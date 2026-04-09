-- ============================================================================
-- 07 — Triggers, cron jobs y limpieza automatica
-- ============================================================================
-- Ejecutar DESPUES de 06-helpers.sql
-- ============================================================================

-- --------------------------------------------------------------------------
-- on_match_finished — trigger: reset ready + room → waiting
-- --------------------------------------------------------------------------

create or replace function public.on_match_finished()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if NEW.status = 'finished' and (OLD.status is null or OLD.status <> 'finished') then
    update public.room_players
    set is_ready = false
    where room_id = NEW.room_id;

    update public.rooms
    set status = 'waiting'
    where id = NEW.room_id;
  end if;
  return NEW;
end;
$$;

drop trigger if exists match_finished_trigger on public.matches;
create trigger match_finished_trigger
  after update on public.matches
  for each row
  when (NEW.status = 'finished' and OLD.status <> 'finished')
  execute function public.on_match_finished();

-- --------------------------------------------------------------------------
-- skip_impostor_guess — impostor decide no adivinar
-- --------------------------------------------------------------------------

create or replace function public.skip_impostor_guess(input_match_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid;
  the_match public.matches%rowtype;
  my_player public.match_players%rowtype;
  active_impostors integer;
  active_civils integer;
begin
  current_user_id := auth.uid();
  if current_user_id is null then raise exception 'No hay sesion autenticada'; end if;

  select * into the_match from public.matches
  where id = input_match_id for update;

  if the_match.id is null then raise exception 'Match no encontrado'; end if;
  if the_match.status <> 'active' then raise exception 'La partida no esta activa'; end if;
  if the_match.current_phase <> 'impostor_guess' then raise exception 'No es la fase de adivinanza'; end if;

  select * into my_player from public.match_players
  where match_id = input_match_id and user_id = current_user_id;
  if my_player.id is null then raise exception 'No eres jugador de este match'; end if;
  if my_player.role <> 'impostor' then raise exception 'Solo los impostores pueden pasar'; end if;
  if not my_player.is_eliminated then raise exception 'Solo el impostor eliminado puede pasar'; end if;

  select
    count(*) filter (where not is_eliminated and role = 'impostor'),
    count(*) filter (where not is_eliminated and role = 'civil')
  into active_impostors, active_civils
  from public.match_players
  where match_id = input_match_id;

  if active_impostors = 0 then
    update public.matches
    set current_phase = 'finished', status = 'finished',
        state_version = state_version + 1, updated_at = timezone('utc', now())
    where id = input_match_id;

    update public.rooms
    set status = 'waiting'
    where id = the_match.room_id;

    return jsonb_build_object('result', 'game_over', 'winner', 'civils');
  end if;

  update public.matches
  set current_phase = 'clue_writing',
      current_round = the_match.current_round + 1,
      current_turn_index = (
        select seat_order from public.match_players
        where match_id = input_match_id and not is_eliminated
        order by seat_order asc limit 1
      ),
      state_version = state_version + 1,
      updated_at = timezone('utc', now())
  where id = input_match_id;

  return jsonb_build_object(
    'result', 'continue', 'next_phase', 'clue_writing',
    'next_round', the_match.current_round + 1
  );
end;
$$;

-- --------------------------------------------------------------------------
-- check_player_heartbeats — marca desconectados + reasigna host
-- --------------------------------------------------------------------------

create or replace function public.check_player_heartbeats()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  room_record record;
begin
  -- 1. Mark room_players as disconnected if last_seen_at > 90s ago
  update public.room_players
  set is_connected = false
  where is_connected = true
    and last_seen_at < timezone('utc', now()) - interval '90 seconds';

  -- 2. Mirror is_connected from room_players to match_players for active matches
  update public.match_players mp
  set is_connected = rp.is_connected
  from public.room_players rp
  inner join public.matches m on m.room_id = rp.room_id
  where mp.match_id = m.id
    and mp.user_id = rp.user_id
    and m.status = 'active'
    and mp.is_connected <> rp.is_connected;

  -- 3. Check host reassignment for rooms in 'playing' status
  for room_record in
    select r.id
    from public.rooms r
    inner join public.room_players rp
      on rp.room_id = r.id and rp.is_host = true
    where r.status = 'playing'
      and rp.is_connected = false
      and rp.last_seen_at < timezone('utc', now()) - interval '3 minutes'
  loop
    perform public.reassign_host_if_needed(room_record.id);
  end loop;
end;
$$;

-- --------------------------------------------------------------------------
-- reassign_host_if_needed — reasigna host desconectado > 3 min
-- --------------------------------------------------------------------------

create or replace function public.reassign_host_if_needed(input_room_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_host public.room_players%rowtype;
  new_host public.room_players%rowtype;
  active_match_id uuid;
begin
  select * into current_host from public.room_players
  where room_id = input_room_id and is_host = true;

  if current_host.id is null then return; end if;
  if current_host.is_connected = true then return; end if;
  if current_host.last_seen_at >= timezone('utc', now()) - interval '3 minutes' then return; end if;

  select * into new_host from public.room_players
  where room_id = input_room_id and is_connected = true and id <> current_host.id
  order by seat_order asc limit 1;

  if new_host.id is not null then
    update public.room_players set is_host = false where id = current_host.id;
    update public.room_players set is_host = true where id = new_host.id;
    update public.rooms set host_user_id = new_host.user_id where id = input_room_id;
  else
    select id into active_match_id from public.matches
    where room_id = input_room_id and status = 'active' limit 1;

    if active_match_id is not null then
      update public.matches
      set status = 'cancelled', current_phase = 'finished',
          state_version = state_version + 1, updated_at = timezone('utc', now())
      where id = active_match_id;

      update public.rooms set status = 'waiting' where id = input_room_id;
    end if;
  end if;
end;
$$;

-- --------------------------------------------------------------------------
-- cleanup_orphaned_matches — cancela matches sin jugadores conectados
-- --------------------------------------------------------------------------

create or replace function public.cleanup_orphaned_matches()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  cancelled_count integer := 0;
  match_record record;
begin
  -- Cancel active matches where ALL players disconnected for > 10 min
  for match_record in
    select m.id as match_id, m.room_id
    from public.matches m
    where m.status = 'active'
      and not exists (
        select 1 from public.match_players mp
        inner join public.room_players rp
          on rp.user_id = mp.user_id and rp.room_id = m.room_id
        where mp.match_id = m.id and mp.is_connected = true
      )
      and not exists (
        select 1 from public.room_players rp
        inner join public.match_players mp
          on mp.user_id = rp.user_id and mp.match_id = m.id
        where rp.room_id = m.room_id
          and rp.last_seen_at >= timezone('utc', now()) - interval '10 minutes'
      )
  loop
    update public.matches
    set status = 'cancelled', current_phase = 'finished',
        state_version = state_version + 1, updated_at = timezone('utc', now())
    where id = match_record.match_id;

    update public.rooms set status = 'waiting' where id = match_record.room_id;
    cancelled_count := cancelled_count + 1;
  end loop;

  -- Safety net: cancel active matches older than 2 hours
  for match_record in
    select m.id as match_id, m.room_id
    from public.matches m
    where m.status = 'active'
      and m.created_at < timezone('utc', now()) - interval '2 hours'
  loop
    update public.matches
    set status = 'cancelled', current_phase = 'finished',
        state_version = state_version + 1, updated_at = timezone('utc', now())
    where id = match_record.match_id;

    update public.rooms set status = 'waiting' where id = match_record.room_id;
    cancelled_count := cancelled_count + 1;
  end loop;

  return cancelled_count;
end;
$$;

-- --------------------------------------------------------------------------
-- cleanup_expired_private_rooms — elimina salas expiradas
-- --------------------------------------------------------------------------

create or replace function public.cleanup_expired_private_rooms()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  deleted_count integer;
begin
  with deleted_rooms as (
    delete from public.rooms
    where expires_at <= timezone('utc', now())
    returning id
  )
  select count(*) into deleted_count from deleted_rooms;

  return coalesce(deleted_count, 0);
end;
$$;

-- --------------------------------------------------------------------------
-- Cron schedules
-- --------------------------------------------------------------------------

select cron.schedule(
  'check-player-heartbeats',
  '* * * * *',
  $$ select public.check_player_heartbeats(); $$
);

select cron.schedule(
  'cleanup-orphaned-matches',
  '*/5 * * * *',
  $$ select public.cleanup_orphaned_matches(); $$
);

select cron.schedule(
  'cleanup-expired-private-rooms',
  '0 * * * *',
  $$ select public.cleanup_expired_private_rooms(); $$
);

-- --------------------------------------------------------------------------
-- Grants
-- --------------------------------------------------------------------------

grant execute on function public.on_match_finished() to postgres;
grant execute on function public.skip_impostor_guess(uuid) to authenticated;
grant execute on function public.check_player_heartbeats() to postgres;
grant execute on function public.reassign_host_if_needed(uuid) to postgres;
grant execute on function public.cleanup_orphaned_matches() to postgres;
grant execute on function public.cleanup_expired_private_rooms() to postgres;
