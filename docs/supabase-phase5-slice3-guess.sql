-- ============================================================================
-- Fase 5 Slice 3: Adivinanza del impostor + finalización + revancha
-- ============================================================================
-- Ejecutar DESPUES de supabase-phase5-slice2-voting.sql
-- ============================================================================

-- --------------------------------------------------------------------------
-- RPC: submit_impostor_guess
-- --------------------------------------------------------------------------
-- Called when the eliminated impostor submits a guess for the secret word.
-- If correct: impostors win immediately.
-- If incorrect: mark as failed guess, check if game continues or ends.
-- --------------------------------------------------------------------------

create or replace function public.submit_impostor_guess(
  input_match_id uuid,
  input_guess text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid;
  the_match public.matches%rowtype;
  my_player public.match_players%rowtype;
  secret_word text;
  normalized_guess text;
  normalized_word text;
  guess_correct boolean;
  active_impostors integer;
  active_civils integer;
begin
  current_user_id := auth.uid();
  if current_user_id is null then
    raise exception 'No hay sesion autenticada';
  end if;

  select * into the_match from public.matches
  where id = input_match_id for update;

  if the_match.id is null then raise exception 'Match no encontrado'; end if;
  if the_match.status <> 'active' then raise exception 'La partida no esta activa'; end if;
  if the_match.current_phase <> 'impostor_guess' then raise exception 'No es la fase de adivinanza'; end if;

  select * into my_player from public.match_players
  where match_id = input_match_id and user_id = current_user_id;
  if my_player.id is null then raise exception 'No eres jugador de este match'; end if;
  if my_player.role <> 'impostor' then raise exception 'Solo los impostores pueden adivinar'; end if;
  if not my_player.is_eliminated then raise exception 'Solo el impostor eliminado puede adivinar'; end if;

  -- Get the secret word
  secret_word := the_match.word;

  -- Normalize both for comparison (lowercase, trim)
  normalized_guess := lower(trim(input_guess));
  normalized_word := lower(trim(secret_word));

  guess_correct := (normalized_guess = normalized_word);

  if guess_correct then
    -- Impostors win!
    update public.matches
    set current_phase = 'finished',
        status = 'finished',
        state_version = state_version + 1,
        updated_at = timezone('utc', now())
    where id = input_match_id;

    -- Return room to waiting
    update public.rooms
    set status = 'waiting'
    where id = the_match.room_id;

    return jsonb_build_object(
      'correct', true,
      'result', 'game_over',
      'winner', 'impostors',
      'guess', input_guess,
      'word', secret_word
    );
  end if;

  -- Incorrect guess — mark player
  update public.match_players
  set eliminated_by_failed_guess = true
  where id = my_player.id;

  -- Check remaining game state
  select
    count(*) filter (where not is_eliminated and role = 'impostor'),
    count(*) filter (where not is_eliminated and role = 'civil')
  into active_impostors, active_civils
  from public.match_players
  where match_id = input_match_id;

  if active_impostors = 0 then
    -- All impostors eliminated — civils win
    update public.matches
    set current_phase = 'finished',
        status = 'finished',
        state_version = state_version + 1,
        updated_at = timezone('utc', now())
    where id = input_match_id;

    update public.rooms
    set status = 'waiting'
    where id = the_match.room_id;

    return jsonb_build_object(
      'correct', false,
      'result', 'game_over',
      'winner', 'civils',
      'guess', input_guess,
      'word', secret_word
    );
  end if;

  -- Game continues — next round of clues
  update public.matches
  set current_phase = 'clue_writing',
      current_round = the_match.current_round + 1,
      current_turn_index = (
        select seat_order
        from public.match_players
        where match_id = input_match_id
          and not is_eliminated
        order by seat_order asc
        limit 1
      ),
      state_version = state_version + 1,
      updated_at = timezone('utc', now())
  where id = input_match_id;

  return jsonb_build_object(
    'correct', false,
    'result', 'continue',
    'guess', input_guess,
    'word', secret_word,
    'next_phase', 'clue_writing',
    'next_round', the_match.current_round + 1
  );
end;
$$;

-- --------------------------------------------------------------------------
-- RPC: skip_impostor_guess
-- --------------------------------------------------------------------------
-- Called when the eliminated impostor decides not to guess.
-- Checks if the game should end or continue to next round.
-- --------------------------------------------------------------------------

create or replace function public.skip_impostor_guess(input_match_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid;
  the_match public.matches%rowtype;
  my_player public.match_players%rowtype;
  active_impostors integer;
  active_civils integer;
begin
  current_user_id := auth.uid();
  if current_user_id is null then
    raise exception 'No hay sesion autenticada';
  end if;

  select * into the_match from public.matches
  where id = input_match_id for update;

  if the_match.id is null then raise exception 'Match no encontrado'; end if;
  if the_match.status <> 'active' then raise exception 'La partida no esta activa'; end if;
  if the_match.current_phase <> 'impostor_guess' then raise exception 'No es la fase de adivinanza'; end if;

  select * into my_player from public.match_players
  where match_id = input_match_id and user_id = current_user_id;
  if my_player.id is null then raise exception 'No eres jugador de este match'; end if;
  if my_player.role <> 'impostor' then raise exception 'Solo los impostores pueden pasar'; end if;
  if not my_player.is_eliminated then raise exception 'Solo el impostor eliminado puede pasar'; end if;

  -- Check remaining game state
  select
    count(*) filter (where not is_eliminated and role = 'impostor'),
    count(*) filter (where not is_eliminated and role = 'civil')
  into active_impostors, active_civils
  from public.match_players
  where match_id = input_match_id;

  if active_impostors = 0 then
    -- All impostors eliminated — civils win
    update public.matches
    set current_phase = 'finished',
        status = 'finished',
        state_version = state_version + 1,
        updated_at = timezone('utc', now())
    where id = input_match_id;

    update public.rooms
    set status = 'waiting'
    where id = the_match.room_id;

    return jsonb_build_object(
      'result', 'game_over',
      'winner', 'civils'
    );
  end if;

  -- Game continues — next round of clues
  update public.matches
  set current_phase = 'clue_writing',
      current_round = the_match.current_round + 1,
      current_turn_index = (
        select seat_order
        from public.match_players
        where match_id = input_match_id
          and not is_eliminated
        order by seat_order asc
        limit 1
      ),
      state_version = state_version + 1,
      updated_at = timezone('utc', now())
  where id = input_match_id;

  return jsonb_build_object(
    'result', 'continue',
    'next_phase', 'clue_writing',
    'next_round', the_match.current_round + 1
  );
end;
$$;

-- --------------------------------------------------------------------------
-- RPC: calculate_match_scores
-- --------------------------------------------------------------------------
-- Called when the match finishes to calculate final scores for all players.
-- Uses Classic mode scoring rules:
--   Civil win: +2 to civils who never voted incorrectly, +2 per correct impostor vote
--   Impostor win: +5 if not eliminated, +1 if eliminated (not by failed guess)
--   Per-elimination: -1 to civils who voted for eliminated civil
--                    +2 to civils who voted for eliminated impostor
--   Failed guess: 0 points for that impostor
-- --------------------------------------------------------------------------

create or replace function public.calculate_match_scores(input_match_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid;
  the_match public.matches%rowtype;
  winner text;
  active_impostors integer;
  player_record record;
  scores jsonb := '[]'::jsonb;
begin
  current_user_id := auth.uid();
  if current_user_id is null then
    raise exception 'No hay sesion autenticada';
  end if;

  select * into the_match from public.matches
  where id = input_match_id;

  if the_match.id is null then raise exception 'Match no encontrado'; end if;
  if the_match.status <> 'finished' then raise exception 'La partida no ha terminado'; end if;

  -- Verify caller is a player
  if not exists (
    select 1 from public.match_players
    where match_id = input_match_id and user_id = current_user_id
  ) then
    raise exception 'No eres jugador de este match';
  end if;

  -- Check if scores were already calculated (idempotent — multiple clients may call)
  -- We use a simple check: if any player has points > 0, scores were already applied
  if exists (
    select 1 from public.match_players
    where match_id = input_match_id and points > 0
  ) then
    -- Already calculated — just return the current scores
    select count(*) filter (where not is_eliminated and role = 'impostor')
    into active_impostors
    from public.match_players
    where match_id = input_match_id;

    if active_impostors = 0 then
      winner := 'civils';
    else
      winner := 'impostors';
    end if;
  else
    -- Determine winner
    select count(*) filter (where not is_eliminated and role = 'impostor')
    into active_impostors
    from public.match_players
    where match_id = input_match_id;

    if active_impostors = 0 then
      winner := 'civils';
    else
      winner := 'impostors';
    end if;

    -- Calculate points for each player
    if winner = 'civils' then
      -- Civil win scoring: +2 to civils who never voted incorrectly
      update public.match_players
      set points = points + 2
      where match_id = input_match_id
        and role = 'civil'
        and not voted_incorrectly;

      -- Impostor loss: 0 if eliminated by failed guess, +1 if eliminated normally
      update public.match_players
      set points = points + 1
      where match_id = input_match_id
        and role = 'impostor'
        and is_eliminated
        and not eliminated_by_failed_guess;
    else
      -- Impostor win scoring
      -- +5 if impostor not eliminated
      update public.match_players
      set points = points + 5
      where match_id = input_match_id
        and role = 'impostor'
        and not is_eliminated;

      -- +1 if impostor eliminated but not by failed guess
      update public.match_players
      set points = points + 1
      where match_id = input_match_id
        and role = 'impostor'
        and is_eliminated
        and not eliminated_by_failed_guess;
    end if;
  end if;

  -- Build scores array
  select jsonb_agg(
    jsonb_build_object(
      'player_id', mp.id,
      'user_id', mp.user_id,
      'display_name', mp.display_name,
      'role', mp.role,
      'points', mp.points,
      'is_eliminated', mp.is_eliminated,
      'voted_incorrectly', mp.voted_incorrectly,
      'eliminated_by_failed_guess', mp.eliminated_by_failed_guess
    ) order by mp.points desc, mp.seat_order asc
  ) into scores
  from public.match_players mp
  where mp.match_id = input_match_id;

  return jsonb_build_object(
    'winner', winner,
    'word', the_match.word,
    'category', the_match.category,
    'scores', coalesce(scores, '[]'::jsonb)
  );
end;
$$;

-- --------------------------------------------------------------------------
-- RPC: rematch
-- --------------------------------------------------------------------------
-- Called by the host to start a new match in the same room.
-- Reuses the room configuration. All current room players join the new match.
-- --------------------------------------------------------------------------
-- NOTE: rematch simply starts a new match using the existing start_match RPC.
-- The client will call start_match again — no new SQL function needed.
-- The room is already back to 'waiting' status after match finishes.
-- --------------------------------------------------------------------------

-- --------------------------------------------------------------------------
-- Grants
-- --------------------------------------------------------------------------

grant execute on function public.submit_impostor_guess(uuid, text) to authenticated;
grant execute on function public.skip_impostor_guess(uuid) to authenticated;
grant execute on function public.calculate_match_scores(uuid) to authenticated;
