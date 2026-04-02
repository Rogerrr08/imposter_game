-- Yeison Impostor
-- Fase 3 (slice 1): salas privadas y lobby
-- Ejecuta este script en el SQL Editor de Supabase sobre el proyecto del MVP.
-- Este bootstrap deja las lecturas protegidas por RLS y usa funciones RPC
-- para crear/unirse/salir y mutar el lobby sin depender de inserts directos
-- desde Flutter antes de ser miembro de la sala.

create extension if not exists pgcrypto;
create extension if not exists pg_cron;

create table if not exists public.rooms (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  host_user_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'waiting'
    check (status in ('waiting', 'playing', 'finished')),
  game_mode text not null default 'classic'
    check (game_mode in ('classic', 'express')),
  categories text[] not null default '{}',
  hints_enabled boolean not null default true,
  impostor_count integer not null default 1 check (impostor_count >= 1),
  duration_seconds integer not null default 120 check (duration_seconds >= 60),
  min_players integer not null default 4 check (min_players >= 4),
  max_players integer not null default 8 check (max_players >= min_players),
  expires_at timestamptz not null default timezone('utc', now()) + interval '1 day',
  created_at timestamptz not null default timezone('utc', now()),
  started_at timestamptz
);

create table if not exists public.room_players (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  display_name text not null,
  seat_order integer not null check (seat_order >= 1),
  is_host boolean not null default false,
  is_ready boolean not null default false,
  is_connected boolean not null default true,
  expires_at timestamptz not null default timezone('utc', now()) + interval '1 day',
  last_seen_at timestamptz not null default timezone('utc', now()),
  joined_at timestamptz not null default timezone('utc', now()),
  unique (room_id, user_id),
  unique (room_id, seat_order)
);

alter table public.rooms
  add column if not exists expires_at timestamptz not null
  default timezone('utc', now()) + interval '1 day';

alter table public.room_players
  add column if not exists expires_at timestamptz not null
  default timezone('utc', now()) + interval '1 day';

update public.room_players rp
set expires_at = r.expires_at
from public.rooms r
where rp.room_id = r.id
  and rp.expires_at <> r.expires_at;

create index if not exists rooms_code_idx on public.rooms (code);
create index if not exists room_players_room_id_idx on public.room_players (room_id);
create index if not exists room_players_user_id_idx on public.room_players (user_id);
create index if not exists rooms_expires_at_idx on public.rooms (expires_at);
create index if not exists room_players_expires_at_idx on public.room_players (expires_at);

alter table public.rooms enable row level security;
alter table public.room_players enable row level security;
alter table public.rooms replica identity full;
alter table public.room_players replica identity full;

do $$
begin
  if exists (
    select 1
    from pg_publication
    where pubname = 'supabase_realtime'
  ) then
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'rooms'
    ) then
      alter publication supabase_realtime add table public.rooms;
    end if;

    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'room_players'
    ) then
      alter publication supabase_realtime add table public.room_players;
    end if;
  end if;
end;
$$;

create or replace function public.is_room_member(input_room_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.room_players
    where room_id = input_room_id
      and user_id = auth.uid()
  );
$$;

drop policy if exists rooms_select_for_members on public.rooms;
create policy rooms_select_for_members
on public.rooms
for select
to authenticated
using (public.is_room_member(id));

drop policy if exists room_players_select_for_members on public.room_players;
create policy room_players_select_for_members
on public.room_players
for select
to authenticated
using (public.is_room_member(room_id));

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
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid;
  new_room_id uuid;
  new_room_expires_at timestamptz;
begin
  current_user_id := auth.uid();
  if current_user_id is null then
    raise exception 'No hay sesion autenticada';
  end if;

  insert into public.rooms (
    code,
    host_user_id,
    status,
    game_mode,
    categories,
    hints_enabled,
    impostor_count,
    duration_seconds,
    min_players,
    max_players
  )
  values (
    upper(trim(input_code)),
    current_user_id,
    'waiting',
    input_game_mode,
    input_categories,
    input_hints_enabled,
    input_impostor_count,
    input_duration_seconds,
    input_min_players,
    input_max_players
  )
  returning id, expires_at into new_room_id, new_room_expires_at;

  insert into public.room_players (
    room_id,
    user_id,
    display_name,
    seat_order,
    is_host,
    is_ready,
    is_connected,
    expires_at
  )
  values (
    new_room_id,
    current_user_id,
    trim(input_display_name),
    1,
    true,
    true,
    true,
    new_room_expires_at
  );

  return new_room_id;
end;
$$;

create or replace function public.join_private_room(
  input_code text,
  input_display_name text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid;
  target_room public.rooms%rowtype;
  existing_membership public.room_players%rowtype;
  next_seat_order integer;
begin
  current_user_id := auth.uid();
  if current_user_id is null then
    raise exception 'No hay sesion autenticada';
  end if;

  select *
  into target_room
  from public.rooms
  where code = upper(trim(input_code));

  if target_room.id is null then
    raise exception 'No existe una sala con ese codigo';
  end if;

  if target_room.status <> 'waiting' then
    raise exception 'La sala ya no esta disponible para unirse';
  end if;

  select *
  into existing_membership
  from public.room_players
  where room_id = target_room.id
    and user_id = current_user_id;

  if existing_membership.id is not null then
    update public.room_players
    set
      display_name = trim(input_display_name),
      is_connected = true,
      last_seen_at = timezone('utc', now())
    where id = existing_membership.id;

    return target_room.id;
  end if;

  if (
    select count(*)
    from public.room_players
    where room_id = target_room.id
  ) >= target_room.max_players then
    raise exception 'La sala ya esta llena';
  end if;

  select coalesce(max(seat_order), 0) + 1
  into next_seat_order
  from public.room_players
  where room_id = target_room.id;

  insert into public.room_players (
    room_id,
    user_id,
    display_name,
    seat_order,
    is_host,
    is_ready,
    is_connected,
    expires_at
  )
  values (
    target_room.id,
    current_user_id,
    trim(input_display_name),
    next_seat_order,
    false,
    false,
    true,
    target_room.expires_at
  );

  return target_room.id;
end;
$$;

create or replace function public.set_room_ready(
  input_room_id uuid,
  input_is_ready boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid;
begin
  current_user_id := auth.uid();
  if current_user_id is null then
    raise exception 'No hay sesion autenticada';
  end if;

  update public.room_players
  set
    is_ready = input_is_ready,
    is_connected = true,
    last_seen_at = timezone('utc', now())
  where room_id = input_room_id
    and user_id = current_user_id;
end;
$$;

create or replace function public.update_room_config(
  input_room_id uuid,
  input_categories text[],
  input_hints_enabled boolean,
  input_impostor_count integer,
  input_duration_seconds integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid;
begin
  current_user_id := auth.uid();
  if current_user_id is null then
    raise exception 'No hay sesion autenticada';
  end if;

  if not exists (
    select 1
    from public.rooms
    where id = input_room_id
      and host_user_id = current_user_id
  ) then
    raise exception 'Solo el host puede modificar la configuracion';
  end if;

  update public.rooms
  set
    categories = input_categories,
    hints_enabled = input_hints_enabled,
    impostor_count = input_impostor_count,
    duration_seconds = input_duration_seconds
  where id = input_room_id;
end;
$$;

create or replace function public.leave_room(input_room_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid;
  membership_row public.room_players%rowtype;
  new_host public.room_players%rowtype;
  remaining_count integer;
begin
  current_user_id := auth.uid();
  if current_user_id is null then
    raise exception 'No hay sesion autenticada';
  end if;

  select *
  into membership_row
  from public.room_players
  where room_id = input_room_id
    and user_id = current_user_id;

  if membership_row.id is null then
    return;
  end if;

  delete from public.room_players
  where id = membership_row.id;

  select count(*)
  into remaining_count
  from public.room_players
  where room_id = input_room_id;

  if remaining_count = 0 then
    delete from public.rooms
    where id = input_room_id;
    return;
  end if;

  if membership_row.is_host then
    select *
    into new_host
    from public.room_players
    where room_id = input_room_id
    order by seat_order
    limit 1;

    update public.room_players
    set is_host = true
    where id = new_host.id;

    update public.rooms
    set host_user_id = new_host.user_id
    where id = input_room_id;
  end if;
end;
$$;

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
  select count(*)
  into deleted_count
  from deleted_rooms;

  return coalesce(deleted_count, 0);
end;
$$;

grant execute on function public.create_private_room(
  text,
  text,
  text,
  text[],
  boolean,
  integer,
  integer,
  integer,
  integer
) to authenticated;

grant execute on function public.join_private_room(text, text) to authenticated;
grant execute on function public.is_room_member(uuid) to authenticated;
grant execute on function public.set_room_ready(uuid, boolean) to authenticated;
grant execute on function public.update_room_config(uuid, text[], boolean, integer, integer) to authenticated;
grant execute on function public.leave_room(uuid) to authenticated;

select cron.schedule(
  'cleanup-expired-private-rooms',
  '0 * * * *',
  $$ select public.cleanup_expired_private_rooms(); $$
);
