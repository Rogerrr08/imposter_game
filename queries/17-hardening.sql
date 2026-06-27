-- ============================================================================
-- 17 — Hardening de seguridad (auditoría 2026-06-26 vía Supabase advisors)
-- ============================================================================
-- Idempotente. Aplicado vía MCP el 2026-06-26. Cubre:
--   1. search_path fijo en funciones que no lo tenían (function_search_path_mutable).
--   2. revoke EXECUTE de funciones internas (triggers/cron) al rol PUBLIC
--      (anon/authenticated lo heredan de PUBLIC; revocar de PUBLIC es lo que
--      realmente cierra el anon/authenticated_security_definer_function_executable).
--   4. índices para FKs sin cubrir (unindexed_foreign_keys).
-- Se DIFIERE el punto 3 (auth_rls_initplan: envolver auth.uid() en (select ...)):
--   es solo performance, irrelevante a la escala actual, y recrear las policies
--   de profiles tiene riesgo > beneficio. Revisitar si el proyecto escala.
-- ============================================================================

-- 1. search_path fijo en SECURITY DEFINER / funciones sin set.
--    '' para las que solo usan built-ins o referencias calificadas; 'public'
--    para matches_secret_word, que llama a normalize_for_match sin calificar.
alter function public.handle_new_user() set search_path = '';
alter function public.normalize_for_match(text) set search_path = '';
alter function public.matches_secret_word(text, text) set search_path = public;

-- 2. Revocar EXECUTE de funciones internas a los clientes (defensa en
--    profundidad; los triggers no chequean EXECUTE y el cron corre como postgres).
revoke execute on function public.broadcast_match_change() from public;
revoke execute on function public.broadcast_matches_change() from public;
revoke execute on function public.broadcast_room_change() from public;
revoke execute on function public.stamp_turn_deadline() from public;
revoke execute on function public.check_player_heartbeats() from public;
revoke execute on function public.cleanup_orphaned_matches() from public;
revoke execute on function public.cleanup_expired_private_rooms() from public;
revoke execute on function public.reassign_host_if_needed(uuid) from public;

-- 4. Índices para foreign keys sin cubrir.
create index if not exists idx_match_clues_player_id
  on public.match_clues(player_id);
create index if not exists idx_match_votes_voter_id
  on public.match_votes(voter_id);
create index if not exists idx_match_votes_target_player_id
  on public.match_votes(target_player_id);
create index if not exists idx_rooms_host_user_id
  on public.rooms(host_user_id);
