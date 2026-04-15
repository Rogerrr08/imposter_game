import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../theme/app_theme.dart';
import '../application/online_auth_provider.dart';
import 'widgets/player_avatar.dart';

class DisplayNameScreen extends ConsumerStatefulWidget {
  const DisplayNameScreen({super.key});

  @override
  ConsumerState<DisplayNameScreen> createState() => _DisplayNameScreenState();
}

class _DisplayNameScreenState extends ConsumerState<DisplayNameScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _saving = false;
  bool _uploadingAvatar = false;
  String? _error;
  String? _currentAvatarUrl;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(onlineProfileProvider).value;
    if (profile?.displayName != null) {
      _controller.text = profile!.displayName!;
    }
    _currentAvatarUrl = profile?.avatarUrl;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _isFirstTime {
    final profile = ref.read(onlineProfileProvider).value;
    return profile == null || !profile.hasDisplayName;
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
    if (name.length > 15) {
      setState(() => _error = 'M\u00e1ximo 15 caracteres');
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

  Future<void> _pickAvatar() async {
    final source = await _showImageSourceSheet();
    if (source == null) return;

    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      maxWidth: 256,
      maxHeight: 256,
      imageQuality: 75,
    );

    if (image == null || !mounted) return;

    setState(() => _uploadingAvatar = true);

    try {
      await ref.read(onlineProfileProvider.notifier).uploadAvatar(image);
      if (mounted) {
        final profile = ref.read(onlineProfileProvider).value;
        setState(() {
          _currentAvatarUrl = profile?.avatarUrl;
          _uploadingAvatar = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir imagen: ${e.toString().replaceFirst("Exception: ", "")}'),
          ),
        );
      }
    }
  }

  Future<void> _removeAvatar() async {
    setState(() => _uploadingAvatar = true);

    try {
      await ref.read(onlineProfileProvider.notifier).deleteAvatar();
      if (mounted) {
        setState(() {
          _currentAvatarUrl = null;
          _uploadingAvatar = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar imagen'),
          ),
        );
      }
    }
  }

  Future<ImageSource?> _showImageSourceSheet() {
    final hasAvatar = _currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty;

    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Foto de perfil',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(Icons.photo_library_rounded,
                    color: AppTheme.primaryColor),
                title: Text(
                  'Elegir de galer\u00eda',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: Icon(Icons.camera_alt_rounded,
                    color: AppTheme.primaryColor),
                title: Text(
                  'Tomar foto',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              if (hasAvatar) ...[
                const Divider(),
                ListTile(
                  leading: Icon(Icons.delete_outline_rounded,
                      color: AppTheme.errorColor),
                  title: Text(
                    'Eliminar foto',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w600,
                      color: AppTheme.errorColor,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _removeAvatar();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _controller.text.trim().isEmpty
        ? '?'
        : _controller.text.trim();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) context.go('/online');
      },
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
              ),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        IconButton(
                          onPressed: _saving
                              ? null
                              : () => context.go(_isFirstTime ? '/' : '/online'),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const Spacer(),
                      ],
                    ),
                    const Spacer(flex: 2),
                    // Avatar
                    InkWell(
                      onTap: (_saving || _uploadingAvatar) ? null : _pickAvatar,
                      customBorder: const CircleBorder(),
                      child: SizedBox(
                        width: 100,
                        height: 100,
                        child: Stack(
                          children: [
                            PlayerAvatar(
                              displayName: displayName,
                              avatarUrl: _currentAvatarUrl,
                              size: 100,
                            ),
                            if (_uploadingAvatar)
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            if (!_uploadingAvatar)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppTheme.surfaceColor,
                                      width: 3,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.camera_alt_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _isFirstTime
                          ? '\u00bfC\u00f3mo te llamas?'
                          : 'Editar perfil',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isFirstTime
                          ? 'Este nombre ver\u00e1n los dem\u00e1s jugadores'
                          : 'Cambia tu nombre o foto de perfil',
                      style: TextStyle(
                        fontFamily: 'Nunito',
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
                      maxLength: 15,
                      style: TextStyle(
                        fontFamily: 'Nunito',
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
                      onChanged: (_) => setState(() {}),
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
                                _isFirstTime ? 'Continuar' : 'Guardar',
                                style: TextStyle(
                                  fontFamily: 'Nunito',
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
          ),
        ),
      ),
    );
  }
}
