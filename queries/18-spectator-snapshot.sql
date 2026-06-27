-- ============================================================================
-- 18 — Espectador robusto (Fase 4): acceso de miembros de la sala al match
-- ============================================================================
-- Aplicado vía MCP el 2026-06-26. Idempotente.
--
-- Bug: un espectador (miembro de la sala que NO es jugador del match) no podía
-- cargar `get_match_snapshot` (gate `is_match_player`) ni suscribirse al
-- broadcast `match:<id>` (RLS de realtime.messages exigía is_match_player) →
-- se quedaba en "cargando" para siempre.
--
-- Fix: dejar entrar a los miembros de la sala (jugador O espectador). El diseño
-- ya muestra roles a los espectadores (eliminados/tardíos ven roles en las
-- pistas), así que el snapshot/broadcast devuelven los mismos datos.
-- ============================================================================

-- Helper: el usuario es miembro de la sala del match (jugador o espectador).
create or replace function public.is_match_room_member(p_match_id uuid)
returns boolean language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.room_players rp
    join public.matches m on m.room_id = rp.room_id
    where m.id = p_match_id and rp.user_id = auth.uid()
  );
$$;

grant execute on function public.is_match_room_member(uuid) to authenticated;

-- get_match_snapshot: permitir también a miembros de la sala (espectadores).
create or replace function public.get_match_snapshot(input_match_id uuid)
returns jsonb language plpgsql security definer set search_path = public
as $$
declare
  v_match jsonb; v_players jsonb; v_clues jsonb; v_votes jsonb;
begin
  if not (public.is_match_player(input_match_id)
          or public.is_match_room_member(input_match_id)) then
    raise exception 'Not a member of this match' using errcode = '42501';
  end if;

  select to_jsonb(m) into v_match from public.matches m where m.id = input_match_id;
  if v_match is null then raise exception 'Match not found' using errcode = 'P0002'; end if;

  select coalesce(jsonb_agg(to_jsonb(mp) order by mp.seat_order), '[]'::jsonb) into v_players
  from public.match_players mp where mp.match_id = input_match_id;

  select coalesce(jsonb_agg(to_jsonb(mc) order by mc.round_number, mc.turn_order), '[]'::jsonb) into v_clues
  from public.match_clues mc where mc.match_id = input_match_id;

  select coalesce(jsonb_agg(to_jsonb(mv) order by mv.created_at), '[]'::jsonb) into v_votes
  from public.match_votes mv where mv.match_id = input_match_id;

  return jsonb_build_object('match', v_match, 'players', v_players, 'clues', v_clues, 'votes', v_votes);
end;
$$;

grant execute on function public.get_match_snapshot(uuid) to authenticated;

-- Realtime: permitir a miembros de la sala suscribirse al broadcast del match.
alter policy authenticated_read_match_room_broadcast on realtime.messages
using (
  ((realtime.topic() like 'match:%') and (
     public.is_match_player((substring(realtime.topic() from 7))::uuid)
     or public.is_match_room_member((substring(realtime.topic() from 7))::uuid)
  ))
  or ((realtime.topic() like 'room:%') and public.is_room_member((substring(realtime.topic() from 6))::uuid))
);
