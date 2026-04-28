-- ============================================================================
-- 14 — Quitar tablas del publication `supabase_realtime`
-- ============================================================================
-- Una vez el cliente migró a Broadcast from Database (Fase 2), las tablas
-- de match/room ya no necesitan publicar cambios para Postgres Changes. Al
-- removerlas se libera un hilo del worker de Realtime y se reduce la carga
-- de WAL → publication.
--
-- ⚠️  IMPORTANTE: Ejecutar SOLO después de:
--     1. Confirmar que toda la base instalada corre ≥ v2.2.0 (cliente ya
--        usa los canales broadcast `match:<id>` y `room:<id>`).
--     2. Smoke test multi-cliente exitoso del nuevo path.
--
-- Si algún cliente con v2.1.x intenta conectarse después de ejecutar esto,
-- sus pantallas online quedarán con datos vacíos. Forzar update via app
-- store o pedirle a los usuarios que actualicen.
--
-- Reversible: las tablas se pueden re-agregar al publication con
-- `alter publication supabase_realtime add table public.<tabla>;`
-- ============================================================================

alter publication supabase_realtime drop table public.matches;
alter publication supabase_realtime drop table public.match_players;
alter publication supabase_realtime drop table public.match_clues;
alter publication supabase_realtime drop table public.match_votes;
alter publication supabase_realtime drop table public.rooms;
alter publication supabase_realtime drop table public.room_players;
