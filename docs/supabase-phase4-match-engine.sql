-- ============================================================================
-- Fase 4: Motor de juego autoritativo — tablas, RLS y start_match
-- ============================================================================
-- Ejecutar DESPUES de supabase-phase3-private-rooms.sql
-- ============================================================================

-- --------------------------------------------------------------------------
-- Tablas
-- --------------------------------------------------------------------------

create table if not exists public.matches (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  status text not null default 'active'
    check (status in ('active', 'finished', 'cancelled')),
  word text not null,
  category text not null,
  hints_enabled boolean not null default true,
  impostor_count integer not null default 1,
  duration_seconds integer not null default 120,
  current_phase text not null default 'role_reveal'
    check (current_phase in (
      'role_reveal', 'clue_writing', 'voting', 'vote_result',
      'impostor_guess', 'finished'
    )),
  current_round integer not null default 1,
  current_turn_index integer not null default 0,
  starting_player_id uuid,
  state_version integer not null default 1,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.match_players (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  user_id uuid not null,
  display_name text not null,
  seat_order integer not null default 0,
  role text not null default 'civil'
    check (role in ('civil', 'impostor')),
  hint text,
  is_eliminated boolean not null default false,
  points integer not null default 0,
  voted_incorrectly boolean not null default false,
  eliminated_by_failed_guess boolean not null default false,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.match_clues (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  round_number integer not null,
  player_id uuid not null references public.match_players(id) on delete cascade,
  turn_order integer not null default 0,
  clue text not null,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.match_votes (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  round_number integer not null,
  voter_id uuid not null references public.match_players(id) on delete cascade,
  target_player_id uuid not null references public.match_players(id) on delete cascade,
  is_tiebreak boolean not null default false,
  created_at timestamptz not null default timezone('utc', now())
);

-- --------------------------------------------------------------------------
-- Indices
-- --------------------------------------------------------------------------

create index if not exists idx_matches_room_id on public.matches(room_id);
create index if not exists idx_matches_status on public.matches(status);
create index if not exists idx_match_players_match_id on public.match_players(match_id);
create index if not exists idx_match_players_user_id on public.match_players(user_id);
create index if not exists idx_match_clues_match_id on public.match_clues(match_id);
create index if not exists idx_match_votes_match_id on public.match_votes(match_id);

-- --------------------------------------------------------------------------
-- RLS
-- --------------------------------------------------------------------------

alter table public.matches enable row level security;
alter table public.match_players enable row level security;
alter table public.match_clues enable row level security;
alter table public.match_votes enable row level security;

-- Helper: check if user is a player in a match
create or replace function public.is_match_player(p_match_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.match_players
    where match_id = p_match_id
      and user_id = auth.uid()
  );
$$;

-- matches: players of the match can read
create policy "match_players_can_read_match"
  on public.matches for select
  using (public.is_match_player(id));

-- match_players: players of the same match can read all columns EXCEPT
-- other players' roles. Each player can only see their own role.
-- We use a permissive policy for basic access + column-level logic in the app.
-- For true role hiding, the role is delivered via RPC (get_my_match_state).
create policy "match_members_can_read_players"
  on public.match_players for select
  using (public.is_match_player(match_id));

-- match_clues: players of the match can read
create policy "match_members_can_read_clues"
  on public.match_clues for select
  using (public.is_match_player(match_id));

-- match_votes: players of the match can read
create policy "match_members_can_read_votes"
  on public.match_votes for select
  using (public.is_match_player(match_id));

-- --------------------------------------------------------------------------
-- Realtime
-- --------------------------------------------------------------------------

alter publication supabase_realtime add table public.matches;
alter publication supabase_realtime add table public.match_players;
alter table public.matches replica identity full;
alter table public.match_players replica identity full;

-- --------------------------------------------------------------------------
-- RPC: start_match
-- --------------------------------------------------------------------------
-- Called by the host from Flutter. Flutter provides the word data
-- (word, category, hints) since the word bank lives client-side.
-- The server validates permissions and creates the match authoritatively.
-- --------------------------------------------------------------------------

create or replace function public.start_match(
  input_room_id uuid,
  input_word text,
  input_category text,
  input_hints jsonb,          -- ["hint1", "hint2", "hint3"]
  input_impostor_indices int[] -- 0-based indices into the player list (by seat_order)
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid;
  target_room public.rooms%rowtype;
  room_player_rows public.room_players[];
  player_row public.room_players;
  player_count integer;
  ready_count integer;
  impostor_count integer;
  new_match_id uuid;
  new_match_player_id uuid;
  is_impostor boolean;
  hint_array text[];
  hint_index integer := 0;
  hints_enabled boolean;
  starting_mp_id uuid;
  i integer;
begin
  -- 1. Auth
  current_user_id := auth.uid();
  if current_user_id is null then
    raise exception 'No hay sesion autenticada';
  end if;

  -- 2. Lock and validate room
  select * into target_room
  from public.rooms
  where id = input_room_id
  for update;

  if target_room.id is null then
    raise exception 'La sala no existe';
  end if;

  if target_room.host_user_id <> current_user_id then
    raise exception 'Solo el host puede iniciar la partida';
  end if;

  if target_room.status <> 'waiting' then
    raise exception 'La sala ya tiene una partida en curso o finalizada';
  end if;

  -- 3. Validate players
  select count(*), count(*) filter (where is_ready or is_host)
  into player_count, ready_count
  from public.room_players
  where room_id = input_room_id;

  if player_count < target_room.min_players then
    raise exception 'No hay suficientes jugadores (minimo %)', target_room.min_players;
  end if;

  if ready_count < target_room.min_players then
    raise exception 'No hay suficientes jugadores listos (minimo %)', target_room.min_players;
  end if;

  -- 4. Validate impostor indices
  impostor_count := array_length(input_impostor_indices, 1);
  if impostor_count is null or impostor_count < 1 then
    raise exception 'Debe haber al menos un impostor';
  end if;

  if impostor_count > (player_count / 3) then
    raise exception 'Demasiados impostores para la cantidad de jugadores';
  end if;

  -- 5. Parse hints
  hints_enabled := target_room.hints_enabled;
  if hints_enabled and input_hints is not null then
    select array_agg(h.value::text)
    into hint_array
    from jsonb_array_elements_text(input_hints) as h(value);
  else
    hint_array := '{}';
  end if;

  -- 6. Create match
  insert into public.matches (
    room_id,
    status,
    word,
    category,
    hints_enabled,
    impostor_count,
    duration_seconds,
    current_phase,
    current_round,
    current_turn_index,
    state_version
  )
  values (
    input_room_id,
    'active',
    input_word,
    input_category,
    hints_enabled,
    impostor_count,
    target_room.duration_seconds,
    'role_reveal',
    1,
    0,
    1
  )
  returning id into new_match_id;

  -- 7. Create match_players from room_players (ordered by seat_order)
  for player_row in
    select * from public.room_players
    where room_id = input_room_id
    order by seat_order asc
  loop
    is_impostor := (player_row.seat_order - 1) = any(input_impostor_indices);

    insert into public.match_players (
      match_id,
      user_id,
      display_name,
      seat_order,
      role,
      hint,
      is_eliminated,
      points
    )
    values (
      new_match_id,
      player_row.user_id,
      player_row.display_name,
      player_row.seat_order,
      case when is_impostor then 'impostor' else 'civil' end,
      case
        when is_impostor and hints_enabled and array_length(hint_array, 1) > 0
        then hint_array[(hint_index % array_length(hint_array, 1)) + 1]
        else null
      end,
      false,
      0
    )
    returning id into new_match_player_id;

    if is_impostor then
      hint_index := hint_index + 1;
    end if;

    -- Pick first civil as starting player (or first player if all impostors somehow)
    if starting_mp_id is null and not is_impostor then
      starting_mp_id := new_match_player_id;
    end if;
  end loop;

  -- Fallback: if no civil found, use first player
  if starting_mp_id is null then
    select id into starting_mp_id
    from public.match_players
    where match_id = new_match_id
    order by seat_order asc
    limit 1;
  end if;

  -- 8. Set starting player on match
  update public.matches
  set starting_player_id = starting_mp_id
  where id = new_match_id;

  -- 9. Transition room to playing
  update public.rooms
  set
    status = 'playing',
    started_at = timezone('utc', now())
  where id = input_room_id;

  return new_match_id;
end;
$$;

-- --------------------------------------------------------------------------
-- RPC: get_my_match_state
-- --------------------------------------------------------------------------
-- Returns the current player's match state including their role.
-- This is the safe way to get role info — RLS lets everyone read
-- match_players, but the client should use this RPC for role/word.
-- --------------------------------------------------------------------------

create or replace function public.get_my_match_state(input_match_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid;
  the_match public.matches%rowtype;
  my_player public.match_players%rowtype;
  result jsonb;
begin
  current_user_id := auth.uid();
  if current_user_id is null then
    raise exception 'No hay sesion autenticada';
  end if;

  select * into the_match
  from public.matches
  where id = input_match_id;

  if the_match.id is null then
    raise exception 'Match no encontrado';
  end if;

  select * into my_player
  from public.match_players
  where match_id = input_match_id
    and user_id = current_user_id;

  if my_player.id is null then
    raise exception 'No eres jugador de este match';
  end if;

  result := jsonb_build_object(
    'match_id', the_match.id,
    'room_id', the_match.room_id,
    'status', the_match.status,
    'category', the_match.category,
    'hints_enabled', the_match.hints_enabled,
    'impostor_count', the_match.impostor_count,
    'duration_seconds', the_match.duration_seconds,
    'current_phase', the_match.current_phase,
    'current_round', the_match.current_round,
    'current_turn_index', the_match.current_turn_index,
    'state_version', the_match.state_version,
    -- Player-specific (safe: only my own data)
    'my_player_id', my_player.id,
    'my_role', my_player.role,
    'my_hint', my_player.hint,
    'my_seat_order', my_player.seat_order,
    'my_is_eliminated', my_player.is_eliminated,
    'my_points', my_player.points,
    -- Word: civils always get it; impostors get it only when match is finished
    'word', case
      when my_player.role = 'civil' then the_match.word
      when the_match.status = 'finished' then the_match.word
      else null
    end
  );

  return result;
end;
$$;

-- --------------------------------------------------------------------------
-- RPC: abandon_match
-- --------------------------------------------------------------------------
-- Marks the calling player as eliminated. If the remaining active players
-- fall below the viability threshold (< 3, or no impostors, or no civils),
-- the match is cancelled and the room returns to 'waiting'.
-- --------------------------------------------------------------------------

create or replace function public.abandon_match(input_match_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid;
  the_match public.matches%rowtype;
  my_player public.match_players%rowtype;
  active_count integer;
  active_impostors integer;
  active_civils integer;
  match_cancelled boolean := false;
begin
  current_user_id := auth.uid();
  if current_user_id is null then
    raise exception 'No hay sesion autenticada';
  end if;

  -- Lock the match row
  select * into the_match
  from public.matches
  where id = input_match_id
  for update;

  if the_match.id is null then
    raise exception 'Match no encontrado';
  end if;

  if the_match.status <> 'active' then
    return jsonb_build_object('cancelled', the_match.status = 'cancelled');
  end if;

  -- Find calling player
  select * into my_player
  from public.match_players
  where match_id = input_match_id
    and user_id = current_user_id;

  if my_player.id is null then
    raise exception 'No eres jugador de este match';
  end if;

  if my_player.is_eliminated then
    return jsonb_build_object('cancelled', false);
  end if;

  -- Mark as eliminated
  update public.match_players
  set is_eliminated = true
  where id = my_player.id;

  -- Remove from room_players so get_my_active_room won't find them
  delete from public.room_players
  where room_id = the_match.room_id
    and user_id = current_user_id;

  -- Check viability of remaining players
  select
    count(*) filter (where not is_eliminated),
    count(*) filter (where not is_eliminated and role = 'impostor'),
    count(*) filter (where not is_eliminated and role = 'civil')
  into active_count, active_impostors, active_civils
  from public.match_players
  where match_id = input_match_id;

  -- Cancel if not viable: < 3 players, or no impostors, or no civils
  if active_count < 3 or active_impostors < 1 or active_civils < 1 then
    update public.matches
    set status = 'cancelled',
        current_phase = 'finished',
        state_version = state_version + 1,
        updated_at = timezone('utc', now())
    where id = input_match_id;

    -- Return room to waiting so remaining players go back to lobby
    update public.rooms
    set status = 'waiting'
    where id = the_match.room_id;

    match_cancelled := true;
  else
    -- Bump version so clients detect the change
    update public.matches
    set state_version = state_version + 1,
        updated_at = timezone('utc', now())
    where id = input_match_id;
  end if;

  return jsonb_build_object('cancelled', match_cancelled);
end;
$$;

-- --------------------------------------------------------------------------
-- Grants
-- --------------------------------------------------------------------------

grant execute on function public.is_match_player(uuid) to authenticated;
grant execute on function public.start_match(uuid, text, text, jsonb, int[]) to authenticated;
grant execute on function public.get_my_match_state(uuid) to authenticated;
grant execute on function public.abandon_match(uuid) to authenticated;
