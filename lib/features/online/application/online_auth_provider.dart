import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/supabase_config.dart';

/// Current Supabase auth session. Null if not signed in.
final onlineAuthProvider = StreamProvider<Session?>((ref) {
  final client = SupabaseConfig.client;
  return client.auth.onAuthStateChange.map((event) => event.session);
});

/// Online user profile (display_name, avatar_url).
class OnlineProfile {
  final String id;
  final String? displayName;
  final String? avatarUrl;

  const OnlineProfile({
    required this.id,
    this.displayName,
    this.avatarUrl,
  });

  bool get hasDisplayName =>
      displayName != null && displayName!.trim().isNotEmpty;

  bool get hasAvatar => avatarUrl != null && avatarUrl!.isNotEmpty;
}

/// Provider that fetches and caches the current user's profile.
final onlineProfileProvider =
    AsyncNotifierProvider<OnlineProfileNotifier, OnlineProfile?>(
  OnlineProfileNotifier.new,
);

class OnlineProfileNotifier extends AsyncNotifier<OnlineProfile?> {
  SupabaseClient get _client => SupabaseConfig.client;

  @override
  Future<OnlineProfile?> build() async {
    final session = await ref.watch(onlineAuthProvider.future);
    final user = session?.user;
    if (user == null) return null;
    return _fetchProfile(user.id);
  }

  Future<OnlineProfile?> _fetchProfile(String userId) async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (data == null) {
      return OnlineProfile(id: userId);
    }

    return OnlineProfile(
      id: data['id'] as String,
      displayName: data['display_name'] as String?,
      avatarUrl: data['avatar_url'] as String?,
    );
  }

  /// Sign in anonymously and load profile.
  Future<void> signInAnonymously() async {
    final response = await _client.auth.signInAnonymously();
    final user = response.user;
    if (user == null) throw Exception('No se pudo crear sesi\u00f3n an\u00f3nima');

    state = AsyncData(await _fetchProfile(user.id));
  }

  /// Update display name in Supabase and refresh local state.
  Future<void> updateDisplayName(String name) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('No hay sesi\u00f3n activa');

    await _client
        .from('profiles')
        .upsert(
          {
            'id': user.id,
            'display_name': name.trim(),
          },
          onConflict: 'id',
        );

    state = AsyncData(OnlineProfile(
      id: user.id,
      displayName: name.trim(),
      avatarUrl: state.value?.avatarUrl,
    ));
  }

  /// Upload avatar image from an XFile (image_picker result).
  /// Resizes are not needed — the picker constrains maxWidth/maxHeight.
  Future<void> uploadAvatar(XFile imageFile) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('No hay sesi\u00f3n activa');

    final bytes = await imageFile.readAsBytes();
    final path = '${user.id}/avatar';

    // Upload (upsert) to Supabase Storage
    await _client.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );

    // Build public URL with cache-busting param
    final publicUrl = _client.storage.from('avatars').getPublicUrl(path);
    final versionedUrl =
        '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';

    // Save URL to profile
    await _updateAvatarUrl(versionedUrl);
  }

  /// Remove the avatar: delete from storage and set avatar_url to null.
  Future<void> deleteAvatar() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('No hay sesi\u00f3n activa');

    final path = '${user.id}/avatar';

    try {
      await _client.storage.from('avatars').remove([path]);
    } catch (_) {
      // File may not exist — ignore
    }

    await _updateAvatarUrl(null);
  }

  Future<void> _updateAvatarUrl(String? url) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client
        .from('profiles')
        .upsert(
          {
            'id': user.id,
            'avatar_url': url,
          },
          onConflict: 'id',
        );

    state = AsyncData(OnlineProfile(
      id: user.id,
      displayName: state.value?.displayName,
      avatarUrl: url,
    ));
  }
}
