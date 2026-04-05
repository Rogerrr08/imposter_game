-- ============================================================================
-- Fase 5 Slice 1: Confirmacion de rol + escritura de pistas
-- ============================================================================
-- Ejecutar DESPUES de supabase-phase4-match-engine.sql
-- ============================================================================

-- --------------------------------------------------------------------------
-- Columna nueva: match_players.role_confirmed
-- --------------------------------------------------------------------------
alter table public.match_players
  add column if not exists role_confirmed boolean not null default false;

-- --------------------------------------------------------------------------
-- Realtime para match_clues (necesario para que los clientes vean pistas)
-- --------------------------------------------------------------------------
alter publication supabase_realtime add table public.match_clues;
alter table public.match_clues replica identity full;

-- --------------------------------------------------------------------------
-- RLS: match_clues insert (players can insert their own clues)
-- --------------------------------------------------------------------------
create policy "match_players_can_insert_clues"
  on public.match_clues for insert
  with check (
    public.is_match_player(match_id)
  );

-- --------------------------------------------------------------------------
-- RPC: confirm_role_reveal
-- --------------------------------------------------------------------------
-- Called after the player taps "Entendido" on the role reveal screen.
-- When all non-eliminated players have confirmed, advances to clue_writing.
-- --------------------------------------------------------------------------

create or replace function public.confirm_role_reveal(input_match_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid;
  the_match public.matches%rowtype;
  my_player public.match_players%rowtype;
  total_active integer;
  total_confirmed integer;
  all_confirmed boolean;
begin
  current_user_id := auth.uid();
  if current_user_id is null then
    raise exception 'No hay sesion autenticada';
  end if;

  select * into the_match
  from public.matches
  where id = input_match_id
  for update;

  if the_match.id is null then
    raise exception 'Match no encontrado';
  end if;

  if the_match.status <> 'active' then
    raise exception 'La partida no esta activa';
  end if;

  if the_match.current_phase <> 'role_reveal' then
    -- Already past role reveal, just return
    return jsonb_build_object('phase_advanced', false, 'already_confirmed', true);
  end if;

  select * into my_player
  from public.match_players
  where match_id = input_match_id
    and user_id = current_user_id;

  if my_player.id is null then
    raise exception 'No eres jugador de este match';
  end if;

  if my_player.role_confirmed then
    return jsonb_build_object('phase_advanced', false, 'already_confirmed', true);
  end if;

  -- Mark as confirmed
  update public.match_players
  set role_confirmed = true
  where id = my_player.id;

  -- Check if all active players have confirmed
  select
    count(*) filter (where not is_eliminated),
    count(*) filter (where not is_eliminated and role_confirmed)
  into total_active, total_confirmed
  from public.match_players
  where match_id = input_match_id;

  -- +1 because we just confirmed but the count query might race
  -- Actually we already updated, so the count includes us
  all_confirmed := (total_confirmed >= total_active);

  if all_confirmed then
    -- Advance to clue_writing phase
    -- current_turn_index starts at the starting_player's seat_order
    update public.matches
    set current_phase = 'clue_writing',
        current_turn_index = (
          select seat_order
          from public.match_players
          where id = the_match.starting_player_id
        ),
        state_version = state_version + 1,
        updated_at = timezone('utc', now())
    where id = input_match_id;
  end if;

  return jsonb_build_object(
    'phase_advanced', all_confirmed,
    'already_confirmed', false
  );
end;
$$;

-- --------------------------------------------------------------------------
-- RPC: submit_clue
-- --------------------------------------------------------------------------
-- Called when the current-turn player submits their clue.
-- Validates it's their turn, inserts the clue, then advances to the next
-- non-eliminated player. If all players have written, advances to voting.
-- --------------------------------------------------------------------------

create or replace function public.submit_clue(
  input_match_id uuid,
  input_clue text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid;
  the_match public.matches%rowtype;
  my_player public.match_players%rowtype;
  next_seat integer;
  phase_after text;
begin
  current_user_id := auth.uid();
  if current_user_id is null then
    raise exception 'No hay sesion autenticada';
  end if;

  -- Validate input
  if input_clue is null or length(trim(input_clue)) = 0 then
    raise exception 'La pista no puede estar vacia';
  end if;

  if length(trim(input_clue)) > 50 then
    raise exception 'La pista es demasiado larga (maximo 50 caracteres)';
  end if;

  -- Lock and validate match
  select * into the_match
  from public.matches
  where id = input_match_id
  for update;

  if the_match.id is null then
    raise exception 'Match no encontrado';
  end if;

  if the_match.status <> 'active' then
    raise exception 'La partida no esta activa';
  end if;

  if the_match.current_phase <> 'clue_writing' then
    raise exception 'No es la fase de escritura de pistas';
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
    raise exception 'Estas eliminado de esta partida';
  end if;

  -- Verify it's this player's turn
  if my_player.seat_order <> the_match.current_turn_index then
    raise exception 'No es tu turno';
  end if;

  -- Check for duplicate clue in this round
  if exists (
    select 1 from public.match_clues
    where match_id = input_match_id
      and round_number = the_match.current_round
      and player_id = my_player.id
  ) then
    raise exception 'Ya escribiste tu pista en esta ronda';
  end if;

  -- Insert the clue
  insert into public.match_clues (
    match_id,
    round_number,
    player_id,
    turn_order,
    clue
  )
  values (
    input_match_id,
    the_match.current_round,
    my_player.id,
    my_player.seat_order,
    trim(input_clue)
  );

  -- Find next non-eliminated player by seat_order
  select seat_order into next_seat
  from public.match_players
  where match_id = input_match_id
    and not is_eliminated
    and seat_order > the_match.current_turn_index
  order by seat_order asc
  limit 1;

  -- If no next player found (wrapped around), also check if we need to
  -- wrap to the beginning (seat_order < current)
  if next_seat is null then
    -- Check if there are players with lower seat_order who haven't written yet
    select mp.seat_order into next_seat
    from public.match_players mp
    where mp.match_id = input_match_id
      and not mp.is_eliminated
      and mp.seat_order < the_match.current_turn_index
      and not exists (
        select 1 from public.match_clues mc
        where mc.match_id = input_match_id
          and mc.round_number = the_match.current_round
          and mc.player_id = mp.id
      )
    order by mp.seat_order asc
    limit 1;
  end if;

  if next_seat is not null then
    -- More players to go — advance turn
    phase_after := 'clue_writing';
    update public.matches
    set current_turn_index = next_seat,
        state_version = state_version + 1,
        updated_at = timezone('utc', now())
    where id = input_match_id;
  else
    -- All players have written — advance to voting
    phase_after := 'voting';
    update public.matches
    set current_phase = 'voting',
        current_turn_index = 0,
        state_version = state_version + 1,
        updated_at = timezone('utc', now())
    where id = input_match_id;
  end if;

  return jsonb_build_object(
    'next_phase', phase_after,
    'next_turn_index', coalesce(next_seat, 0)
  );
end;
$$;

-- --------------------------------------------------------------------------
-- RPC: skip_clue_turn
-- --------------------------------------------------------------------------
-- Called when the turn timer expires. Advances to the next player
-- without inserting a clue. Can be called by any player in the match
-- (client-side timer enforcement).
-- --------------------------------------------------------------------------

create or replace function public.skip_clue_turn(input_match_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid;
  the_match public.matches%rowtype;
  current_turn_player public.match_players%rowtype;
  next_seat integer;
  phase_after text;
begin
  current_user_id := auth.uid();
  if current_user_id is null then
    raise exception 'No hay sesion autenticada';
  end if;

  select * into the_match
  from public.matches
  where id = input_match_id
  for update;

  if the_match.id is null then
    raise exception 'Match no encontrado';
  end if;

  if the_match.status <> 'active' or the_match.current_phase <> 'clue_writing' then
    return jsonb_build_object('skipped', false);
  end if;

  -- Verify caller is a player in this match
  if not exists (
    select 1 from public.match_players
    where match_id = input_match_id and user_id = current_user_id
  ) then
    raise exception 'No eres jugador de este match';
  end if;

  -- Find next non-eliminated player who hasn't written yet
  select seat_order into next_seat
  from public.match_players mp
  where mp.match_id = input_match_id
    and not mp.is_eliminated
    and mp.seat_order > the_match.current_turn_index
    and not exists (
      select 1 from public.match_clues mc
      where mc.match_id = input_match_id
        and mc.round_number = the_match.current_round
        and mc.player_id = mp.id
    )
  order by mp.seat_order asc
  limit 1;

  if next_seat is null then
    -- Wrap around
    select mp.seat_order into next_seat
    from public.match_players mp
    where mp.match_id = input_match_id
      and not mp.is_eliminated
      and mp.seat_order < the_match.current_turn_index
      and not exists (
        select 1 from public.match_clues mc
        where mc.match_id = input_match_id
          and mc.round_number = the_match.current_round
          and mc.player_id = mp.id
      )
    order by mp.seat_order asc
    limit 1;
  end if;

  if next_seat is not null then
    phase_after := 'clue_writing';
    update public.matches
    set current_turn_index = next_seat,
        state_version = state_version + 1,
        updated_at = timezone('utc', now())
    where id = input_match_id;
  else
    phase_after := 'voting';
    update public.matches
    set current_phase = 'voting',
        current_turn_index = 0,
        state_version = state_version + 1,
        updated_at = timezone('utc', now())
    where id = input_match_id;
  end if;

  return jsonb_build_object('skipped', true, 'next_phase', phase_after);
end;
$$;

-- --------------------------------------------------------------------------
-- Grants
-- --------------------------------------------------------------------------

grant execute on function public.confirm_role_reveal(uuid) to authenticated;
grant execute on function public.submit_clue(uuid, text) to authenticated;
grant execute on function public.skip_clue_turn(uuid) to authenticated;
