import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_theme.dart';
import '../application/online_auth_provider.dart';
import '../application/online_rooms_provider.dart';

class JoinRoomScreen extends ConsumerStatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  ConsumerState<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends ConsumerState<JoinRoomScreen> {
  final _codeController = TextEditingController();
  final _focusNode = FocusNode();
  bool _joining = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _joinRoom(String displayName) async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _error = 'Escribe el código de la sala.');
      return;
    }
    if (code.length != 6) {
      setState(() => _error = 'El código debe tener 6 caracteres.');
      return;
    }
    if (_joining) return;

    setState(() {
      _joining = true;
      _error = null;
    });

    try {
      final repository = ref.read(onlineRoomsRepositoryProvider);
      final roomId = await repository.joinPrivateRoom(
        code: code,
        displayName: displayName,
      );

      if (mounted) {
        context.go('/online/room/$roomId');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _joining = false;
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
          onPressed: _joining ? null : () => context.go('/online'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
          'Unirse por código',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
        ),
      ),
      body: profileAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
        error: (_, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No pudimos cargar tu perfil online.',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
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
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.key_rounded,
                      size: 30,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Entrar a sala privada',
                    style: GoogleFonts.nunito(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pide el código al host y escríbelo aquí para unirte al lobby.',
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      height: 1.45,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _codeController,
                    focusNode: _focusNode,
                    enabled: !_joining,
                    autofocus: false,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 6,
                      color: AppTheme.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'ABC123',
                      counterText: '',
                      errorText: _error,
                    ),
                    onChanged: (value) {
                      final formatted = value.toUpperCase().replaceAll(' ', '');
                      if (formatted != value) {
                        _codeController.value = TextEditingValue(
                          text: formatted,
                          selection: TextSelection.collapsed(
                            offset: formatted.length,
                          ),
                        );
                      }
                    },
                    onSubmitted: (_) => _joinRoom(profile.displayName!),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _joining ? null : () => _joinRoom(profile.displayName!),
                      icon: _joining
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.login_rounded),
                      label: Text(_joining ? 'Entrando...' : 'Entrar a la sala'),
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
}
