-- ============================================================================
-- 06 — Helpers: normalizacion de texto y matching de palabras
-- ============================================================================
-- Ejecutar DESPUES de 05-scoring.sql
-- ============================================================================

-- --------------------------------------------------------------------------
-- normalize_for_match — replica text_normalize.dart
-- --------------------------------------------------------------------------
-- Strips diacritics, lowercases, removes special chars, singularizes tokens.
-- Ensures online guess validation matches local mode exactly.
-- --------------------------------------------------------------------------

create or replace function public.normalize_for_match(input text)
returns text
language plpgsql
immutable
as $$
declare
  normalized text;
  tokens text[];
  token text;
  result text[];
begin
  -- Lowercase and trim
  normalized := lower(trim(input));

  -- Strip diacritics via translate
  normalized := translate(
    normalized,
    'áàâäãéèêëíìîïóòôöõúùûüñ',
    'aaaaaeeeeiiiioooooouuuun'
  );

  -- Replace non-alphanumeric with space, collapse multiple spaces
  normalized := regexp_replace(normalized, '[^a-z0-9]+', ' ', 'g');
  normalized := regexp_replace(normalized, '\s+', ' ', 'g');
  normalized := trim(normalized);

  -- Singularize each token
  tokens := string_to_array(normalized, ' ');
  result := array[]::text[];

  foreach token in array tokens loop
    if token = '' then continue; end if;
    if length(token) > 4 and token like '%es' then
      token := left(token, length(token) - 2);
    elsif length(token) > 3 and token like '%s' then
      token := left(token, length(token) - 1);
    end if;
    result := array_append(result, token);
  end loop;

  return array_to_string(result, ' ');
end;
$$;

-- --------------------------------------------------------------------------
-- matches_secret_word — replica word_matching.dart
-- --------------------------------------------------------------------------

create or replace function public.matches_secret_word(
  guess text,
  secret_word text
)
returns boolean
language plpgsql
immutable
as $$
declare
  ng text;  -- normalized guess
  ns text;  -- normalized secret
  tokens text[];
  surname_allowed text[] := array[
    'Harry Potter', 'Mickey Mouse', 'Darth Vader', 'Taylor Swift',
    'Indiana Jones', 'Buzz Lightyear', 'Lionel Messi', 'LeBron James',
    'Usain Bolt', 'Michael Jordan', 'Cristiano Ronaldo', 'Serena Williams',
    'Rafael Nadal', 'Tiger Woods', 'Simone Biles', 'Kylian Mbappe',
    'Mike Tyson', 'Lewis Hamilton', 'Stephen Curry', 'Zinedine Zidane',
    'Roger Federer', 'Muhammad Ali', 'Erling Haaland'
  ];
  allowed text;
begin
  ng := normalize_for_match(guess);
  ns := normalize_for_match(secret_word);

  -- Exact match (normalized)
  if ng = ns then
    return true;
  end if;

  -- Surname match: only for allowed compound names
  foreach allowed in array surname_allowed loop
    if normalize_for_match(allowed) = ns then
      -- Secret word is in the allowed list — check surname
      tokens := string_to_array(ns, ' ');
      if array_length(tokens, 1) >= 2 then
        return ng = tokens[array_length(tokens, 1)];
      end if;
    end if;
  end loop;

  return false;
end;
$$;

-- --------------------------------------------------------------------------
-- Grants
-- --------------------------------------------------------------------------

grant execute on function public.normalize_for_match(text) to authenticated;
grant execute on function public.matches_secret_word(text, text) to authenticated;
