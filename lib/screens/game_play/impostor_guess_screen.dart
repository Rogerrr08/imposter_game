import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/action_reveal.dart';
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
  String? _selectedImpostor;

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
    final selectedImpostor = _resolveSelectedImpostor();
    if (guess.isEmpty || selectedImpostor == null) return;

    final correct = ref.read(gameProvider.notifier).impostorGuess(
          guess,
          guessedBy: selectedImpostor,
        );

    context.go(
      '/action-reveal',
      extra: ActionRevealData(
        type: ActionRevealType.guess,
        success: correct,
        subjectText: '"$guess"',
        actorText: selectedImpostor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: _buildGuessForm(),
        ),
      ),
    );
  }

  String? _resolveSelectedImpostor() {
    final gameState = ref.read(gameProvider);
    final activeImpostors = gameState?.activeImpostors ?? const [];

    if (activeImpostors.length == 1) {
      return activeImpostors.first.name;
    }

    if (_selectedImpostor != null &&
        activeImpostors.any((player) => player.name == _selectedImpostor)) {
      return _selectedImpostor;
    }

    return null;
  }

  Widget _buildGuessForm() {
    final gameState = ref.watch(gameProvider);
    final activeImpostors = gameState?.activeImpostors ?? const [];
    final selectedImpostor = _resolveSelectedImpostor();
    final hasSingleImpostor = activeImpostors.length == 1;

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
        const SizedBox(height: 28),
        if (hasSingleImpostor)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Impostor que está adivinando',
                  style: GoogleFonts.poppins(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  selectedImpostor ?? activeImpostors.first.name,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                hint: Text(
                  'Que impostor esta adivinando?',
                  style:
                      GoogleFonts.poppins(color: Colors.white38, fontSize: 14),
                ),
                value: selectedImpostor,
                dropdownColor: AppTheme.surfaceColor,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                items: activeImpostors.map((player) {
                  return DropdownMenuItem<String>(
                    value: player.name,
                    child: Text(player.name),
                  );
                }).toList(),
                onChanged: activeImpostors.isEmpty
                    ? null
                    : (value) => setState(() => _selectedImpostor = value),
              ),
            ),
          ),
        const SizedBox(height: 20),
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
            onPressed: _guessController.text.trim().isNotEmpty &&
                    selectedImpostor != null
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
}
