import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_theme.dart';
import '../application/online_auth_provider.dart';
import '../application/online_match_provider.dart';
import '../application/online_rooms_provider.dart';
import 'widgets/active_room_dialog.dart';

class OnlineHomeScreen extends ConsumerStatefulWidget {
  const OnlineHomeScreen({super.key});

  @override
  ConsumerState<OnlineHomeScreen> createState() => _OnlineHomeScreenState();
}

class _OnlineHomeScreenState extends ConsumerState<OnlineHomeScreen> {
  bool _signingIn = false;
  bool _redirectingToDisplayName = false;
  bool _redirectingToActiveRoom = false;
  bool _activeRoomHandled = false;
  String? _authError;

  Future<void> _ensureAnonymousAuth() async {
    if (_signingIn) return;

    setState(() {
      _signingIn = true;
      _authError = null;
    });

    try {
      await ref.read(onlineProfileProvider.notifier).signInAnonymously();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _authError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _signingIn = false);
      }
    }
  }

  Future<void> _resolveActiveRoomRedirect(String roomId) async {
    final action = await showActiveRoomDialog(
      context: context,
      ref: ref,
      roomId: roomId,
    );

    if (!mounted) return;

    switch (action) {
      case ActiveRoomAction.continueRoom:
        // Check if room has active match to decide destination
        final matchId = await ref
            .read(onlineMatchRepositoryProvider)
            .getActiveMatchForRoom(roomId);
        if (!mounted) return;
        if (matchId != null) {
          context.go('/online/match/$matchId');
        } else {
          context.go('/online/room/$roomId');
        }
      case ActiveRoomAction.leaveRoom:
        await ref.read(onlineRoomsRepositoryProvider).leaveRoom(roomId);
        if (mounted) {
          ref.invalidate(myActiveRoomProvider);
          setState(() {
            _redirectingToActiveRoom = false;
            _activeRoomHandled = true;
          });
        }
      case null:
        // Dismissed — stay on home, don't show dialog again
        setState(() {
          _redirectingToActiveRoom = false;
          _activeRoomHandled = true;
        });
    }
  }

  void _goToDisplayName() {
    if (_redirectingToDisplayName) return;
    _redirectingToDisplayName = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go('/online/display-name');
    });
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(onlineAuthProvider);
    final profileAsync = ref.watch(onlineProfileProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
          'Jugar en linea',
          style: TextStyle(fontFamily: 'Nunito',fontWeight: FontWeight.w700),
        ),
      ),
      body: authAsync.when(
        loading: () => _buildLoadingState(
          title: 'Preparando tu sesión online',
          subtitle: 'Estamos restaurando tu acceso antes de entrar al lobby.',
        ),
        error: (error, _) => _buildErrorState(
          title: 'No pudimos iniciar la sesión online',
          subtitle: error.toString(),
          actionLabel: 'Reintentar',
          onPressed: _ensureAnonymousAuth,
        ),
        data: (session) {
          if (session == null) {
            if (_authError != null) {
              return _buildErrorState(
                title: 'No pudimos crear tu sesión online',
                subtitle: _authError!,
                actionLabel: 'Intentar de nuevo',
                onPressed: _ensureAnonymousAuth,
              );
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _ensureAnonymousAuth();
              }
            });

            return _buildLoadingState(
              title: 'Conectando con Supabase',
              subtitle: 'Tu perfil anónimo se está creando por primera vez.',
            );
          }

          return profileAsync.when(
            loading: () => _buildLoadingState(
              title: 'Cargando tu perfil online',
              subtitle: 'Un momento, estamos preparando tu acceso al lobby.',
            ),
            error: (error, _) => _buildErrorState(
              title: 'No pudimos cargar tu perfil',
              subtitle: error.toString(),
              actionLabel: 'Volver a intentar',
              onPressed: _ensureAnonymousAuth,
            ),
            data: (profile) {
              if (profile == null || !profile.hasDisplayName) {
                _goToDisplayName();
                return _buildLoadingState(
                  title: 'Falta tu nombre visible',
                  subtitle: 'Te llevaremos a la pantalla para terminar tu perfil.',
                );
              }

              _redirectingToDisplayName = false;

              // Check for active room to rejoin
              final activeRoomAsync = ref.watch(myActiveRoomProvider);
              return activeRoomAsync.when(
                loading: () => _buildLoadingState(
                  title: 'Verificando sesión activa',
                  subtitle: 'Estamos revisando si tienes una sala en curso.',
                ),
                error: (_, __) => _buildContent(profile),
                data: (activeRoomId) {
                  if (activeRoomId == null) {
                    _activeRoomHandled = false;
                    _redirectingToActiveRoom = false;
                    return _buildContent(profile);
                  }

                  if (!_redirectingToActiveRoom && !_activeRoomHandled) {
                    _redirectingToActiveRoom = true;
                    _resolveActiveRoomRedirect(activeRoomId);
                    return _buildLoadingState(
                      title: 'Tienes una sesión activa',
                      subtitle: 'Verificando si hay partida en curso...',
                    );
                  }

                  if (_activeRoomHandled) {
                    return _buildContent(profile);
                  }

                  return _buildLoadingState(
                    title: 'Tienes una sesión activa',
                    subtitle: 'Verificando si hay partida en curso...',
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildContent(OnlineProfile profile) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHero(profile),
            const SizedBox(height: 24),
            _buildActionCard(
              icon: Icons.add_circle_rounded,
              title: 'Crear sala privada',
              description:
                  'Genera un código para compartir con tus amigos y configura la partida desde el lobby.',
              buttonLabel: 'Crear sala',
              onPressed: () => context.go('/online/create-room'),
              filled: true,
            ),
            const SizedBox(height: 14),
            _buildActionCard(
              icon: Icons.login_rounded,
              title: 'Unirse por código',
              description:
                  'Entra a un lobby existente con el código de 6 caracteres que te comparta el host.',
              buttonLabel: 'Entrar con código',
              onPressed: () => context.go('/online/join-room'),
              filled: false,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(OnlineProfile profile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.wifi_tethering_rounded,
                  size: 16,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  profile.displayName!,
                  style: TextStyle(fontFamily: 'Nunito',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Yeison Impostor online',
            style: TextStyle(fontFamily: 'Nunito',
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Juega con tus amigos en tiempo real. '
            'Crea una sala privada o únete con un código.',
            style: TextStyle(fontFamily: 'Nunito',
              fontSize: 15,
              height: 1.45,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String description,
    required String buttonLabel,
    required VoidCallback onPressed,
    required bool filled,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppTheme.textSecondary.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: (filled ? AppTheme.primaryColor : AppTheme.secondaryColor)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: filled ? AppTheme.primaryColor : AppTheme.secondaryColor,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(fontFamily: 'Nunito',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(fontFamily: 'Nunito',
              fontSize: 14,
              height: 1.45,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: filled
                ? ElevatedButton.icon(
                    onPressed: onPressed,
                    icon: Icon(icon),
                    label: Text(buttonLabel),
                  )
                : OutlinedButton.icon(
                    onPressed: onPressed,
                    icon: Icon(icon),
                    label: Text(buttonLabel),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState({
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryColor),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Nunito',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Nunito',
                fontSize: 14,
                height: 1.45,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState({
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onPressed,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 58,
              color: AppTheme.errorColor.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Nunito',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Nunito',
                fontSize: 14,
                height: 1.45,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onPressed,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
