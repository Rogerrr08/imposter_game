import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../../providers/game_provider.dart';

class ImpostorGuessScreen extends ConsumerStatefulWidget {
  const ImpostorGuessScreen({super.key});

  @override
  ConsumerState<ImpostorGuessScreen> createState() =>
      _ImpostorGuessScreenState();
}

class _ImpostorGuessScreenState extends ConsumerState<ImpostorGuessScreen>
    with SingleTickerProviderStateMixin {
  final _guessController = TextEditingController();
  bool _hasGuessed = false;
  bool _wasCorrect = false;

  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _guessController.addListener(() => setState(() {}));
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _guessController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _submitGuess() {
    final guess = _guessController.text.trim();
    if (guess.isEmpty) return;

    final correct = ref.read(gameProvider.notifier).impostorGuess(guess);

    setState(() {
      _hasGuessed = true;
      _wasCorrect = correct;
    });

    _animController.forward(from: 0);
  }

  void _continue() {
    if (_wasCorrect) {
      context.go('/results');
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: _hasGuessed ? _buildResultView() : _buildGuessForm(),
        ),
      ),
    );
  }

  Widget _buildGuessForm() {
    return Column(
      children: [
        const SizedBox(height: 24),
        // Back button
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
          ),
        ),
        const Spacer(flex: 1),
        // Header icon
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppTheme.secondaryColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.secondaryColor, width: 3),
          ),
          child: const Icon(
            Icons.psychology_alt_rounded,
            size: 50,
            color: AppTheme.secondaryColor,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'El impostor intenta adivinar',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Escribe la palabra secreta que crees que es',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.white54,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        // Text field
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.secondaryColor.withValues(alpha: 0.1),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: TextField(
            controller: _guessController,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Escribe tu respuesta...',
              hintStyle: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.white30,
              ),
              filled: true,
              fillColor: AppTheme.cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: AppTheme.secondaryColor,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 20,
              ),
            ),
            onSubmitted: (_) => _submitGuess(),
          ),
        ),
        const SizedBox(height: 24),
        // Warning
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.warningColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.warningColor.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppTheme.warningColor,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Si fallas, el juego continua y los civiles sabran que eres impostor.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.warningColor.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Spacer(flex: 1),
        // Submit button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _guessController.text.trim().isNotEmpty
                ? _submitGuess
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondaryColor,
              disabledBackgroundColor:
                  AppTheme.secondaryColor.withValues(alpha: 0.3),
              padding: const EdgeInsets.symmetric(vertical: 18),
              textStyle: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('Confirmar'),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildResultView() {
    final color =
        _wasCorrect ? AppTheme.secondaryColor : AppTheme.successColor;
    final icon = _wasCorrect
        ? Icons.celebration_rounded
        : Icons.close_rounded;
    final title = _wasCorrect
        ? 'El impostor adivino la palabra!'
        : 'Respuesta incorrecta!';
    final subtitle = _wasCorrect
        ? 'Los impostores ganan 3 puntos cada uno'
        : 'El juego continua...';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(flex: 2),
        FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Result icon
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    size: 64,
                    color: color,
                  ),
                ),
                const SizedBox(height: 32),
                // Guess shown
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '"${_guessController.text.trim()}"',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Result title
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: Colors.white54,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const Spacer(flex: 2),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _continue,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              padding: const EdgeInsets.symmetric(vertical: 18),
              textStyle: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(_wasCorrect ? 'Ver resultados' : 'Volver al juego'),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
