-- ============================================================================
-- 15 — Anti-repetición de palabras (online)
-- ============================================================================
-- Tabla + RPC para que el cliente excluya las últimas 25 palabras jugadas por
-- el host al elegir la siguiente palabra. Scope: por host_user_id (el que
-- crea la sala). Las salas son efímeras pero el "grupo de amigos" del host
-- suele ser estable, así que tiene sentido recordar entre salas distintas.
--
-- Paridad con la lógica local (Drift `word_history`): mismo N=25.
-- ============================================================================

create table if not exists public.match_word_history (
  id bigserial primary key,
  host_user_id uuid not null references public.profiles(id) on delete cascade,
  category text not null,
  word text not null,
  picked_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_match_word_history_host_cat_picked
  on public.match_word_history(host_user_id, category, picked_at desc, id desc);

alter table public.match_word_history enable row level security;

-- Cada usuario solo puede leer su propio historial. La RPC abajo usa
-- SECURITY DEFINER así que el cliente no necesita SELECT directo, pero
-- dejamos la policy abierta para debug/analytics futuros.
drop policy if exists "users_read_own_word_history" on public.match_word_history;
create policy "users_read_own_word_history" on public.match_word_history
  for select to authenticated
  using (host_user_id = auth.uid());

-- ----------------------------------------------------------------------------
-- get_recent_words_for_host — lee la cola del usuario actual
-- ----------------------------------------------------------------------------
-- Devuelve hasta 25 * N palabras donde N = cardinalidad de input_categories.
-- El cliente las usa como `excludedWords` al invocar `WordBank.getRandomWord
-- FromCategories`.
-- ----------------------------------------------------------------------------

create or replace function public.get_recent_words_for_host(
  input_categories text[]
)
returns text[]
language sql
security definer
set search_path = public
as $$
  select coalesce(array_agg(word), array[]::text[])
  from (
    select word
    from public.match_word_history
    where host_user_id = auth.uid()
      and category = any(input_categories)
    order by picked_at desc, id desc
    limit 25 * coalesce(cardinality(input_categories), 0)
  ) recent_words;
$$;

grant execute on function public.get_recent_words_for_host(text[]) to authenticated;

-- ----------------------------------------------------------------------------
-- record_word_pick — registra y poda
-- ----------------------------------------------------------------------------
-- Invocado desde `start_match` (ver SQL modificado abajo). Mantiene la cola
-- en máximo 25 entradas por (host, category).
-- ----------------------------------------------------------------------------

create or replace function public.record_word_pick(
  input_host_user_id uuid,
  input_category text,
  input_word text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.match_word_history (host_user_id, category, word)
  values (input_host_user_id, input_category, input_word);

  -- Mantener solo las 25 más recientes por (host, category).
  delete from public.match_word_history
  where id in (
    select id from public.match_word_history
    where host_user_id = input_host_user_id
      and category = input_category
    order by picked_at desc, id desc
    offset 25
  );
end;
$$;

-- No grants directos: solo se invoca desde otros SECURITY DEFINER funcs.
revoke execute on function public.record_word_pick(uuid, text, text) from public;
