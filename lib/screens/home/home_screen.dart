import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/online/data/supabase_config.dart';
import '../../providers/app_info_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/full_width_button.dart';
import '../../widgets/neon_spotlight.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _assetsPrecached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_assetsPrecached) {
      _assetsPrecached = true;
      // Precarga de assets que se usan durante la partida para evitar
      // el decode síncrono en la primera aparición (role reveal, resultados).
      precacheImage(
        const AssetImage('assets/images/player_civil.webp'),
        context,
      );
      precacheImage(
        const AssetImage('assets/images/player_impostor.webp'),
        context,
      );
      precacheImage(
        const AssetImage('assets/images/tie_after_voting.webp'),
        context,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appVersionLabel = ref.watch(appVersionLabelProvider);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Scrollable para que no haya overflow en pantallas cortas o con
            // text scaling grande; los Spacers centran cuando sí hay espacio.
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: IntrinsicHeight(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 520),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 24 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Spacer(flex: 2),
                            // Logo con spotlight neón (momento de marca).
                            NeonSpotlight(
                              size: 300,
                              child: Image.asset(
                                'assets/images/app_logo_no_bg.webp',
                                width: 210,
                                height: 210,
                                cacheWidth: 420,
                                cacheHeight: 420,
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'YEISON',
                              style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 6,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              'Impostor',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'El juego de la palabra secreta',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                                letterSpacing: 1,
                              ),
                            ),
                            const Spacer(flex: 2),
                            // ── Local play ──
                            FullWidthButton(
                              label: 'Juego r\u00e1pido',
                              icon: Icons.play_arrow_rounded,
                              onPressed: () =>
                                  _navigateWithLoading(context, '/setup'),
                            ),
                            const SizedBox(height: 12),
                            FullWidthButton(
                              label: 'Mis grupos',
                              icon: Icons.group,
                              outlined: true,
                              onPressed: () =>
                                  _navigateWithLoading(context, '/groups'),
                            ),
                            const SizedBox(height: 20),
                            // ── Divider ──
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: AppTheme.textSecondary.withValues(
                                      alpha: 0.15,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  child: Text(
                                    'o',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: AppTheme.textSecondary.withValues(
                                      alpha: 0.15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // ── Online play ──
                            FullWidthButton(
                              label: 'Jugar en l\u00ednea',
                              icon: Icons.wifi_rounded,
                              outlined: true,
                              onPressed: () =>
                                  _navigateWithLoading(context, '/online'),
                            ),
                            const Spacer(flex: 1),
                            // How to play
                            TextButton.icon(
                              onPressed: () => context.push('/how-to-play'),
                              icon: const Icon(Icons.help_outline, size: 20),
                              label: Text(
                                'C\u00F3mo jugar',
                                style: TextStyle(color: AppTheme.textSecondary),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              appVersionLabel,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary.withValues(
                                  alpha: 0.5,
                                ),
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Ajustes — al final del Stack para quedar ENCIMA del scroll y
            // recibir el tap (antes el scroll lo tapaba y no respondía).
            Positioned(
              top: 12,
              right: 16,
              child: IconButton(
                onPressed: () => context.push('/settings'),
                icon: Icon(
                  Icons.settings_rounded,
                  color: AppTheme.textSecondary,
                ),
                tooltip: 'Ajustes',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateWithLoading(BuildContext context, String route) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.16),
      builder: (_) => Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      ),
    );
    // Inicialización lazy de Supabase aprovechando este loading: los usuarios
    // que solo juegan local nunca pagan este costo en cold-start.
    await Future.wait<void>([
      Future<void>.delayed(const Duration(milliseconds: 400)),
      if (route.startsWith('/online')) SupabaseConfig.ensureInitialized(),
    ]);
    if (context.mounted) {
      Navigator.of(context).pop();
      context.push(route);
    }
  }
}
