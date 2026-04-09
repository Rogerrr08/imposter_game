-- ============================================================================
-- 04 — Game phases: role reveal, clues, voting, impostor choice/guess
-- ============================================================================
-- Ejecutar DESPUES de 03-match-lifecycle.sql
-- ============================================================================

-- --------------------------------------------------------------------------
-- confirm_role_reveal
-- --------------------------------------------------------------------------

create or replace function public.confirm_role_reveal(input_match_id uuid)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  current_user_id uuid;
  the_match public.matches%rowtype;
  my_player public.match_players%rowtype;
  total_active integer;
  total_confirmed integer;
  all_confirmed boolean;
begin
  current_user_id := auth.uid();
  if current_user_id is null then raise exception 'No hay sesion autenticada'; end if;

  select * into the_match from public.matches where id = input_match_id for update;
  if the_match.id is null then raise exception 'Match no encontrado'; end if;
  if the_match.status <> 'active' then raise exception 'La partida no esta activa'; end if;

  if the_match.current_phase <> 'role_reveal' then
    return jsonb_build_object('phase_advanced', false, 'already_confirmed', true);
  end if;

  select * into my_player from public.match_players
  where match_id = input_match_id and user_id = current_user_id;
  if my_player.id is null then raise exception 'No eres jugador de este match'; end if;

  if my_player.role_confirmed then
    return jsonb_build_object('phase_advanced', false, 'already_confirmed', true);
  end if;

  update public.match_players set role_confirmed = true where id = my_player.id;

  select
    count(*) filter (where not is_eliminated),
    count(*) filter (where not is_eliminated and role_confirmed)
  into total_active, total_confirmed
  from public.match_players where match_id = input_match_id;

  all_confirmed := (total_confirmed >= total_active);

  if all_confirmed then
    update public.matches
    set current_phase = 'clue_writing',
        current_turn_index = (
          select seat_order from public.match_players
          where id = the_match.starting_player_id
        ),
        state_version = state_version + 1,
        updated_at = timezone('utc', now())
    where id = input_match_id;
  end if;

  return jsonb_build_object('phase_advanced', all_confirmed, 'already_confirmed', false);
end;
$$;

-- --------------------------------------------------------------------------
-- submit_clue (with not-exists check to prevent stuck turns)
-- --------------------------------------------------------------------------

create or replace function public.submit_clue(
  input_match_id uuid,
  input_clue text
)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  current_user_id uuid;
  the_match public.matches%rowtype;
  my_player public.match_players%rowtype;
  next_seat integer;
  phase_after text;
begin
  current_user_id := auth.uid();
  if current_user_id is null then raise exception 'No hay sesion autenticada'; end if;

  if input_clue is null or length(trim(input_clue)) = 0 then raise exception 'La pista no puede estar vacia'; end if;
  if length(trim(input_clue)) > 50 then raise exception 'La pista es demasiado larga (maximo 50 caracteres)'; end if;

  select * into the_match from public.matches where id = input_match_id for update;
  if the_match.id is null then raise exception 'Match no encontrado'; end if;
  if the_match.status <> 'active' then raise exception 'La partida no esta activa'; end if;
  if the_match.current_phase <> 'clue_writing' then raise exception 'No es la fase de escritura de pistas'; end if;

  select * into my_player from public.match_players
  where match_id = input_match_id and user_id = current_user_id;
  if my_player.id is null then raise exception 'No eres jugador de este match'; end if;
  if my_player.is_eliminated then raise exception 'Estas eliminado de esta partida'; end if;
  if my_player.seat_order <> the_match.current_turn_index then raise exception 'No es tu turno'; end if;

  if exists (
    select 1 from public.match_clues
    where match_id = input_match_id
      and round_number = the_match.current_round
      and player_id = my_player.id
  ) then raise exception 'Ya escribiste tu pista en esta ronda'; end if;

  insert into public.match_clues (match_id, round_number, player_id, turn_order, clue)
  values (input_match_id, the_match.current_round, my_player.id, my_player.seat_order, trim(input_clue));

  -- Find next non-eliminated player WHO HASN'T WRITTEN YET (forward)
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

  -- Wrap around
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

  return jsonb_build_object('next_phase', phase_after, 'next_turn_index', coalesce(next_seat, 0));
end;
$$;

-- --------------------------------------------------------------------------
-- skip_clue_turn
-- --------------------------------------------------------------------------

create or replace function public.skip_clue_turn(input_match_id uuid)
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

  if not exists (
    select 1 from public.match_players
    where match_id = input_match_id and user_id = current_user_id
  ) then raise exception 'No eres jugador de este match'; end if;

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

-- --------------------------------------------------------------------------
-- submit_vote
-- --------------------------------------------------------------------------

create or replace function public.submit_vote(
  input_match_id uuid,
  input_target_player_id uuid
)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  current_user_id uuid;
  the_match public.matches%rowtype;
  my_player public.match_players%rowtype;
  target_player public.match_players%rowtype;
  active_count integer;
  voted_count integer;
  all_voted boolean;
  v_is_tiebreak boolean;
begin
  current_user_id := auth.uid();
  if current_user_id is null then raise exception 'No hay sesion autenticada'; end if;

  select * into the_match from public.matches where id = input_match_id for update;
  if the_match.id is null then raise exception 'Match no encontrado'; end if;
  if the_match.status <> 'active' then raise exception 'La partida no esta activa'; end if;
  if the_match.current_phase <> 'voting' then raise exception 'No es la fase de votacion'; end if;

  select * into my_player from public.match_players
  where match_id = input_match_id and user_id = current_user_id;
  if my_player.id is null then raise exception 'No eres jugador de este match'; end if;
  if my_player.is_eliminated then raise exception 'Estas eliminado de esta partida'; end if;

  select * into target_player from public.match_players
  where id = input_target_player_id and match_id = input_match_id;
  if target_player.id is null then raise exception 'Jugador objetivo no encontrado'; end if;
  if target_player.is_eliminated then raise exception 'No puedes votar por un jugador eliminado'; end if;
  if target_player.user_id = current_user_id then raise exception 'No puedes votar por ti mismo'; end if;

  v_is_tiebreak := (
    select count(distinct mv.voter_id) from public.match_votes mv
    where mv.match_id = input_match_id
      and mv.round_number = the_match.current_round
      and mv.is_tiebreak = false
  ) >= (
    select count(*) from public.match_players
    where match_id = input_match_id and not is_eliminated
  );

  if exists (
    select 1 from public.match_votes mv
    where mv.match_id = input_match_id
      and mv.round_number = the_match.current_round
      and mv.voter_id = my_player.id
      and mv.is_tiebreak = v_is_tiebreak
  ) then raise exception 'Ya votaste en esta ronda'; end if;

  insert into public.match_votes (match_id, round_number, voter_id, target_player_id, is_tiebreak)
  values (input_match_id, the_match.current_round, my_player.id, input_target_player_id, v_is_tiebreak);

  select count(*) into active_count from public.match_players
  where match_id = input_match_id and not is_eliminated;

  select count(*) into voted_count from public.match_votes mv
  where mv.match_id = input_match_id
    and mv.round_number = the_match.current_round
    and mv.is_tiebreak = v_is_tiebreak;

  all_voted := (voted_count >= active_count);

  if all_voted then
    update public.matches
    set current_phase = 'vote_result', state_version = state_version + 1, updated_at = timezone('utc', now())
    where id = input_match_id;
  end if;

  return jsonb_build_object('all_voted', all_voted, 'voted_count', voted_count, 'active_count', active_count);
end;
$$;

-- --------------------------------------------------------------------------
-- resolve_votes (impostor_choice phase + always gives impostor a chance)
-- --------------------------------------------------------------------------

create or replace function public.resolve_votes(input_match_id uuid)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  current_user_id uuid;
  the_match public.matches%rowtype;
  my_player public.match_players%rowtype;
  active_players integer;
  vote_count integer;
  max_votes integer;
  tied_count integer;
  tied_player_ids uuid[];
  eliminated_player public.match_players%rowtype;
  active_impostors integer;
  active_civils integer;
  game_over boolean := false;
  winner text;
  v_is_tiebreak boolean;
begin
  current_user_id := auth.uid();
  if current_user_id is null then raise exception 'No hay sesion autenticada'; end if;

  select * into the_match from public.matches where id = input_match_id for update;
  if the_match.id is null then raise exception 'Match no encontrado'; end if;
  if the_match.status not in ('active', 'finished') then raise exception 'La partida no esta activa'; end if;

  select * into my_player from public.match_players
  where match_id = input_match_id and user_id = current_user_id;
  if my_player.id is null then raise exception 'No eres jugador de este match'; end if;

  -- IDEMPOTENT PATH
  if the_match.current_phase <> 'vote_result' then
    declare
      v_vote_round integer;
      v_was_tiebreak boolean;
      v_max integer;
      v_tied uuid[];
      v_elim_player public.match_players%rowtype;
    begin
      select max(mv.round_number) into v_vote_round
      from public.match_votes mv where mv.match_id = input_match_id;
      if v_vote_round is null then raise exception 'No hay votos registrados'; end if;

      v_was_tiebreak := exists (
        select 1 from public.match_votes mv
        where mv.match_id = input_match_id and mv.round_number = v_vote_round and mv.is_tiebreak = true
      );

      select max(cnt) into v_max from (
        select count(*) as cnt from public.match_votes mv
        where mv.match_id = input_match_id and mv.round_number = v_vote_round and mv.is_tiebreak = v_was_tiebreak
        group by mv.target_player_id
      ) sub;

      select array_agg(target_player_id) into v_tied from (
        select target_player_id, count(*) as cnt from public.match_votes mv
        where mv.match_id = input_match_id and mv.round_number = v_vote_round and mv.is_tiebreak = v_was_tiebreak
        group by mv.target_player_id having count(*) = v_max
      ) sub;

      if the_match.current_phase = 'voting' and not v_was_tiebreak then
        return jsonb_build_object('result', 'tie', 'tied_player_ids', to_jsonb(v_tied), 'max_votes', v_max);
      end if;

      select * into v_elim_player from public.match_players
      where match_id = input_match_id and id = v_tied[1] and is_eliminated = true;
      if v_elim_player.id is null then
        select * into v_elim_player from public.match_players
        where match_id = input_match_id and is_eliminated = true
        order by updated_at desc limit 1;
      end if;
      if v_elim_player.id is null then raise exception 'No se encontro al jugador eliminado'; end if;

      select
        count(*) filter (where not is_eliminated and role = 'impostor'),
        count(*) filter (where not is_eliminated and role = 'civil')
      into active_impostors, active_civils
      from public.match_players where match_id = input_match_id;

      if the_match.status = 'finished' then
        if the_match.winner_override is not null then winner := the_match.winner_override;
        elsif active_impostors = 0 then winner := 'civils';
        else winner := 'impostors';
        end if;
        return jsonb_build_object(
          'result', 'game_over', 'eliminated_player_id', v_elim_player.id,
          'eliminated_role', v_elim_player.role, 'winner', winner,
          'active_impostors', active_impostors, 'active_civils', active_civils
        );
      end if;

      if the_match.current_phase in ('impostor_guess', 'impostor_choice') then
        return jsonb_build_object(
          'result', 'impostor_eliminated', 'eliminated_player_id', v_elim_player.id,
          'eliminated_role', v_elim_player.role, 'next_phase', the_match.current_phase
        );
      end if;

      return jsonb_build_object(
        'result', 'civil_eliminated', 'eliminated_player_id', v_elim_player.id,
        'eliminated_role', v_elim_player.role, 'next_phase', the_match.current_phase,
        'next_round', the_match.current_round
      );
    end;
  end if;

  -- NORMAL PATH
  select count(*) into active_players from public.match_players
  where match_id = input_match_id and not is_eliminated;

  v_is_tiebreak := exists (
    select 1 from public.match_votes mv
    where mv.match_id = input_match_id and mv.round_number = the_match.current_round and mv.is_tiebreak = true
  );

  select max(cnt) into max_votes from (
    select count(*) as cnt from public.match_votes mv
    where mv.match_id = input_match_id and mv.round_number = the_match.current_round and mv.is_tiebreak = v_is_tiebreak
    group by mv.target_player_id
  ) sub;

  select array_agg(target_player_id), count(*) into tied_player_ids, tied_count from (
    select target_player_id, count(*) as cnt from public.match_votes mv
    where mv.match_id = input_match_id and mv.round_number = the_match.current_round and mv.is_tiebreak = v_is_tiebreak
    group by mv.target_player_id having count(*) = max_votes
  ) sub;

  if tied_count > 1 then
    if v_is_tiebreak then
      select * into eliminated_player from public.match_players
      where match_id = input_match_id and id = any(tied_player_ids)
      order by display_name asc limit 1;
    else
      update public.matches
      set current_phase = 'voting', state_version = state_version + 1, updated_at = timezone('utc', now())
      where id = input_match_id;
      return jsonb_build_object('result', 'tie', 'tied_player_ids', to_jsonb(tied_player_ids), 'max_votes', max_votes);
    end if;
  else
    select * into eliminated_player from public.match_players
    where match_id = input_match_id and id = tied_player_ids[1];
  end if;

  update public.match_players set is_eliminated = true where id = eliminated_player.id;

  if eliminated_player.role = 'civil' then
    update public.match_players mp set voted_incorrectly = true
    from public.match_votes mv
    where mv.match_id = input_match_id and mv.round_number = the_match.current_round
      and mv.target_player_id = eliminated_player.id and mv.voter_id = mp.id
      and mv.is_tiebreak = v_is_tiebreak;
  end if;

  select
    count(*) filter (where not is_eliminated and role = 'impostor'),
    count(*) filter (where not is_eliminated and role = 'civil')
  into active_impostors, active_civils
  from public.match_players where match_id = input_match_id;

  -- Eliminated impostor: always goes to impostor_choice (gets a chance to guess)
  if eliminated_player.role = 'impostor' then
    if active_impostors >= active_civils and active_civils > 0 then
      game_over := true;
      winner := 'impostors';
    else
      update public.matches
      set current_phase = 'impostor_choice', state_version = state_version + 1, updated_at = timezone('utc', now())
      where id = input_match_id;
      return jsonb_build_object(
        'result', 'impostor_eliminated', 'eliminated_player_id', eliminated_player.id,
        'eliminated_role', eliminated_player.role, 'next_phase', 'impostor_choice'
      );
    end if;
  else
    if active_impostors >= active_civils then
      game_over := true;
      winner := 'impostors';
    end if;
  end if;

  if game_over then
    update public.matches
    set current_phase = 'finished', status = 'finished',
        state_version = state_version + 1, updated_at = timezone('utc', now())
    where id = input_match_id;
    update public.rooms set status = 'waiting' where id = the_match.room_id;
    return jsonb_build_object(
      'result', 'game_over', 'eliminated_player_id', eliminated_player.id,
      'eliminated_role', eliminated_player.role, 'winner', winner,
      'active_impostors', active_impostors, 'active_civils', active_civils
    );
  end if;

  -- Civil eliminated — next round
  update public.matches
  set current_phase = 'clue_writing',
      current_round = the_match.current_round + 1,
      current_turn_index = (
        select seat_order from public.match_players
        where match_id = input_match_id and not is_eliminated
        order by seat_order asc limit 1
      ),
      state_version = state_version + 1, updated_at = timezone('utc', now())
  where id = input_match_id;

  return jsonb_build_object(
    'result', 'civil_eliminated', 'eliminated_player_id', eliminated_player.id,
    'eliminated_role', eliminated_player.role, 'next_phase', 'clue_writing',
    'next_round', the_match.current_round + 1
  );
end;
$$;

-- --------------------------------------------------------------------------
-- impostor_make_choice (guess or skip)
-- --------------------------------------------------------------------------

create or replace function public.impostor_make_choice(
  input_match_id uuid,
  input_choice text
)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  current_user_id uuid;
  the_match public.matches%rowtype;
  my_player public.match_players%rowtype;
  active_impostors integer;
  active_civils integer;
begin
  current_user_id := auth.uid();
  if current_user_id is null then raise exception 'No hay sesion autenticada'; end if;
  if input_choice not in ('guess', 'skip') then raise exception 'Opcion invalida: debe ser guess o skip'; end if;

  select * into the_match from public.matches where id = input_match_id for update;
  if the_match.id is null then raise exception 'Match no encontrado'; end if;
  if the_match.status <> 'active' then raise exception 'La partida no esta activa'; end if;
  if the_match.current_phase <> 'impostor_choice' then raise exception 'No es la fase de eleccion del impostor'; end if;

  select * into my_player from public.match_players
  where match_id = input_match_id and user_id = current_user_id;
  if my_player.id is null then raise exception 'No eres jugador de este match'; end if;
  if my_player.role <> 'impostor' then raise exception 'Solo el impostor puede elegir'; end if;
  if not my_player.is_eliminated then raise exception 'Solo el impostor eliminado puede elegir'; end if;

  if input_choice = 'guess' then
    update public.matches
    set current_phase = 'impostor_guess', state_version = state_version + 1, updated_at = timezone('utc', now())
    where id = input_match_id;
    return jsonb_build_object('result', 'guess', 'next_phase', 'impostor_guess');
  end if;

  -- Skip
  select
    count(*) filter (where not is_eliminated and role = 'impostor'),
    count(*) filter (where not is_eliminated and role = 'civil')
  into active_impostors, active_civils
  from public.match_players where match_id = input_match_id;

  if active_impostors = 0 then
    update public.matches
    set current_phase = 'finished', status = 'finished',
        state_version = state_version + 1, updated_at = timezone('utc', now())
    where id = input_match_id;
    update public.rooms set status = 'waiting' where id = the_match.room_id;
    return jsonb_build_object('result', 'game_over', 'winner', 'civils');
  end if;

  update public.matches
  set current_phase = 'clue_writing',
      current_round = the_match.current_round + 1,
      current_turn_index = (
        select seat_order from public.match_players
        where match_id = input_match_id and not is_eliminated
        order by seat_order asc limit 1
      ),
      state_version = state_version + 1, updated_at = timezone('utc', now())
  where id = input_match_id;

  return jsonb_build_object('result', 'continue', 'next_phase', 'clue_writing', 'next_round', the_match.current_round + 1);
end;
$$;

-- --------------------------------------------------------------------------
-- submit_impostor_guess (normalized + winner_override + stores guess_word)
-- --------------------------------------------------------------------------

create or replace function public.submit_impostor_guess(
  input_match_id uuid,
  input_guess text
)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  current_user_id uuid;
  the_match public.matches%rowtype;
  my_player public.match_players%rowtype;
  secret_word text;
  guess_correct boolean;
  active_impostors integer;
  active_civils integer;
begin
  current_user_id := auth.uid();
  if current_user_id is null then raise exception 'No hay sesion autenticada'; end if;

  select * into the_match from public.matches where id = input_match_id for update;
  if the_match.id is null then raise exception 'Match no encontrado'; end if;
  if the_match.status <> 'active' then raise exception 'La partida no esta activa'; end if;
  if the_match.current_phase <> 'impostor_guess' then raise exception 'No es la fase de adivinanza'; end if;

  select * into my_player from public.match_players
  where match_id = input_match_id and user_id = current_user_id;
  if my_player.id is null then raise exception 'No eres jugador de este match'; end if;
  if my_player.role <> 'impostor' then raise exception 'Solo los impostores pueden adivinar'; end if;
  if not my_player.is_eliminated then raise exception 'Solo el impostor eliminado puede adivinar'; end if;

  secret_word := the_match.word;

  -- Store guess word for results screen
  update public.match_players set guess_word = trim(input_guess) where id = my_player.id;

  -- Use normalized matching (diacritics, plurals, surname matching)
  guess_correct := matches_secret_word(input_guess, secret_word);

  if guess_correct then
    -- Impostors win! Set winner_override so calculate_match_scores knows
    update public.matches
    set current_phase = 'finished', status = 'finished', winner_override = 'impostors',
        state_version = state_version + 1, updated_at = timezone('utc', now())
    where id = input_match_id;
    update public.rooms set status = 'waiting' where id = the_match.room_id;
    return jsonb_build_object('correct', true, 'result', 'game_over', 'winner', 'impostors', 'guess', input_guess, 'word', secret_word);
  end if;

  -- Incorrect guess
  update public.match_players set eliminated_by_failed_guess = true where id = my_player.id;

  select
    count(*) filter (where not is_eliminated and role = 'impostor'),
    count(*) filter (where not is_eliminated and role = 'civil')
  into active_impostors, active_civils
  from public.match_players where match_id = input_match_id;

  if active_impostors = 0 then
    update public.matches
    set current_phase = 'finished', status = 'finished',
        state_version = state_version + 1, updated_at = timezone('utc', now())
    where id = input_match_id;
    update public.rooms set status = 'waiting' where id = the_match.room_id;
    return jsonb_build_object('correct', false, 'result', 'game_over', 'winner', 'civils', 'guess', input_guess, 'word', secret_word);
  end if;

  update public.matches
  set current_phase = 'clue_writing',
      current_round = the_match.current_round + 1,
      current_turn_index = (
        select seat_order from public.match_players
        where match_id = input_match_id and not is_eliminated
        order by seat_order asc limit 1
      ),
      state_version = state_version + 1, updated_at = timezone('utc', now())
  where id = input_match_id;

  return jsonb_build_object(
    'correct', false, 'result', 'continue', 'guess', input_guess, 'word', secret_word,
    'next_phase', 'clue_writing', 'next_round', the_match.current_round + 1
  );
end;
$$;

-- --------------------------------------------------------------------------
-- Grants
-- --------------------------------------------------------------------------

grant execute on function public.confirm_role_reveal(uuid) to authenticated;
grant execute on function public.submit_clue(uuid, text) to authenticated;
grant execute on function public.skip_clue_turn(uuid) to authenticated;
grant execute on function public.submit_vote(uuid, uuid) to authenticated;
grant execute on function public.resolve_votes(uuid) to authenticated;
grant execute on function public.impostor_make_choice(uuid, text) to authenticated;
grant execute on function public.submit_impostor_guess(uuid, text) to authenticated;
