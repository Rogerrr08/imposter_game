-- ============================================================================
-- 01 — Schema: tablas, columnas, indices, RLS, Realtime, extensiones
-- ============================================================================
-- Ejecutar PRIMERO. Define toda la estructura de base de datos.
-- ============================================================================

-- Extensions
create extension if not exists pgcrypto;
create extension if not exists pg_cron;

-- ============================================================================
-- ROOMS & ROOM_PLAYERS
-- ============================================================================

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

-- ============================================================================
-- MATCHES, MATCH_PLAYERS, MATCH_CLUES, MATCH_VOTES
-- ============================================================================

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
      'impostor_choice', 'impostor_guess', 'finished'
    )),
  current_round integer not null default 1,
  current_turn_index integer not null default 0,
  starting_player_id uuid,
  winner_override text default null,
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
  is_connected boolean not null default true,
  role_confirmed boolean not null default false,
  points integer not null default 0,
  voted_incorrectly boolean not null default false,
  eliminated_by_failed_guess boolean not null default false,
  guess_word text default null,
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

-- ============================================================================
-- INDICES
-- ============================================================================

create index if not exists rooms_code_idx on public.rooms (code);
create index if not exists room_players_room_id_idx on public.room_players (room_id);
create index if not exists room_players_user_id_idx on public.room_players (user_id);
create index if not exists rooms_expires_at_idx on public.rooms (expires_at);
create index if not exists room_players_expires_at_idx on public.room_players (expires_at);
create index if not exists idx_matches_room_id on public.matches(room_id);
create index if not exists idx_matches_status on public.matches(status);
create index if not exists idx_match_players_match_id on public.match_players(match_id);
create index if not exists idx_match_players_user_id on public.match_players(user_id);
create index if not exists idx_match_clues_match_id on public.match_clues(match_id);
create index if not exists idx_match_votes_match_id on public.match_votes(match_id);

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================

alter table public.rooms enable row level security;
alter table public.room_players enable row level security;
alter table public.matches enable row level security;
alter table public.match_players enable row level security;
alter table public.match_clues enable row level security;
alter table public.match_votes enable row level security;

-- Helper: is user a room member?
create or replace function public.is_room_member(input_room_id uuid)
returns boolean
language sql security definer stable set search_path = public
as $$
  select exists (
    select 1 from public.room_players
    where room_id = input_room_id and user_id = auth.uid()
  );
$$;

-- Helper: is user a match player?
create or replace function public.is_match_player(p_match_id uuid)
returns boolean
language sql security definer set search_path = public
as $$
  select exists (
    select 1 from public.match_players
    where match_id = p_match_id and user_id = auth.uid()
  );
$$;

-- Room policies
drop policy if exists rooms_select_for_members on public.rooms;
create policy rooms_select_for_members on public.rooms
  for select to authenticated using (public.is_room_member(id));

drop policy if exists room_players_select_for_members on public.room_players;
create policy room_players_select_for_members on public.room_players
  for select to authenticated using (public.is_room_member(room_id));

-- Match policies
create policy "match_players_can_read_match" on public.matches
  for select using (public.is_match_player(id));

create policy "match_members_can_read_players" on public.match_players
  for select using (public.is_match_player(match_id));

create policy "match_members_can_read_clues" on public.match_clues
  for select using (public.is_match_player(match_id));

create policy "match_players_can_insert_clues" on public.match_clues
  for insert with check (public.is_match_player(match_id));

create policy "match_members_can_read_votes" on public.match_votes
  for select using (public.is_match_player(match_id));

create policy "match_players_can_insert_votes" on public.match_votes
  for insert with check (public.is_match_player(match_id));

-- ============================================================================
-- REALTIME
-- ============================================================================

alter table public.rooms replica identity full;
alter table public.room_players replica identity full;
alter table public.matches replica identity full;
alter table public.match_players replica identity full;
alter table public.match_clues replica identity full;
alter table public.match_votes replica identity full;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'rooms') then
      alter publication supabase_realtime add table public.rooms;
    end if;
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'room_players') then
      alter publication supabase_realtime add table public.room_players;
    end if;
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'matches') then
      alter publication supabase_realtime add table public.matches;
    end if;
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'match_players') then
      alter publication supabase_realtime add table public.match_players;
    end if;
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'match_clues') then
      alter publication supabase_realtime add table public.match_clues;
    end if;
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'match_votes') then
      alter publication supabase_realtime add table public.match_votes;
    end if;
  end if;
end;
$$;

-- ============================================================================
-- GRANTS (helpers)
-- ============================================================================

grant execute on function public.is_room_member(uuid) to authenticated;
grant execute on function public.is_match_player(uuid) to authenticated;
