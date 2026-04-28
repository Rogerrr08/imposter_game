import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/action_reveal.dart';
import '../../models/game_state.dart';
import '../../providers/game_provider.dart';
import '../../theme/app_theme.dart';

class ImpostorGuessScreen extends ConsumerStatefulWidget {
  const ImpostorGuessScreen({super.key});

  @override
  ConsumerState<ImpostorGuessScreen> createState() =>
      _ImpostorGuessScreenState();
}

class _ImpostorGuessScreenState extends ConsumerState<ImpostorGuessScreen> {
  final _guessController = TextEditingController();
  String? _selectedImpostor;

  @override
  void initState() {
    super.initState();
    _guessController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _guessController.dispose();
    super.dispose();
  }

  void _submitGuess() {
    final guess = _guessController.text.trim();
    final selectedImpostor = _resolveSelectedImpostor();
    if (guess.isEmpty || selectedImpostor == null) return;

    final correct = ref
        .read(gameProvider.notifier)
        .impostorGuess(guess, guessedBy: selectedImpostor);

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
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    MediaQuery.sizeOf(context).height -
                    MediaQuery.paddingOf(context).top -
                    MediaQuery.paddingOf(context).bottom,
              ),
              child: _buildGuessForm(),
            ),
          ),
        ),
      ),
    );
  }

  String? _resolveSelectedImpostor() {
    final gameState = ref.read(gameProvider);
    if (gameState?.config.mode == GameMode.classic) {
      return gameState?.pendingClassicGuesserName;
    }

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
    final isClassicMode = gameState?.config.mode == GameMode.classic;
    final activeImpostors = isClassicMode
        ? (gameState?.impostors ?? const <GamePlayer>[])
        : (gameState?.activeImpostors ?? const <GamePlayer>[]);
    final selectedImpostor = _resolveSelectedImpostor();
    final hasSingleImpostor = isClassicMode || activeImpostors.length == 1;

    return IntrinsicHeight(
      child: Column(
        children: [
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => context.pop(),
              icon: Icon(
                Icons.arrow_back_rounded,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const Spacer(flex: 1),
          Image.asset(
            'assets/images/player_impostor.webp',
            width: 130,
            height: 130,
            cacheWidth: 260,
            cacheHeight: 260,
          ),
          const SizedBox(height: 24),
          Text(
            isClassicMode
                ? 'El impostor eliminado intenta adivinar'
                : 'El impostor intenta adivinar',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Escribe la palabra secreta que crees que es',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
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
                border: Border.all(
                  color: AppTheme.textSecondary.withValues(alpha: 0.15),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isClassicMode
                        ? 'Impostor eliminado que est\u00E1 adivinando'
                        : 'Impostor que est\u00E1 adivinando',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    selectedImpostor ?? activeImpostors.first.name,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
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
                border: Border.all(
                  color: AppTheme.textSecondary.withValues(alpha: 0.15),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  hint: Text(
                    '\u00BFQu\u00E9 impostor est\u00E1 adivinando?',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  value: selectedImpostor,
                  dropdownColor: AppTheme.surfaceColor,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
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
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'Escribe tu respuesta...',
                hintStyle: TextStyle(
                  fontSize: 16,
                  color: AppTheme.textSecondary.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: AppTheme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
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
                Icon(
                  Icons.warning_amber_rounded,
                  color: AppTheme.warningColor,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isClassicMode
                        ? 'Si fallas, pierdes tu oportunidad y el juego contin\u00FAa.'
                        : 'Si fallas, el juego contin\u00FAa y los civiles sabr\u00E1n que eres impostor.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.warningColor.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(flex: 1),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  _guessController.text.trim().isNotEmpty &&
                      selectedImpostor != null
                  ? _submitGuess
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryColor,
                disabledBackgroundColor: AppTheme.secondaryColor.withValues(
                  alpha: 0.3,
                ),
                padding: const EdgeInsets.symmetric(vertical: 18),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Confirmar'),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
