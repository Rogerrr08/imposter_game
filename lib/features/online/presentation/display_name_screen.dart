import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_theme.dart';
import '../application/online_auth_provider.dart';

class DisplayNameScreen extends ConsumerStatefulWidget {
  const DisplayNameScreen({super.key});

  @override
  ConsumerState<DisplayNameScreen> createState() => _DisplayNameScreenState();
}

class _DisplayNameScreenState extends ConsumerState<DisplayNameScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Pre-fill if user already has a display name
    final profile = ref.read(onlineProfileProvider).value;
    if (profile?.displayName != null) {
      _controller.text = profile!.displayName!;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Escribe tu nombre');
      return;
    }
    if (name.length < 2) {
      setState(() => _error = 'M\u00ednimo 2 caracteres');
      return;
    }
    if (name.length > 20) {
      setState(() => _error = 'M\u00e1ximo 20 caracteres');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref
          .read(onlineProfileProvider.notifier)
          .updateDisplayName(name);
      if (mounted) {
        context.go('/online');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Error al guardar. Intenta de nuevo.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Row(
                children: [
                  IconButton(
                    onPressed: _saving ? null : () => context.go('/'),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const Spacer(),
                ],
              ),
              const Spacer(flex: 2),
              Icon(
                Icons.person_rounded,
                size: 72,
                color: AppTheme.primaryColor.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 20),
              Text(
                '\u00bfC\u00f3mo te llamas?',
                style: TextStyle(fontFamily: 'Nunito',
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Este nombre ver\u00e1n los dem\u00e1s jugadores',
                style: TextStyle(fontFamily: 'Nunito',
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: false,
                enabled: !_saving,
                textCapitalization: TextCapitalization.words,
                maxLength: 20,
                style: TextStyle(fontFamily: 'Nunito',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'Tu nombre...',
                  errorText: _error,
                  counterText: '',
                ),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _saving
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        )
                      : Text(
                          'Continuar',
                          style: TextStyle(fontFamily: 'Nunito',
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
