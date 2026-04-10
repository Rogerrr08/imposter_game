-- ============================================================================
-- 08 — Spectator RLS: permitir a miembros de sala leer datos de partida
-- ============================================================================
-- Ejecutar DESPUES de 01-schema.sql
-- ============================================================================

-- --------------------------------------------------------------------------
-- Helper: es miembro de la sala asociada a un match
-- --------------------------------------------------------------------------

create or replace function public.is_room_member_of_match(p_match_id uuid)
returns boolean language sql security definer stable set search_path = public
as $$ select exists (
  select 1 from public.room_players rp
  inner join public.matches m on m.room_id = rp.room_id
  where m.id = p_match_id and rp.user_id = auth.uid()
); $$;

-- --------------------------------------------------------------------------
-- Actualizar policies de SELECT para incluir miembros de sala
-- --------------------------------------------------------------------------

-- matches
drop policy if exists "match_players_can_read_match" on public.matches;
create policy "match_players_can_read_match" on public.matches
  for select using (public.is_match_player(id) or public.is_room_member_of_match(id));

-- match_players
drop policy if exists "match_members_can_read_players" on public.match_players;
create policy "match_members_can_read_players" on public.match_players
  for select using (public.is_match_player(match_id) or public.is_room_member_of_match(match_id));

-- match_clues
drop policy if exists "match_members_can_read_clues" on public.match_clues;
create policy "match_members_can_read_clues" on public.match_clues
  for select using (public.is_match_player(match_id) or public.is_room_member_of_match(match_id));

-- match_votes
drop policy if exists "match_members_can_read_votes" on public.match_votes;
create policy "match_members_can_read_votes" on public.match_votes
  for select using (public.is_match_player(match_id) or public.is_room_member_of_match(match_id));

-- --------------------------------------------------------------------------
-- Grants
-- --------------------------------------------------------------------------

grant execute on function public.is_room_member_of_match(uuid) to authenticated;
