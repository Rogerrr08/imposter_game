-- ============================================================================
-- 13 — get_match_snapshot RPC
-- ============================================================================
-- Devuelve un snapshot completo del estado del match para el cliente. Se llama
-- al abrir el canal `match:<id>` (una sola vez por sesión) y luego el cliente
-- aplica deltas en memoria desde los broadcasts. Si la conexión se cae, se
-- vuelve a invocar al re-suscribirse para reconciliar.
--
-- Forma del payload:
--   {
--     "match":   <jsonb>,         -- row de matches
--     "players": <jsonb[]>,       -- rows de match_players ordenados por seat_order
--     "clues":   <jsonb[]>,       -- rows de match_clues
--     "votes":   <jsonb[]>        -- rows de match_votes (sin target_player_id)
--   }
-- ============================================================================

create or replace function public.get_match_snapshot(input_match_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match   jsonb;
  v_players jsonb;
  v_clues   jsonb;
  v_votes   jsonb;
begin
  -- Membresía: solo jugadores del match (RLS no aplica con SECURITY DEFINER,
  -- por eso validamos explícitamente).
  if not public.is_match_player(input_match_id) then
    raise exception 'Not a member of this match'
      using errcode = '42501';  -- insufficient_privilege
  end if;

  select to_jsonb(m) into v_match
  from public.matches m
  where m.id = input_match_id;

  if v_match is null then
    raise exception 'Match not found' using errcode = 'P0002';
  end if;

  select coalesce(jsonb_agg(to_jsonb(mp) order by mp.seat_order), '[]'::jsonb)
    into v_players
  from public.match_players mp
  where mp.match_id = input_match_id;

  select coalesce(jsonb_agg(to_jsonb(mc) order by mc.round_number, mc.turn_order), '[]'::jsonb)
    into v_clues
  from public.match_clues mc
  where mc.match_id = input_match_id;

  -- Incluye target_player_id para que el cliente reconstruya el conteo
  -- de votos por target (UI de voting_phase) tras un reconnect.
  select coalesce(jsonb_agg(to_jsonb(mv) order by mv.created_at), '[]'::jsonb)
    into v_votes
  from public.match_votes mv
  where mv.match_id = input_match_id;

  return jsonb_build_object(
    'match',   v_match,
    'players', v_players,
    'clues',   v_clues,
    'votes',   v_votes
  );
end;
$$;

grant execute on function public.get_match_snapshot(uuid) to authenticated;
