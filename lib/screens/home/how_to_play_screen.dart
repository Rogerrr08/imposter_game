import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/neon_spotlight.dart';

class HowToPlayScreen extends StatefulWidget {
  const HowToPlayScreen({super.key});

  @override
  State<HowToPlayScreen> createState() => _HowToPlayScreenState();
}

class _HowToPlayScreenState extends State<HowToPlayScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  static const _totalPages = 3;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < _totalPages - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close_rounded,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  if (_currentPage < _totalPages - 1)
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Saltar',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Pages
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildConceptPage(),
                  _buildHowToPlayPage(),
                  _buildScoringPage(),
                ],
              ),
            ),

            // Dots + Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                children: [
                  // Page indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_totalPages, (i) {
                      final isActive = i == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppTheme.primaryColor
                              : AppTheme.textSecondary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  // Next / Close button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _currentPage < _totalPages - 1
                            ? 'Siguiente'
                            : '¡A jugar!',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Página 1: Concepto ────────────────────────────────────

  Widget _buildConceptPage() {
    return _PageLayout(
      image: NeonSpotlight(
        size: 260,
        child: Image.asset(
          'assets/images/app_logo_no_bg.webp',
          height: 180,
          cacheHeight: 360,
          fit: BoxFit.contain,
        ),
      ),
      title: '¿Qué es Impostor?',
      children: [
        _bullet(
          Icons.group_rounded,
          AppTheme.primaryColor,
          'Un juego de palabras y deducción para 3-20 jugadores.',
        ),
        _bullet(
          Icons.phone_android_rounded,
          AppTheme.primaryColor,
          'Solo necesitan un celular. Se lo pasan entre todos.',
        ),
        _bullet(
          Icons.visibility_off_rounded,
          AppTheme.secondaryColor,
          'Todos reciben una palabra secreta, menos los impostores.',
        ),
        _bullet(
          Icons.chat_rounded,
          AppTheme.primaryColor,
          'Hablen, pregunten y descubran quién NO conoce la palabra.',
        ),
      ],
    );
  }

  // ─── Página 2: Cómo se juega ───────────────────────────────

  Widget _buildHowToPlayPage() {
    return _PageLayout(
      icon: Icons.sports_esports_rounded,
      iconColor: AppTheme.primaryColor,
      title: 'Cómo se juega',
      children: [
        _numberedStep(
          '1',
          'Arma los jugadores, elige categorías y cuántos impostores habrá.',
        ),
        _numberedStep('2', 'Pasa el celular: cada quien ve su rol en secreto.'),
        _numberedStep(
          '3',
          'Den pistas por turnos y discutan sobre la palabra.',
        ),
        _numberedStep(
          '4',
          'Voten al sospechoso. Si era impostor, puede arriesgar e intentar adivinar la palabra.',
        ),
        const SizedBox(height: 14),
        _sectionLabel('Modos'),
        _bullet(
          Icons.bolt_rounded,
          AppTheme.warningColor,
          'Express: rápido, con vidas y voto en cualquier momento.',
        ),
        _bullet(
          Icons.gavel_rounded,
          AppTheme.successColor,
          'Clásico: votación anónima por rondas, ideal para grupos grandes.',
        ),
        _bullet(
          Icons.wifi_rounded,
          AppTheme.primaryColor,
          'Online: cada quien desde su dispositivo, con un código de sala.',
        ),
      ],
    );
  }

  // ─── Página 3: Puntos (esencial) ───────────────────────────

  Widget _buildScoringPage() {
    return _PageLayout(
      icon: Icons.emoji_events_rounded,
      iconColor: AppTheme.warningColor,
      title: 'Puntos',
      subtitle: 'Se acumulan en el ranking del grupo',
      children: [
        _sectionLabel('Impostores'),
        _scoreRow(
          '+5',
          'Sobreviven hasta el final sin ser descubiertos',
          AppTheme.secondaryColor,
        ),
        _scoreRow('+3', 'Adivinan la palabra secreta', AppTheme.secondaryColor),
        const SizedBox(height: 12),
        _sectionLabel('Civiles'),
        _scoreRow(
          '+3',
          'Atrapan a un impostor con su voto',
          AppTheme.primaryColor,
        ),
        _scoreRow('+1', 'Su equipo gana la partida', AppTheme.primaryColor),
        _scoreRow(
          ' 0',
          'Votan mal — pierden el bonus (y una vida en Express)',
          AppTheme.textSecondary,
        ),
        const SizedBox(height: 14),
        _infoBadge(
          '\u{1F3C6} Cada modo tiene sus matices en los puntos — los irás viendo al jugar.',
        ),
      ],
    );
  }

  // ─── Widgets compartidos ───────────────────────────────────

  Widget _bullet(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _numberedStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBadge(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.15),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _scoreRow(String points, String description, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 36,
            padding: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              points,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              description,
              style: TextStyle(fontSize: 12.5, color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shell de página ───────────────────────────────────────────

class _PageLayout extends StatelessWidget {
  final Widget? image;
  final IconData? icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const _PageLayout({
    this.image,
    this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          // Imagen o ícono hero
          if (image != null)
            Center(child: image!)
          else if (icon != null)
            Center(
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: (iconColor ?? AppTheme.primaryColor).withValues(
                    alpha: 0.12,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 44,
                  color: iconColor ?? AppTheme.primaryColor,
                ),
              ),
            ),
          const SizedBox(height: 24),
          // Título
          Text(
            title,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 20),
          // Contenido
          ...children,
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
