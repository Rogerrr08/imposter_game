-- ============================================================================
-- 12 — Realtime Triggers: publicar deltas a canales privados
-- ============================================================================
-- Usa `realtime.send(payload, event, topic, private=true)` desde triggers
-- AFTER INSERT/UPDATE/DELETE para empujar deltas al canal privado del
-- match o de la sala. El cliente solo abre 2 conexiones WebSocket
-- (match:<id> + room:<id>) en lugar de 5–7.
--
-- Convención de topics:
--   match:<match_uuid>     → eventos de match, match_players, match_clues, match_votes
--   room:<room_uuid>       → eventos de rooms, room_players (presence sigue compartiendo este canal)
-- ============================================================================

-- ---------------------------------------------------------------------------
-- broadcast_match_change — para match_players, match_clues, match_votes
-- ---------------------------------------------------------------------------

create or replace function public.broadcast_match_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match_id uuid;
  v_topic text;
  v_event text;
  v_payload jsonb;
begin
  v_match_id := coalesce(new.match_id, old.match_id);
  v_topic := 'match:' || v_match_id::text;

  case tg_table_name
    when 'match_players' then
      v_event := 'player-updated';
      v_payload := jsonb_build_object(
        'id',                      coalesce(new.id, old.id),
        'match_id',                v_match_id,
        'user_id',                 coalesce(new.user_id, old.user_id),
        'display_name',            coalesce(new.display_name, old.display_name),
        'avatar_url',              coalesce(new.avatar_url, old.avatar_url),
        'role',                    coalesce(new.role, old.role),
        'seat_order',              coalesce(new.seat_order, old.seat_order),
        'hint',                    coalesce(new.hint, old.hint),
        'is_eliminated',           coalesce(new.is_eliminated, old.is_eliminated),
        'is_connected',            coalesce(new.is_connected, old.is_connected),
        'role_confirmed',          coalesce(new.role_confirmed, old.role_confirmed),
        'points',                  coalesce(new.points, old.points),
        'voted_incorrectly',       coalesce(new.voted_incorrectly, old.voted_incorrectly),
        'eliminated_by_failed_guess',
            coalesce(new.eliminated_by_failed_guess, old.eliminated_by_failed_guess),
        'guess_word',              coalesce(new.guess_word, old.guess_word),
        'created_at',              coalesce(new.created_at, old.created_at),
        'op',                      tg_op
      );

    when 'match_clues' then
      v_event := 'clue-added';
      v_payload := to_jsonb(new);

    when 'match_votes' then
      -- Incluye `target_player_id`: la UI de voting_phase usa el conteo
      -- por target en tiempo real (`votesByTarget`) durante la fase de
      -- votación. La RLS actual de `match_votes` ya expone ese campo a
      -- todos los miembros del match, así que no se gana privacidad
      -- ocultándolo aquí.
      v_event := 'vote-added';
      v_payload := to_jsonb(new);

    else
      return null;
  end case;

  perform realtime.send(v_payload, v_event, v_topic, true);
  return null;
end;
$$;

-- ---------------------------------------------------------------------------
-- broadcast_matches_change — para tabla `matches` (UPDATE)
-- ---------------------------------------------------------------------------

create or replace function public.broadcast_matches_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_topic text;
begin
  v_topic := 'match:' || new.id::text;
  perform realtime.send(to_jsonb(new), 'match-updated', v_topic, true);
  return null;
end;
$$;

-- ---------------------------------------------------------------------------
-- broadcast_room_change — para `rooms` y `room_players`
-- ---------------------------------------------------------------------------

create or replace function public.broadcast_room_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_room_id uuid;
  v_topic text;
  v_event text;
  v_payload jsonb;
begin
  if tg_table_name = 'rooms' then
    v_room_id := coalesce(new.id, old.id);
    v_event := 'room-updated';
    v_payload := to_jsonb(coalesce(new, old));
  else  -- room_players
    v_room_id := coalesce(new.room_id, old.room_id);
    if tg_op = 'DELETE' then
      v_event := 'player-left';
      v_payload := jsonb_build_object(
        'id',      old.id,
        'room_id', old.room_id,
        'user_id', old.user_id
      );
    elsif tg_op = 'INSERT' then
      v_event := 'player-joined';
      v_payload := to_jsonb(new);
    else
      v_event := 'player-updated';
      v_payload := to_jsonb(new);
    end if;
  end if;

  v_topic := 'room:' || v_room_id::text;
  perform realtime.send(v_payload, v_event, v_topic, true);
  return null;
end;
$$;

-- ---------------------------------------------------------------------------
-- Attach triggers (idempotente vía drop if exists)
-- ---------------------------------------------------------------------------

drop trigger if exists tr_broadcast_matches on public.matches;
create trigger tr_broadcast_matches
  after update on public.matches
  for each row execute function public.broadcast_matches_change();

drop trigger if exists tr_broadcast_match_players on public.match_players;
create trigger tr_broadcast_match_players
  after insert or update on public.match_players
  for each row execute function public.broadcast_match_change();

drop trigger if exists tr_broadcast_match_clues on public.match_clues;
create trigger tr_broadcast_match_clues
  after insert on public.match_clues
  for each row execute function public.broadcast_match_change();

drop trigger if exists tr_broadcast_match_votes on public.match_votes;
create trigger tr_broadcast_match_votes
  after insert on public.match_votes
  for each row execute function public.broadcast_match_change();

drop trigger if exists tr_broadcast_rooms on public.rooms;
create trigger tr_broadcast_rooms
  after update on public.rooms
  for each row execute function public.broadcast_room_change();

drop trigger if exists tr_broadcast_room_players on public.room_players;
create trigger tr_broadcast_room_players
  after insert or update or delete on public.room_players
  for each row execute function public.broadcast_room_change();
