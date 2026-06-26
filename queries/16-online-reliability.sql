-- ============================================================================
-- 16 — Confiabilidad online v2 (Fase 2: timer autoritativo del servidor)
-- ============================================================================
-- Aplicar a mano en el SQL Editor de Supabase. Idempotente.
--
-- Resumen:
--   1. matches.turn_ends_at  — deadline del turno de pistas (timestamptz).
--   2. trigger stamp_turn_deadline — lo estampa al entrar a clue_writing o al
--      cambiar de turno (cubre confirm_roles, submit_clue, skip_clue_turn y los
--      reinicios de ronda en resolve_votes/impostor_*; ninguna RPC se edita).
--   3. server_now() — hora del servidor para que el cliente mida su offset de
--      reloj (elimina el skew; el countdown es igual para todos).
--   4. skip_clue_turn(uuid, int) — overload con compare-and-swap para evitar el
--      over-skip ("se salta a las personas") cuando varios clientes detectan el
--      timeout a la vez.
--
-- Nota: matches.turn_ends_at se incluye solo en el broadcast (`to_jsonb(new)` en
-- broadcast_matches_change) y en get_match_snapshot (`to_jsonb(m)`). No hay que
-- tocar 12 ni 13.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Columna del deadline de turno
-- ---------------------------------------------------------------------------

alter table public.matches
  add column if not exists turn_ends_at timestamptz;

-- ---------------------------------------------------------------------------
-- 2. Trigger: estampa turn_ends_at al iniciar cada turno de clue_writing
-- ---------------------------------------------------------------------------
-- 32s = 30s visibles + ~2s de colchón para absorber la latencia de propagación
-- del aviso "es tu turno". El cliente muestra clamp(restante, 0, 30).

create or replace function public.stamp_turn_deadline()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.current_phase = 'clue_writing' and (
       tg_op = 'INSERT'
       or old.current_phase is distinct from 'clue_writing'
       or new.current_turn_index is distinct from old.current_turn_index
     ) then
    new.turn_ends_at := now() + interval '32 seconds';
  elsif new.current_phase is distinct from 'clue_writing' then
    new.turn_ends_at := null;
  end if;
  return new;
end;
$$;

drop trigger if exists tr_stamp_turn_deadline on public.matches;
create trigger tr_stamp_turn_deadline
  before insert or update on public.matches
  for each row execute function public.stamp_turn_deadline();

-- ---------------------------------------------------------------------------
-- 3. server_now() — hora del servidor (para el offset de reloj del cliente)
-- ---------------------------------------------------------------------------

create or replace function public.server_now()
returns timestamptz
language sql
security definer
set search_path = public
stable
as $$
  select now();
$$;

grant execute on function public.server_now() to authenticated;

-- ---------------------------------------------------------------------------
-- 4. skip_clue_turn con compare-and-swap (evita el over-skip)
-- ---------------------------------------------------------------------------
-- Overload de skip_clue_turn que recibe el índice de turno esperado. Si el
-- turno ya avanzó (otro cliente skipeó primero), es un no-op. La versión vieja
-- skip_clue_turn(uuid) queda intacta pero el cliente pasa a usar esta.

create or replace function public.skip_clue_turn(
  input_match_id uuid,
  expected_turn_index int
)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  current_user_id uuid;
  the_match public.matches%rowtype;
  next_seat integer;
  phase_after text;
begin
  current_user_id := auth.uid();
  if current_user_id is null then raise exception 'No hay sesion autenticada'; end if;

  select * into the_match from public.matches where id = input_match_id for update;
  if the_match.id is null then raise exception 'Match no encontrado'; end if;
  if the_match.status <> 'active' or the_match.current_phase <> 'clue_writing' then
    return jsonb_build_object('skipped', false);
  end if;

  -- Compare-and-swap: si el turno ya avanzó, este skip es un no-op.
  if expected_turn_index is not null
     and the_match.current_turn_index <> expected_turn_index then
    return jsonb_build_object('skipped', false);
  end if;

  if not exists (
    select 1 from public.match_players
    where match_id = input_match_id and user_id = current_user_id
  ) then raise exception 'No eres jugador de este match'; end if;

  -- Siguiente jugador no eliminado que aún no dio pista esta ronda (hacia adelante).
  select mp.seat_order into next_seat
  from public.match_players mp
  where mp.match_id = input_match_id
    and not mp.is_eliminated
    and mp.seat_order > the_match.current_turn_index
    and not exists (
      select 1 from public.match_clues mc
      where mc.match_id = input_match_id
        and mc.round_number = the_match.current_round
        and mc.player_id = mp.id
    )
  order by mp.seat_order asc limit 1;

  -- Wrap-around (hacia atrás).
  if next_seat is null then
    select mp.seat_order into next_seat
    from public.match_players mp
    where mp.match_id = input_match_id
      and not mp.is_eliminated
      and mp.seat_order < the_match.current_turn_index
      and not exists (
        select 1 from public.match_clues mc
        where mc.match_id = input_match_id
          and mc.round_number = the_match.current_round
          and mc.player_id = mp.id
      )
    order by mp.seat_order asc limit 1;
  end if;

  if next_seat is not null then
    phase_after := 'clue_writing';
    update public.matches
    set current_turn_index = next_seat, state_version = state_version + 1, updated_at = timezone('utc', now())
    where id = input_match_id;
  else
    phase_after := 'voting';
    update public.matches
    set current_phase = 'voting', current_turn_index = 0,
        state_version = state_version + 1, updated_at = timezone('utc', now())
    where id = input_match_id;
  end if;

  return jsonb_build_object('skipped', true, 'next_phase', phase_after);
end;
$$;

grant execute on function public.skip_clue_turn(uuid, int) to authenticated;
