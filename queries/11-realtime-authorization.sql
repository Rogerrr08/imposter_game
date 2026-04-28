-- ============================================================================
-- 11 — Realtime Authorization: políticas sobre realtime.messages
-- ============================================================================
-- Habilita Broadcast from Database (privado) en canales `match:<uuid>` y
-- `room:<uuid>`. Solo miembros del match/room respectivo pueden recibir
-- (SELECT) y enviar (INSERT) mensajes.
--
-- Los broadcasts disparados por triggers vía `realtime.send(..., true)` con
-- SECURITY DEFINER no pasan por la policy de INSERT — pero el cliente que
-- escuche el canal SÍ debe pasar la policy de SELECT.
-- ============================================================================

-- Política de lectura: solo miembros del match/room reciben broadcasts.
drop policy if exists "authenticated_read_match_room_broadcast"
  on realtime.messages;

create policy "authenticated_read_match_room_broadcast"
on realtime.messages
for select
to authenticated
using (
  (
    realtime.topic() like 'match:%'
    and public.is_match_player(
      substring(realtime.topic() from 7)::uuid
    )
  )
  or
  (
    realtime.topic() like 'room:%'
    and public.is_room_member(
      substring(realtime.topic() from 6)::uuid
    )
  )
);

-- Política de escritura: solo miembros pueden enviar broadcasts manuales
-- (presence/broadcasts del cliente). Los triggers usan SECURITY DEFINER y
-- bypassean RLS, así que esta policy NO los bloquea.
drop policy if exists "authenticated_write_match_room_broadcast"
  on realtime.messages;

create policy "authenticated_write_match_room_broadcast"
on realtime.messages
for insert
to authenticated
with check (
  (
    realtime.topic() like 'match:%'
    and public.is_match_player(
      substring(realtime.topic() from 7)::uuid
    )
  )
  or
  (
    realtime.topic() like 'room:%'
    and public.is_room_member(
      substring(realtime.topic() from 6)::uuid
    )
  )
);
