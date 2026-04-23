import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class HowToPlayScreen extends StatefulWidget {
  const HowToPlayScreen({super.key});

  @override
  State<HowToPlayScreen> createState() => _HowToPlayScreenState();
}

class _HowToPlayScreenState extends State<HowToPlayScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  static const _totalPages = 8;

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
                        style: TextStyle(fontFamily: 'Nunito',
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
                  _buildSetupPage(),
                  _buildExpressPage(),
                  _buildExpressScoringPage(),
                  _buildClassicPage(),
                  _buildClassicScoringPage(),
                  _buildOnlinePage(),
                  _buildOnlineScoringPage(),
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
                            : '\u00A1A jugar!',
                        style: const TextStyle(fontFamily: 'Nunito',
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

  // ─── Page 1: Concept ───────────────────────────────────────

  Widget _buildConceptPage() {
    return _PageLayout(
      image: Image.asset(
        'assets/images/app_logo_no_bg.webp',
        height: 200,
        cacheHeight: 400,
        fit: BoxFit.contain,
      ),
      title: '\u00BFQu\u00E9 es Impostor?',
      children: [
        _bullet(Icons.group_rounded, AppTheme.primaryColor,
            'Un juego de palabras y deducci\u00F3n para 3-20 jugadores.'),
        _bullet(Icons.phone_android_rounded, AppTheme.primaryColor,
            'Solo necesitan un celular. Se lo pasan entre todos.'),
        _bullet(Icons.visibility_off_rounded, AppTheme.secondaryColor,
            'Todos reciben una palabra secreta, menos los impostores.'),
        _bullet(Icons.chat_rounded, AppTheme.primaryColor,
            'Hablen, pregunten y descubran qui\u00E9n NO conoce la palabra.'),
      ],
    );
  }

  // ─── Page 2: Setup ─────────────────────────────────────────

  Widget _buildSetupPage() {
    return _PageLayout(
      icon: Icons.tune_rounded,
      iconColor: AppTheme.primaryColor,
      title: 'Preparar la partida',
      children: [
        _numberedStep('1', 'Agrega los jugadores o selecciona un grupo guardado.'),
        _numberedStep('2', 'Elige las categor\u00EDas de palabras que quieran jugar.'),
        _numberedStep('3', 'Ajusta la cantidad de impostores y el tiempo de discusi\u00F3n.'),
        _numberedStep('4', 'Elige el modo de juego: Express o Cl\u00E1sico.'),
        const SizedBox(height: 12),
        _infoBadge(
          '\u{1F4F1} Pasa el celular a cada jugador para que vea su rol en secreto.',
        ),
      ],
    );
  }

  // ─── Page 3: Express Mode ──────────────────────────────────

  Widget _buildExpressPage() {
    return _PageLayout(
      icon: Icons.bolt_rounded,
      iconColor: AppTheme.warningColor,
      title: 'Modo Express',
      subtitle: 'R\u00E1pido y directo',
      children: [
        _bullet(Icons.timer_rounded, AppTheme.warningColor,
            'El temporizador corre mientras discuten.'),
        _bullet(Icons.how_to_vote_rounded, AppTheme.warningColor,
            'Cualquier civil puede votar en cualquier momento.'),
        _bullet(Icons.favorite_rounded, AppTheme.secondaryColor,
            'Tienen 3 vidas. Si votan mal, pierden una vida.'),
        _bullet(Icons.psychology_rounded, AppTheme.warningColor,
            'Al eliminar un impostor, este puede intentar adivinar la palabra.'),
        const SizedBox(height: 12),
        _infoBadge(
          '\u26A1 Ideal para partidas r\u00E1pidas y din\u00E1micas con pocos jugadores.',
        ),
      ],
    );
  }

  // ─── Page 4: Classic Mode ──────────────────────────────────

  Widget _buildClassicPage() {
    return _PageLayout(
      icon: Icons.gavel_rounded,
      iconColor: AppTheme.successColor,
      title: 'Modo Cl\u00E1sico',
      subtitle: 'Votaci\u00F3n por rondas',
      children: [
        _bullet(Icons.timer_rounded, AppTheme.successColor,
            'El temporizador marca el tiempo de discusi\u00F3n.'),
        _bullet(Icons.people_rounded, AppTheme.successColor,
            'Al terminar, TODOS votan de forma an\u00F3nima, uno por uno.'),
        _bullet(Icons.bar_chart_rounded, AppTheme.successColor,
            'Se cuentan los votos y el m\u00E1s votado queda eliminado.'),
        _bullet(Icons.balance_rounded, AppTheme.warningColor,
            'Si hay empate, se vota de nuevo solo entre los empatados.'),
        _bullet(Icons.psychology_rounded, AppTheme.successColor,
            'Si eliminan a un impostor, este puede adivinar la palabra.'),
        const SizedBox(height: 12),
        _infoBadge(
          '\u{1F3AF} Ideal para grupos grandes. M\u00E1s estrat\u00E9gico y social.',
        ),
      ],
    );
  }

  // ─── Page 4: Express Scoring ────────────────────────────────

  Widget _buildExpressScoringPage() {
    return _PageLayout(
      icon: Icons.bolt_rounded,
      iconColor: AppTheme.warningColor,
      title: 'Puntos Express',
      subtitle: '\u26A1 Se reparten al final de la partida',
      children: [
        _sectionLabel('Impostores'),
        _scoreRow('+5', 'Sobrevive hasta el final sin ser descubierto',
            AppTheme.secondaryColor),
        _scoreRow('+3', 'Adivina la palabra secreta',
            AppTheme.secondaryColor),
        _scoreRow('+1', 'Eliminado por votaci\u00F3n (si ganan impostores)',
            AppTheme.secondaryColor),
        _scoreRow('\u00A00', 'Eliminado por adivinar mal',
            AppTheme.textSecondary),
        const SizedBox(height: 14),
        _sectionLabel('Civiles'),
        _scoreRow('+3', 'Vota correctamente a un impostor',
            AppTheme.primaryColor),
        _scoreRow('+1', 'Equipo ganador (sin haber votado mal)',
            AppTheme.primaryColor),
        _scoreRow('\u00A00', 'Vot\u00F3 mal \u2014 pierde una vida y no recibe bonus',
            AppTheme.textSecondary),
        const SizedBox(height: 14),
        _infoBadge(
          '\u{1F4CA} Los puntos se acumulan en el ranking del grupo.',
        ),
      ],
    );
  }

  // ─── Page 6: Classic Scoring ───────────────────────────────

  Widget _buildClassicScoringPage() {
    return _PageLayout(
      icon: Icons.gavel_rounded,
      iconColor: AppTheme.successColor,
      title: 'Puntos Cl\u00E1sico',
      subtitle: '\u{1F3DB}\uFE0F Se acumulan ronda a ronda',
      children: [
        _sectionLabel('Impostores'),
        _scoreRow('+5', 'Sobrevive hasta el final sin ser descubierto',
            AppTheme.secondaryColor),
        _scoreRow('+3', 'Adivina la palabra secreta al ser eliminado',
            AppTheme.secondaryColor),
        _scoreRow('+1', 'Eliminado por votaci\u00F3n (si ganan impostores)',
            AppTheme.secondaryColor),
        _scoreRow('\u00A00', 'Eliminado por adivinar mal',
            AppTheme.textSecondary),
        const SizedBox(height: 14),
        _sectionLabel('Civiles (por ronda)'),
        _scoreRow('+2', 'Vota correctamente a un impostor',
            AppTheme.primaryColor),
        _scoreRow(' \u20131', 'Vota a un civil inocente',
            AppTheme.errorColor),
        const SizedBox(height: 14),
        _sectionLabel('Civiles (bonus final)'),
        _scoreRow('+2', 'Equipo ganador \u2014 nunca vot\u00F3 mal',
            AppTheme.primaryColor),
        _scoreRow('\u00A00', 'Equipo ganador \u2014 pero vot\u00F3 mal alguna vez',
            AppTheme.textSecondary),
        const SizedBox(height: 14),
        _infoBadge(
          '\u{2757} En cl\u00E1sico, votar mal tiene doble costo: pierdes 1 punto en la ronda y pierdes el bonus final.',
        ),
      ],
    );
  }

  // ─── Page 7: Online Mode ────────────────────────────────────

  Widget _buildOnlinePage() {
    return _PageLayout(
      icon: Icons.wifi_rounded,
      iconColor: AppTheme.primaryColor,
      title: 'Modo Online',
      subtitle: 'Cada quien en su dispositivo',
      children: [
        _bullet(Icons.add_circle_outline_rounded, AppTheme.primaryColor,
            'El host crea una sala privada y comparte el c\u00F3digo con los dem\u00E1s.'),
        _bullet(Icons.people_rounded, AppTheme.primaryColor,
            'Cada jugador se une desde su propio celular o navegador.'),
        _bullet(Icons.check_circle_outline_rounded, AppTheme.successColor,
            'Todos marcan "Listo" y el host inicia la partida.'),
        _bullet(Icons.visibility_off_rounded, AppTheme.secondaryColor,
            'Cada uno ve su rol en secreto en su pantalla.'),
        _bullet(Icons.edit_rounded, AppTheme.primaryColor,
            'Se dan pistas por turnos, escribi\u00E9ndolas en la app.'),
        _bullet(Icons.how_to_vote_rounded, AppTheme.warningColor,
            'Todos votan de forma an\u00F3nima. El m\u00E1s votado queda eliminado.'),
        _bullet(Icons.psychology_rounded, AppTheme.secondaryColor,
            'Si eliminan a un impostor, puede arriesgar e intentar adivinar la palabra.'),
        const SizedBox(height: 12),
        _infoBadge(
          '\u{1F310} Juega con amigos a distancia. Solo necesitan conexi\u00F3n a internet.',
        ),
      ],
    );
  }

  // ─── Page 8: Online Scoring ────────────────────────────────

  Widget _buildOnlineScoringPage() {
    return _PageLayout(
      icon: Icons.wifi_rounded,
      iconColor: AppTheme.primaryColor,
      title: 'Puntos Online',
      subtitle: '\u{1F310} Se calculan al finalizar la partida',
      children: [
        _sectionLabel('Si ganan los civiles'),
        _scoreRow('+3', 'Civil que nunca vot\u00F3 mal (+1 base + 2 bonus)',
            AppTheme.primaryColor),
        _scoreRow('+1', 'Civil que vot\u00F3 mal al menos una vez',
            AppTheme.primaryColor),
        _scoreRow('\u00A00', 'Impostores (no reciben puntos)',
            AppTheme.textSecondary),
        const SizedBox(height: 14),
        _sectionLabel('Si ganan los impostores (sin adivinar)'),
        _scoreRow('+5', 'Impostor que sobrevivi\u00F3 sin ser descubierto',
            AppTheme.secondaryColor),
        const SizedBox(height: 14),
        _sectionLabel('Si un impostor adivina la palabra'),
        _scoreRow('+3', 'El impostor que adivin\u00F3 correctamente',
            AppTheme.secondaryColor),
        _scoreRow('+1', 'Los dem\u00E1s impostores',
            AppTheme.secondaryColor),
        _scoreRow('\u00A00', 'Civiles (no reciben puntos)',
            AppTheme.textSecondary),
        const SizedBox(height: 14),
        _infoBadge(
          '\u{1F3C6} Si el impostor adivina la palabra de forma verbal, cualquier jugador puede darle la victoria desde la pantalla de resultados.',
        ),
      ],
    );
  }

  // ─── Shared Widgets ────────────────────────────────────────

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
              style: TextStyle(fontFamily: 'Nunito',
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
                style: const TextStyle(fontFamily: 'Nunito',
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
              style: TextStyle(fontFamily: 'Nunito',
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
        style: TextStyle(fontFamily: 'Nunito',
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
        style: TextStyle(fontFamily: 'Nunito',
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
              style: TextStyle(fontFamily: 'Nunito',
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
              style: TextStyle(fontFamily: 'Nunito',
                fontSize: 12.5,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Page Layout Shell ─────────────────────────────────────────

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
          // Hero image or icon
          if (image != null)
            Center(child: image!)
          else if (icon != null)
            Center(
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: (iconColor ?? AppTheme.primaryColor)
                      .withValues(alpha: 0.12),
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
          // Title
          Text(
            title,
            style: TextStyle(fontFamily: 'Nunito',
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(fontFamily: 'Nunito',
                fontSize: 15,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 20),
          // Content
          ...children,
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
