-- ============================================================================
-- 03 — Match lifecycle: iniciar partida, estado, abandonar
-- ============================================================================
-- Ejecutar DESPUES de 02-rooms.sql
-- ============================================================================

-- --------------------------------------------------------------------------
-- start_match (random starting player + all players must be ready)
-- --------------------------------------------------------------------------

create or replace function public.start_match(
  input_room_id uuid,
  input_word text,
  input_category text,
  input_hints jsonb,
  input_impostor_indices int[]
)
returns uuid
language plpgsql security definer set search_path = public
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
  current_user_id := auth.uid();
  if current_user_id is null then raise exception 'No hay sesion autenticada'; end if;

  select * into target_room from public.rooms where id = input_room_id for update;
  if target_room.id is null then raise exception 'La sala no existe'; end if;
  if target_room.host_user_id <> current_user_id then raise exception 'Solo el host puede iniciar la partida'; end if;
  if target_room.status <> 'waiting' then raise exception 'La sala ya tiene una partida en curso o finalizada'; end if;

  -- Validate ALL players are ready (host counts as ready)
  select count(*), count(*) filter (where is_ready or is_host)
  into player_count, ready_count
  from public.room_players where room_id = input_room_id;

  if player_count < target_room.min_players then
    raise exception 'No hay suficientes jugadores (minimo %)', target_room.min_players;
  end if;
  if ready_count < player_count then
    raise exception 'Todos los jugadores deben estar listos para iniciar';
  end if;

  -- Validate impostor indices
  impostor_count := array_length(input_impostor_indices, 1);
  if impostor_count is null or impostor_count < 1 then raise exception 'Debe haber al menos un impostor'; end if;
  if impostor_count > (player_count / 3) then raise exception 'Demasiados impostores para la cantidad de jugadores'; end if;

  -- Parse hints
  hints_enabled := target_room.hints_enabled;
  if hints_enabled and input_hints is not null then
    select array_agg(h.value::text order by h.ordinality)
    into hint_array
    from jsonb_array_elements_text(input_hints) with ordinality as h(value, ordinality);
  end if;

  -- Get room players ordered by seat_order
  select array_agg(rp order by rp.seat_order)
  into room_player_rows
  from public.room_players rp where rp.room_id = input_room_id;

  -- Create match
  insert into public.matches (
    room_id, word, category, hints_enabled,
    impostor_count, duration_seconds,
    current_phase, current_round, current_turn_index
  ) values (
    input_room_id, input_word, input_category, hints_enabled,
    impostor_count, target_room.duration_seconds,
    'role_reveal', 1, 0
  ) returning id into new_match_id;

  -- Create match_players
  for i in 1..array_length(room_player_rows, 1) loop
    player_row := room_player_rows[i];
    is_impostor := (i - 1) = any(input_impostor_indices);

    insert into public.match_players (
      match_id, user_id, display_name, avatar_url, role, seat_order, hint
    ) values (
      new_match_id, player_row.user_id, player_row.display_name,
      player_row.avatar_url,
      case when is_impostor then 'impostor' else 'civil' end,
      player_row.seat_order,
      case
        when is_impostor and hints_enabled and hint_array is not null then
          hint_array[hint_index + 1]
        else null
      end
    ) returning id into new_match_player_id;

    if is_impostor then hint_index := hint_index + 1; end if;
  end loop;

  -- Pick a RANDOM civil as starting player
  select id into starting_mp_id
  from public.match_players
  where match_id = new_match_id and role = 'civil'
  order by random() limit 1;

  -- Fallback: if no civil found, pick any random player
  if starting_mp_id is null then
    select id into starting_mp_id
    from public.match_players
    where match_id = new_match_id
    order by random() limit 1;
  end if;

  update public.matches
  set starting_player_id = starting_mp_id,
      current_turn_index = (select seat_order from public.match_players where id = starting_mp_id)
  where id = new_match_id;

  update public.rooms set status = 'playing' where id = input_room_id;

  return new_match_id;
end;
$$;

-- --------------------------------------------------------------------------
-- get_my_match_state
-- --------------------------------------------------------------------------

create or replace function public.get_my_match_state(input_match_id uuid)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  current_user_id uuid;
  the_match public.matches%rowtype;
  my_player public.match_players%rowtype;
  result jsonb;
begin
  current_user_id := auth.uid();
  if current_user_id is null then raise exception 'No hay sesion autenticada'; end if;

  select * into the_match from public.matches where id = input_match_id;
  if the_match.id is null then raise exception 'Match no encontrado'; end if;

  select * into my_player from public.match_players
  where match_id = input_match_id and user_id = current_user_id;
  if my_player.id is null then raise exception 'No eres jugador de este match'; end if;

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
    'my_player_id', my_player.id,
    'my_role', my_player.role,
    'my_hint', my_player.hint,
    'my_seat_order', my_player.seat_order,
    'my_is_eliminated', my_player.is_eliminated,
    'my_points', my_player.points,
    'my_role_confirmed', my_player.role_confirmed,
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
-- abandon_match
-- --------------------------------------------------------------------------

create or replace function public.abandon_match(input_match_id uuid)
returns jsonb
language plpgsql security definer set search_path = public
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
  if current_user_id is null then raise exception 'No hay sesion autenticada'; end if;

  select * into the_match from public.matches where id = input_match_id for update;
  if the_match.id is null then raise exception 'Match no encontrado'; end if;
  if the_match.status <> 'active' then
    return jsonb_build_object('cancelled', the_match.status = 'cancelled');
  end if;

  select * into my_player from public.match_players
  where match_id = input_match_id and user_id = current_user_id;
  if my_player.id is null then raise exception 'No eres jugador de este match'; end if;
  if my_player.is_eliminated then return jsonb_build_object('cancelled', false); end if;

  update public.match_players set is_eliminated = true where id = my_player.id;

  select
    count(*) filter (where not is_eliminated),
    count(*) filter (where not is_eliminated and role = 'impostor'),
    count(*) filter (where not is_eliminated and role = 'civil')
  into active_count, active_impostors, active_civils
  from public.match_players where match_id = input_match_id;

  if active_count < 3 or active_impostors < 1 or active_civils < 1 then
    update public.matches
    set status = 'cancelled', current_phase = 'finished',
        state_version = state_version + 1, updated_at = timezone('utc', now())
    where id = input_match_id;

    update public.rooms set status = 'waiting' where id = the_match.room_id;
    match_cancelled := true;
  else
    update public.matches
    set state_version = state_version + 1, updated_at = timezone('utc', now())
    where id = input_match_id;
  end if;

  return jsonb_build_object('cancelled', match_cancelled);
end;
$$;

-- --------------------------------------------------------------------------
-- Grants
-- --------------------------------------------------------------------------

grant execute on function public.start_match(uuid, text, text, jsonb, int[]) to authenticated;
grant execute on function public.get_my_match_state(uuid) to authenticated;
grant execute on function public.abandon_match(uuid) to authenticated;
