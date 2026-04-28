-- Índices compuestos para reducir latencia en RPCs y queries del refactor
-- Realtime (v2.2.0). Aplicar antes de cualquier otro cambio del plan; ya
-- aporta sin necesidad de tocar el cliente.
--
-- Beneficiarios principales:
--   - submit_clue / get_match_snapshot         → match_clues(match_id, round_number)
--   - resolve_votes                            → match_votes(match_id, round_number, is_tiebreak)
--   - lecturas ordenadas de jugadores          → match_players(match_id, seat_order)
--   - getActiveMatchForRoom                    → matches(room_id, status) WHERE status = 'active'

create index if not exists idx_match_clues_match_round
  on public.match_clues(match_id, round_number);

create index if not exists idx_match_votes_match_round
  on public.match_votes(match_id, round_number, is_tiebreak);

create index if not exists idx_match_players_match_seat
  on public.match_players(match_id, seat_order);

create index if not exists idx_matches_room_status
  on public.matches(room_id, status) where status = 'active';
