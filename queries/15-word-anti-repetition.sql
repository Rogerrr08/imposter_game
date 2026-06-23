-- ============================================================================
-- 15 — Anti-repetición de palabras (online)
-- ============================================================================
-- Tabla + RPCs para que el cliente elija la siguiente palabra usando el
-- algoritmo Spotify-style con soft decay scoring (paridad con local):
--   - Las últimas 10 palabras quedan en hard exclusion (nunca repiten).
--   - El resto se puntúa por decay: palabras vistas hace mucho tiempo
--     tienen score cercano a 1.0, recientes cercano a 0.
--
-- Scope: por host_user_id (el que crea la sala). Las salas son efímeras
-- pero el "grupo de amigos" del host suele ser estable, así que tiene
-- sentido recordar entre salas distintas.
--
-- Window persistido: 35 entradas por (host, categoría) — 47% del pool
-- de 75. Industria recomienda 30-50% para que se sienta fresco.
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
-- get_word_freshness_for_host — historial con timestamps para soft scoring
-- ----------------------------------------------------------------------------
-- Devuelve un array JSON `[{word, picked_at}, ...]` con hasta 35 * N entradas
-- (N = cardinalidad de input_categories). El cliente lo pasa a
-- `WordBank.pickWordWithDecay` que usa los timestamps para puntuar
-- candidatos por freshness (Spotify-style).
-- ----------------------------------------------------------------------------

create or replace function public.get_word_freshness_for_host(
  input_categories text[]
)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'word', word,
    'picked_at', picked_at
  )), '[]'::jsonb)
  from (
    select word, picked_at
    from public.match_word_history
    where host_user_id = auth.uid()
      and category = any(input_categories)
    order by picked_at desc, id desc
    limit 35 * coalesce(cardinality(input_categories), 0)
  ) recent_words;
$$;

grant execute on function public.get_word_freshness_for_host(text[]) to authenticated;

-- Compat: mantener `get_recent_words_for_host` (v2.2.0 lo llama). Lo dejamos
-- como wrapper retornando solo las palabras, por si algún cliente viejo se
-- conecta antes de actualizar. Se puede borrar cuando v2.3.0 esté en todos
-- los devices.
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
    limit 35 * coalesce(cardinality(input_categories), 0)
  ) recent_words;
$$;

grant execute on function public.get_recent_words_for_host(text[]) to authenticated;

-- ----------------------------------------------------------------------------
-- record_word_pick — registra y poda
-- ----------------------------------------------------------------------------
-- Invocado desde `start_match`. Mantiene la cola en máximo 35 entradas por
-- (host, category) — paridad con `_wordHistoryWindow` del cliente.
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

  -- Mantener solo las 35 más recientes por (host, category).
  delete from public.match_word_history
  where id in (
    select id from public.match_word_history
    where host_user_id = input_host_user_id
      and category = input_category
    order by picked_at desc, id desc
    offset 35
  );
end;
$$;

-- No grants directos: solo se invoca desde otros SECURITY DEFINER funcs.
revoke execute on function public.record_word_pick(uuid, text, text) from public;
