import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_theme.dart';
import '../application/online_auth_provider.dart';
import '../application/online_rooms_provider.dart';

class CreateRoomScreen extends ConsumerStatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  bool _creating = false;
  String? _error;

  Future<void> _createRoom(String displayName) async {
    if (_creating) return;

    setState(() {
      _creating = true;
      _error = null;
    });

    try {
      final repository = ref.read(onlineRoomsRepositoryProvider);
      final roomId = await repository.createPrivateRoom(
        displayName: displayName,
      );

      if (mounted) {
        context.go('/online/room/$roomId');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _creating = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(onlineProfileProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: _creating ? null : () => context.go('/online'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
          'Crear sala privada',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
        ),
      ),
      body: profileAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
        error: (_, __) => _buildErrorState(
          title: 'No pudimos cargar tu perfil online',
          actionLabel: 'Volver',
          onPressed: () => context.go('/online'),
        ),
        data: (profile) {
          if (profile == null || !profile.hasDisplayName) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                context.go('/online/display-name');
              }
            });
            return const SizedBox.shrink();
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHero(),
                  const SizedBox(height: 24),
                  _buildSummaryCard(),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    _buildInlineError(_error!),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _creating ? null : () => _createRoom(profile.displayName!),
                      icon: _creating
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.add_rounded),
                      label: Text(_creating ? 'Creando sala...' : 'Crear sala'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHero() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.lock_rounded,
            size: 32,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Sala privada',
          style: GoogleFonts.nunito(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Se generará un código para compartir con tus amigos. '
          'En este MVP, las salas online arrancan en Modo Clásico.',
          style: GoogleFonts.nunito(
            fontSize: 15,
            height: 1.45,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Configuración inicial',
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _summaryRow('Modo', 'Clásico'),
          _summaryRow('Jugadores', '4 a 8'),
          _summaryRow('Pistas', 'Activadas'),
          _summaryRow('Duración', '2 min'),
          _summaryRow('Categorías', 'Todas'),
          const SizedBox(height: 12),
          Text(
            'Podrás ajustar categorías, tiempo, pistas e impostores dentro del lobby.',
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineError(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.errorColor.withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        message,
        style: GoogleFonts.nunito(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppTheme.errorColor,
        ),
      ),
    );
  }

  Widget _buildErrorState({
    required String title,
    required String actionLabel,
    required VoidCallback onPressed,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: AppTheme.errorColor.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
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
