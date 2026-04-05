-- ============================================================================
-- Fase 5 Slice 2: Votacion simultanea + resolucion + eliminacion
-- ============================================================================
-- Ejecutar DESPUES de supabase-phase5-slice1-clues.sql
-- ============================================================================

-- --------------------------------------------------------------------------
-- Realtime para match_votes
-- --------------------------------------------------------------------------
alter publication supabase_realtime add table public.match_votes;
alter table public.match_votes replica identity full;

-- --------------------------------------------------------------------------
-- RLS: match_votes insert (players can insert their own votes)
-- --------------------------------------------------------------------------
create policy "match_players_can_insert_votes"
  on public.match_votes for insert
  with check (
    public.is_match_player(match_id)
  );

-- --------------------------------------------------------------------------
-- RPC: submit_vote
-- --------------------------------------------------------------------------
-- Called when a player submits their vote during the voting phase.
-- Validates: active match, voting phase, not eliminated, not self-vote,
-- not already voted, target is valid.
-- Does NOT resolve — resolution happens when all votes are in.
-- --------------------------------------------------------------------------

create or replace function public.submit_vote(
  input_match_id uuid,
  input_target_player_id uuid
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
  target_player public.match_players%rowtype;
  active_count integer;
  voted_count integer;
  all_voted boolean;
  v_is_tiebreak boolean;
begin
  current_user_id := auth.uid();
  if current_user_id is null then
    raise exception 'No hay sesion autenticada';
  end if;

  select * into the_match from public.matches
  where id = input_match_id for update;

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

  -- Determine if this is a tiebreak round:
  -- If all active players already have non-tiebreak votes for this round,
  -- then the next vote must be a tiebreak vote.
  v_is_tiebreak := (
    select count(distinct mv.voter_id) from public.match_votes mv
    where mv.match_id = input_match_id
      and mv.round_number = the_match.current_round
      and mv.is_tiebreak = false
  ) >= (
    select count(*) from public.match_players
    where match_id = input_match_id
      and not is_eliminated
  );

  if exists (
    select 1 from public.match_votes mv
    where mv.match_id = input_match_id
      and mv.round_number = the_match.current_round
      and mv.voter_id = my_player.id
      and mv.is_tiebreak = v_is_tiebreak
  ) then
    raise exception 'Ya votaste en esta ronda';
  end if;

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
    -- Bump version to signal clients that voting is complete
    update public.matches
    set current_phase = 'vote_result',
        state_version = state_version + 1,
        updated_at = timezone('utc', now())
    where id = input_match_id;
  end if;

  return jsonb_build_object(
    'all_voted', all_voted,
    'voted_count', voted_count,
    'active_count', active_count
  );
end;
$$;

-- --------------------------------------------------------------------------
-- RPC: resolve_votes
-- --------------------------------------------------------------------------
-- Called after all votes are in (phase = vote_result).
-- Counts votes, determines elimination or tie.
-- If tie: sets up tiebreaker (back to voting phase).
-- If clear winner: eliminates player, reveals role, checks end conditions.
-- Returns the result for the UI to display.
-- --------------------------------------------------------------------------

create or replace function public.resolve_votes(input_match_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid;
  the_match public.matches%rowtype;
  v_is_tiebreak boolean;
  vote_counts jsonb;
  max_votes integer;
  tied_player_ids uuid[];
  eliminated_player public.match_players%rowtype;
  active_impostors integer;
  active_civils integer;
  game_over boolean := false;
  winner text;
begin
  current_user_id := auth.uid();
  if current_user_id is null then
    raise exception 'No hay sesion autenticada';
  end if;

  select * into the_match
  from public.matches
  where id = input_match_id
  for update;

  if the_match.id is null then
    raise exception 'Match no encontrado';
  end if;

  if the_match.status <> 'active' then
    raise exception 'La partida no esta activa';
  end if;

  -- Verify caller is a player
  if not exists (
    select 1 from public.match_players
    where match_id = input_match_id and user_id = current_user_id
  ) then
    raise exception 'No eres jugador de este match';
  end if;

  -- -----------------------------------------------------------------------
  -- IDEMPOTENT PATH: If another client already resolved this vote round,
  -- compute and return the result in read-only mode so every client
  -- can display the vote result for their local 3-second hold.
  -- -----------------------------------------------------------------------
  if the_match.current_phase <> 'vote_result' then

    -- Figure out which round the votes belong to.
    -- After resolution the match may have advanced to the next round,
    -- so we look at the most recent round that has votes.
    declare
      v_vote_round integer;
      v_was_tiebreak boolean;
      v_max integer;
      v_tied uuid[];
      v_elim_player public.match_players%rowtype;
    begin
      -- Find the round that was just resolved
      select max(mv.round_number) into v_vote_round
      from public.match_votes mv
      where mv.match_id = input_match_id;

      if v_vote_round is null then
        raise exception 'No hay votos registrados';
      end if;

      -- Check if there were tiebreak votes in that round
      v_was_tiebreak := exists (
        select 1 from public.match_votes mv
        where mv.match_id = input_match_id
          and mv.round_number = v_vote_round
          and mv.is_tiebreak = true
      );

      -- Count votes per target (using tiebreak votes if they exist, else normal)
      select max(cnt) into v_max
      from (
        select count(*) as cnt
        from public.match_votes mv
        where mv.match_id = input_match_id
          and mv.round_number = v_vote_round
          and mv.is_tiebreak = v_was_tiebreak
        group by mv.target_player_id
      ) sub;

      select array_agg(target_player_id) into v_tied
      from (
        select target_player_id, count(*) as cnt
        from public.match_votes mv
        where mv.match_id = input_match_id
          and mv.round_number = v_vote_round
          and mv.is_tiebreak = v_was_tiebreak
        group by mv.target_player_id
        having count(*) = v_max
      ) sub;

      -- If current phase is 'voting' and there were no tiebreak votes,
      -- it means it was a tie → back to voting for tiebreak
      if the_match.current_phase = 'voting' and not v_was_tiebreak then
        return jsonb_build_object(
          'result', 'tie',
          'tied_player_ids', to_jsonb(v_tied),
          'max_votes', v_max
        );
      end if;

      -- Otherwise someone was eliminated — find them
      select * into v_elim_player
      from public.match_players
      where match_id = input_match_id
        and id = v_tied[1]
        and is_eliminated = true;

      -- If the top-voted player wasn't eliminated, try finding the most
      -- recently eliminated player in this match (fallback)
      if v_elim_player.id is null then
        select * into v_elim_player
        from public.match_players
        where match_id = input_match_id
          and is_eliminated = true
        order by updated_at desc
        limit 1;
      end if;

      if v_elim_player.id is null then
        -- Should not happen, but safe fallback
        raise exception 'No se encontro al jugador eliminado';
      end if;

      -- Check current game state
      select
        count(*) filter (where not is_eliminated and role = 'impostor'),
        count(*) filter (where not is_eliminated and role = 'civil')
      into active_impostors, active_civils
      from public.match_players
      where match_id = input_match_id;

      if the_match.status = 'finished' then
        if active_impostors = 0 then winner := 'civils';
        else winner := 'impostors';
        end if;
        return jsonb_build_object(
          'result', 'game_over',
          'eliminated_player_id', v_elim_player.id,
          'eliminated_role', v_elim_player.role,
          'winner', winner,
          'active_impostors', active_impostors,
          'active_civils', active_civils
        );
      end if;

      if the_match.current_phase = 'impostor_guess' then
        return jsonb_build_object(
          'result', 'impostor_eliminated',
          'eliminated_player_id', v_elim_player.id,
          'eliminated_role', v_elim_player.role,
          'next_phase', 'impostor_guess'
        );
      end if;

      -- Must be clue_writing or voting (next round)
      return jsonb_build_object(
        'result', 'civil_eliminated',
        'eliminated_player_id', v_elim_player.id,
        'eliminated_role', v_elim_player.role,
        'next_phase', the_match.current_phase,
        'next_round', the_match.current_round
      );
    end;
  end if;

  -- -----------------------------------------------------------------------
  -- NORMAL PATH: We are the first client to resolve. Do the actual work.
  -- -----------------------------------------------------------------------

  -- Check if this is tiebreak
  v_is_tiebreak := exists (
    select 1 from public.match_votes mv
    where mv.match_id = input_match_id
      and mv.round_number = the_match.current_round
      and mv.is_tiebreak = true
  );

  -- Count votes per target
  select max(cnt) into max_votes
  from (
    select count(*) as cnt
    from public.match_votes mv
    where mv.match_id = input_match_id
      and mv.round_number = the_match.current_round
      and mv.is_tiebreak = v_is_tiebreak
    group by mv.target_player_id
  ) sub;

  -- Find tied players (all with max votes)
  select array_agg(target_player_id) into tied_player_ids
  from (
    select target_player_id, count(*) as cnt
    from public.match_votes mv
    where mv.match_id = input_match_id
      and mv.round_number = the_match.current_round
      and mv.is_tiebreak = v_is_tiebreak
    group by mv.target_player_id
    having count(*) = max_votes
  ) sub;

  if array_length(tied_player_ids, 1) > 1 and not v_is_tiebreak then
    -- TIE on first vote — go to tiebreaker
    update public.matches
    set current_phase = 'voting',
        state_version = state_version + 1,
        updated_at = timezone('utc', now())
    where id = input_match_id;

    return jsonb_build_object(
      'result', 'tie',
      'tied_player_ids', to_jsonb(tied_player_ids),
      'max_votes', max_votes
    );
  end if;

  -- If tie on tiebreak, pick first tied player (no infinite loops)
  -- Otherwise, pick the single winner
  select * into eliminated_player
  from public.match_players
  where id = tied_player_ids[1];

  -- Eliminate the player
  update public.match_players
  set is_eliminated = true
  where id = eliminated_player.id;

  -- Mark voters who voted incorrectly (voted for a civil)
  if eliminated_player.role = 'civil' then
    update public.match_players mp
    set voted_incorrectly = true
    from public.match_votes mv
    where mv.match_id = input_match_id
      and mv.round_number = the_match.current_round
      and mv.target_player_id = eliminated_player.id
      and mv.voter_id = mp.id
      and mv.is_tiebreak = v_is_tiebreak;
  end if;

  -- Check end conditions
  select
    count(*) filter (where not is_eliminated and role = 'impostor'),
    count(*) filter (where not is_eliminated and role = 'civil')
  into active_impostors, active_civils
  from public.match_players
  where match_id = input_match_id;

  if active_impostors = 0 then
    -- Civils win: all impostors eliminated
    game_over := true;
    winner := 'civils';
  elsif active_impostors >= active_civils then
    -- Impostors win: they equal or outnumber civils
    game_over := true;
    winner := 'impostors';
  end if;

  if game_over then
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
      'result', 'game_over',
      'eliminated_player_id', eliminated_player.id,
      'eliminated_role', eliminated_player.role,
      'winner', winner,
      'active_impostors', active_impostors,
      'active_civils', active_civils
    );
  end if;

  -- Game continues: check if eliminated player was impostor → impostor_guess phase
  if eliminated_player.role = 'impostor' then
    -- Check if there are remaining impostors who can guess
    if active_impostors > 0 then
      update public.matches
      set current_phase = 'impostor_guess',
          state_version = state_version + 1,
          updated_at = timezone('utc', now())
      where id = input_match_id;

      return jsonb_build_object(
        'result', 'impostor_eliminated',
        'eliminated_player_id', eliminated_player.id,
        'eliminated_role', eliminated_player.role,
        'next_phase', 'impostor_guess'
      );
    end if;
  end if;

  -- Civil was eliminated or no impostor guess needed — next round of clues
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
    'result', 'civil_eliminated',
    'eliminated_player_id', eliminated_player.id,
    'eliminated_role', eliminated_player.role,
    'next_phase', 'clue_writing',
    'next_round', the_match.current_round + 1
  );
end;
$$;

-- --------------------------------------------------------------------------
-- Grants
-- --------------------------------------------------------------------------

grant execute on function public.submit_vote(uuid, uuid) to authenticated;
grant execute on function public.resolve_votes(uuid) to authenticated;
