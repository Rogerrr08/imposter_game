-- ============================================================================
-- 05 — Scoring: calcular puntuacion + override victoria impostor
-- ============================================================================
-- Ejecutar DESPUES de 04-game-phases.sql
-- ============================================================================

-- --------------------------------------------------------------------------
-- calculate_match_scores (includes winner_override + guess_word)
-- --------------------------------------------------------------------------

create or replace function public.calculate_match_scores(input_match_id uuid)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  current_user_id uuid;
  the_match public.matches%rowtype;
  winner text;
  active_impostors integer;
  scores jsonb := '[]'::jsonb;
begin
  current_user_id := auth.uid();
  if current_user_id is null then raise exception 'No hay sesion autenticada'; end if;

  select * into the_match from public.matches where id = input_match_id;
  if the_match.id is null then raise exception 'Match no encontrado'; end if;
  if the_match.status <> 'finished' then raise exception 'La partida no ha terminado'; end if;

  if not exists (
    select 1 from public.match_players
    where match_id = input_match_id and user_id = current_user_id
  ) then raise exception 'No eres jugador de este match'; end if;

  -- Determine winner (check override first)
  if the_match.winner_override is not null then
    winner := the_match.winner_override;
  else
    select count(*) filter (where not is_eliminated and role = 'impostor')
    into active_impostors
    from public.match_players where match_id = input_match_id;

    if active_impostors = 0 then winner := 'civils';
    else winner := 'impostors';
    end if;
  end if;

  -- Calculate points (idempotent — only if no points yet)
  if not exists (
    select 1 from public.match_players where match_id = input_match_id and points > 0
  ) then
    if winner = 'civils' then
      update public.match_players set points = points + 2
      where match_id = input_match_id and role = 'civil' and not voted_incorrectly;
    else
      update public.match_players set points = points + 5
      where match_id = input_match_id and role = 'impostor' and not is_eliminated;

      update public.match_players set points = points + 1
      where match_id = input_match_id and role = 'impostor'
        and is_eliminated and not eliminated_by_failed_guess;
    end if;
  end if;

  -- Build scores array
  select jsonb_agg(
    jsonb_build_object(
      'player_id', mp.id, 'user_id', mp.user_id, 'display_name', mp.display_name,
      'role', mp.role, 'points', mp.points, 'is_eliminated', mp.is_eliminated,
      'voted_incorrectly', mp.voted_incorrectly,
      'eliminated_by_failed_guess', mp.eliminated_by_failed_guess,
      'guess_word', mp.guess_word
    ) order by mp.points desc, mp.seat_order asc
  ) into scores
  from public.match_players mp where mp.match_id = input_match_id;

  return jsonb_build_object(
    'winner', winner, 'word', the_match.word,
    'category', the_match.category, 'scores', coalesce(scores, '[]'::jsonb)
  );
end;
$$;

-- --------------------------------------------------------------------------
-- override_impostor_victory
-- --------------------------------------------------------------------------

create or replace function public.override_impostor_victory(
  input_match_id uuid,
  input_impostor_player_id uuid
)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  current_user_id uuid;
  the_match public.matches%rowtype;
  target_player public.match_players%rowtype;
  scores jsonb := '[]'::jsonb;
begin
  current_user_id := auth.uid();
  if current_user_id is null then raise exception 'No hay sesion autenticada'; end if;

  select * into the_match from public.matches where id = input_match_id;
  if the_match.id is null then raise exception 'Match no encontrado'; end if;
  if the_match.status <> 'finished' then raise exception 'La partida no ha terminado'; end if;

  if not exists (
    select 1 from public.match_players
    where match_id = input_match_id and user_id = current_user_id
  ) then raise exception 'No eres jugador de este match'; end if;

  select * into target_player from public.match_players
  where id = input_impostor_player_id and match_id = input_match_id;
  if target_player.id is null then raise exception 'Jugador no encontrado'; end if;
  if target_player.role <> 'impostor' then raise exception 'El jugador no es impostor'; end if;

  update public.matches set winner_override = 'impostors', updated_at = timezone('utc', now())
  where id = input_match_id;

  -- Reset and recalculate points
  update public.match_players set points = 0 where match_id = input_match_id;
  update public.match_players set points = 3 where id = input_impostor_player_id;
  update public.match_players set points = 1
  where match_id = input_match_id and role = 'impostor'
    and id <> input_impostor_player_id and not eliminated_by_failed_guess;

  select jsonb_agg(
    jsonb_build_object(
      'player_id', mp.id, 'user_id', mp.user_id, 'display_name', mp.display_name,
      'role', mp.role, 'points', mp.points, 'is_eliminated', mp.is_eliminated,
      'voted_incorrectly', mp.voted_incorrectly,
      'eliminated_by_failed_guess', mp.eliminated_by_failed_guess,
      'guess_word', mp.guess_word
    ) order by mp.points desc, mp.seat_order asc
  ) into scores
  from public.match_players mp where mp.match_id = input_match_id;

  return jsonb_build_object(
    'winner', 'impostors', 'word', the_match.word,
    'category', the_match.category, 'scores', coalesce(scores, '[]'::jsonb)
  );
end;
$$;

-- --------------------------------------------------------------------------
-- Grants
-- --------------------------------------------------------------------------

grant execute on function public.calculate_match_scores(uuid) to authenticated;
grant execute on function public.override_impostor_victory(uuid, uuid) to authenticated;
