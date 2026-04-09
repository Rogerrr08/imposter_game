-- ============================================================================
-- 02 — Rooms: crear, unirse, salir, kick, config, ready, presencia
-- ============================================================================
-- Ejecutar DESPUES de 01-schema.sql
-- ============================================================================

-- --------------------------------------------------------------------------
-- create_private_room
-- --------------------------------------------------------------------------

create or replace function public.create_private_room(
  input_display_name text,
  input_code text,
  input_game_mode text,
  input_categories text[],
  input_hints_enabled boolean,
  input_impostor_count integer,
  input_duration_seconds integer,
  input_min_players integer,
  input_max_players integer
)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  current_user_id uuid;
  new_room_id uuid;
  new_room_expires_at timestamptz;
begin
  current_user_id := auth.uid();
  if current_user_id is null then raise exception 'No hay sesion autenticada'; end if;

  insert into public.rooms (
    code, host_user_id, status, game_mode, categories,
    hints_enabled, impostor_count, duration_seconds, min_players, max_players
  ) values (
    upper(trim(input_code)), current_user_id, 'waiting', input_game_mode,
    input_categories, input_hints_enabled, input_impostor_count,
    input_duration_seconds, input_min_players, input_max_players
  ) returning id, expires_at into new_room_id, new_room_expires_at;

  insert into public.room_players (
    room_id, user_id, display_name, seat_order,
    is_host, is_ready, is_connected, expires_at
  ) values (
    new_room_id, current_user_id, trim(input_display_name),
    1, true, true, true, new_room_expires_at
  );

  return new_room_id;
end;
$$;

-- --------------------------------------------------------------------------
-- join_private_room
-- --------------------------------------------------------------------------

create or replace function public.join_private_room(
  input_code text,
  input_display_name text
)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  current_user_id uuid;
  target_room public.rooms%rowtype;
  existing_membership public.room_players%rowtype;
  next_seat_order integer;
begin
  current_user_id := auth.uid();
  if current_user_id is null then raise exception 'No hay sesion autenticada'; end if;

  select * into target_room from public.rooms
  where code = upper(trim(input_code)) for update;

  if target_room.id is null then raise exception 'No existe una sala con ese codigo'; end if;
  if target_room.status <> 'waiting' then raise exception 'La sala ya no esta disponible para unirse'; end if;

  select * into existing_membership from public.room_players
  where room_id = target_room.id and user_id = current_user_id;

  if existing_membership.id is not null then
    update public.room_players
    set display_name = trim(input_display_name),
        is_connected = true,
        last_seen_at = timezone('utc', now())
    where id = existing_membership.id;
    return target_room.id;
  end if;

  if (select count(*) from public.room_players where room_id = target_room.id) >= target_room.max_players then
    raise exception 'La sala ya esta llena';
  end if;

  select coalesce(max(seat_order), 0) + 1 into next_seat_order
  from public.room_players where room_id = target_room.id;

  insert into public.room_players (
    room_id, user_id, display_name, seat_order,
    is_host, is_ready, is_connected, expires_at
  ) values (
    target_room.id, current_user_id, trim(input_display_name),
    next_seat_order, false, false, true, target_room.expires_at
  );

  return target_room.id;
end;
$$;

-- --------------------------------------------------------------------------
-- leave_room
-- --------------------------------------------------------------------------

create or replace function public.leave_room(input_room_id uuid)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  current_user_id uuid;
  membership_row public.room_players%rowtype;
  new_host public.room_players%rowtype;
  remaining_count integer;
begin
  current_user_id := auth.uid();
  if current_user_id is null then raise exception 'No hay sesion autenticada'; end if;

  select * into membership_row from public.room_players
  where room_id = input_room_id and user_id = current_user_id;
  if membership_row.id is null then return; end if;

  delete from public.room_players where id = membership_row.id;

  select count(*) into remaining_count
  from public.room_players where room_id = input_room_id;

  if remaining_count = 0 then
    delete from public.rooms where id = input_room_id;
    return;
  end if;

  if membership_row.is_host then
    select * into new_host from public.room_players
    where room_id = input_room_id order by seat_order limit 1;

    update public.room_players set is_host = true where id = new_host.id;
    update public.rooms set host_user_id = new_host.user_id where id = input_room_id;
  end if;
end;
$$;

-- --------------------------------------------------------------------------
-- kick_player
-- --------------------------------------------------------------------------

create or replace function public.kick_player(
  input_room_id uuid,
  input_target_user_id uuid
)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  current_user_id uuid;
  target_room public.rooms%rowtype;
begin
  current_user_id := auth.uid();
  if current_user_id is null then raise exception 'No hay sesion autenticada'; end if;

  select * into target_room from public.rooms where id = input_room_id for update;
  if target_room.id is null then raise exception 'La sala no existe'; end if;
  if target_room.host_user_id <> current_user_id then raise exception 'Solo el host puede expulsar jugadores'; end if;
  if target_room.status <> 'waiting' then raise exception 'No se puede expulsar durante una partida en curso'; end if;
  if input_target_user_id = current_user_id then raise exception 'No puedes expulsarte a ti mismo'; end if;

  delete from public.room_players
  where room_id = input_room_id and user_id = input_target_user_id;
  if not found then raise exception 'El jugador no esta en la sala'; end if;
end;
$$;

-- --------------------------------------------------------------------------
-- set_room_ready
-- --------------------------------------------------------------------------

create or replace function public.set_room_ready(
  input_room_id uuid,
  input_is_ready boolean
)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  current_user_id uuid;
begin
  current_user_id := auth.uid();
  if current_user_id is null then raise exception 'No hay sesion autenticada'; end if;

  update public.room_players
  set is_ready = input_is_ready,
      is_connected = true,
      last_seen_at = timezone('utc', now())
  where room_id = input_room_id
    and user_id = current_user_id
    and exists (select 1 from public.rooms where id = input_room_id and status = 'waiting');
end;
$$;

-- --------------------------------------------------------------------------
-- update_room_config
-- --------------------------------------------------------------------------

create or replace function public.update_room_config(
  input_room_id uuid,
  input_categories text[],
  input_hints_enabled boolean,
  input_impostor_count integer,
  input_duration_seconds integer
)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  current_user_id uuid;
begin
  current_user_id := auth.uid();
  if current_user_id is null then raise exception 'No hay sesion autenticada'; end if;

  if not exists (
    select 1 from public.rooms
    where id = input_room_id and host_user_id = current_user_id
  ) then raise exception 'Solo el host puede modificar la configuracion'; end if;

  update public.rooms
  set categories = input_categories,
      hints_enabled = input_hints_enabled,
      impostor_count = input_impostor_count,
      duration_seconds = input_duration_seconds
  where id = input_room_id;
end;
$$;

-- --------------------------------------------------------------------------
-- set_player_connected (mirrors to match_players too)
-- --------------------------------------------------------------------------

create or replace function public.set_player_connected(
  input_room_id uuid,
  input_connected boolean
)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  current_user_id uuid;
begin
  current_user_id := auth.uid();
  if current_user_id is null then raise exception 'No hay sesion autenticada'; end if;

  update public.room_players
  set is_connected = input_connected,
      last_seen_at = timezone('utc', now())
  where room_id = input_room_id and user_id = current_user_id;

  -- Mirror immediately to match_players for active matches
  update public.match_players mp
  set is_connected = input_connected
  from public.matches m
  where m.room_id = input_room_id
    and m.status = 'active'
    and mp.match_id = m.id
    and mp.user_id = current_user_id
    and mp.is_connected <> input_connected;
end;
$$;

-- --------------------------------------------------------------------------
-- get_my_active_room
-- --------------------------------------------------------------------------

create or replace function public.get_my_active_room()
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  current_user_id uuid;
  active_room_id uuid;
begin
  current_user_id := auth.uid();
  if current_user_id is null then return null; end if;

  select rp.room_id into active_room_id
  from public.room_players rp
  inner join public.rooms r on r.id = rp.room_id
  where rp.user_id = current_user_id
    and r.status in ('waiting', 'playing')
  order by rp.joined_at desc
  limit 1;

  return active_room_id;
end;
$$;

-- --------------------------------------------------------------------------
-- Grants
-- --------------------------------------------------------------------------

grant execute on function public.create_private_room(text, text, text, text[], boolean, integer, integer, integer, integer) to authenticated;
grant execute on function public.join_private_room(text, text) to authenticated;
grant execute on function public.set_room_ready(uuid, boolean) to authenticated;
grant execute on function public.update_room_config(uuid, text[], boolean, integer, integer) to authenticated;
grant execute on function public.leave_room(uuid) to authenticated;
grant execute on function public.kick_player(uuid, uuid) to authenticated;
grant execute on function public.set_player_connected(uuid, boolean) to authenticated;
grant execute on function public.get_my_active_room() to authenticated;
