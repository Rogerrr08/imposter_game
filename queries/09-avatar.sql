-- ============================================================================
-- 09 — Avatar: columnas avatar_url + Storage bucket + policies
-- ============================================================================
-- Ejecutar en Supabase SQL Editor.
-- ============================================================================

-- 1. Agregar columna avatar_url y eliminar avatar_seed obsoleta
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avatar_url text;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS avatar_seed;
ALTER TABLE public.room_players ADD COLUMN IF NOT EXISTS avatar_url text;
ALTER TABLE public.match_players ADD COLUMN IF NOT EXISTS avatar_url text;

-- 2. Bucket publico para avatars
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- 3. Storage policies

-- Lectura publica
DROP POLICY IF EXISTS "public_read_avatars" ON storage.objects;
CREATE POLICY "public_read_avatars" ON storage.objects
FOR SELECT TO public
USING (bucket_id = 'avatars');

-- Usuario puede subir su propio avatar
DROP POLICY IF EXISTS "users_upload_own_avatar" ON storage.objects;
CREATE POLICY "users_upload_own_avatar" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Usuario puede actualizar su propio avatar
DROP POLICY IF EXISTS "users_update_own_avatar" ON storage.objects;
CREATE POLICY "users_update_own_avatar" ON storage.objects
FOR UPDATE TO authenticated
USING (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Usuario puede borrar su propio avatar
DROP POLICY IF EXISTS "users_delete_own_avatar" ON storage.objects;
CREATE POLICY "users_delete_own_avatar" ON storage.objects
FOR DELETE TO authenticated
USING (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] = auth.uid()::text
);
