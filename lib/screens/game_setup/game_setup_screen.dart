import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/word_bank.dart';
import '../../database/database.dart';
import '../../models/game_state.dart';
import '../../providers/game_provider.dart';
import '../../providers/group_provider.dart';
import '../../theme/app_theme.dart';

class GameSetupScreen extends ConsumerStatefulWidget {
  final int? groupId;

  const GameSetupScreen({super.key, this.groupId});

  @override
  ConsumerState<GameSetupScreen> createState() => _GameSetupScreenState();
}

class _GameSetupScreenState extends ConsumerState<GameSetupScreen> {
  final _playerController = TextEditingController();
  final _playerFocusNode = FocusNode();
  final _scrollController = ScrollController();

  final List<String> _manualPlayers = [];
  List<GroupPlayer> _groupPlayers = const [];
  final Set<int> _excludedGroupPlayerIds = <int>{};

  WordCategory _selectedCategory = WordCategory.cosas;
  int _impostorCount = 1;
  bool _hintsEnabled = true;
  int _durationSeconds = 120;

  static const int _minPlayers = 3;
  static const int _maxPlayers = 20;
  static const List<int> _presetDurations = [60, 120, 180, 300, 600];
  static const List<String> _presetLabels = [
    '1 min',
    '2 min',
    '3 min',
    '5 min',
    '10 min',
  ];

  static const Map<WordCategory, _CategoryInfo> _categoryData = {
    WordCategory.cosas: _CategoryInfo('Cosas', '📦'),
    WordCategory.entretenimiento: _CategoryInfo('Entretenimiento', '🎬'),
    WordCategory.geografia: _CategoryInfo('Geografia', '🌍'),
    WordCategory.deportes: _CategoryInfo('Deportes', '⚽'),
  };

  bool get _isGroupMode => widget.groupId != null;

  List<GroupPlayer> get _activeGroupPlayers => _groupPlayers
      .where((player) => !_excludedGroupPlayerIds.contains(player.id))
      .toList();

  List<String> get _currentPlayers => _isGroupMode
      ? _activeGroupPlayers.map((player) => player.name).toList()
      : List<String>.from(_manualPlayers);

  int get _playerCount => _currentPlayers.length;

  int get _maxImpostors =>
      (_playerCount / 3).floor().clamp(1, _maxPlayers);

  @override
  void initState() {
    super.initState();
    if (!_isGroupMode) {
      final preset = ref.read(lastQuickGamePresetProvider);
      if (preset != null) {
        _manualPlayers.addAll(preset.playerNames);
        _selectedCategory = preset.category;
        _impostorCount = preset.impostorCount;
        _hintsEnabled = preset.hintsEnabled;
        _durationSeconds = preset.durationSeconds;
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(_clampImpostorCount);
    });
  }

  @override
  void dispose() {
    _playerController.dispose();
    _playerFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _clampImpostorCount() {
    final max = _maxImpostors;
    if (_impostorCount > max) {
      _impostorCount = max;
    }
  }

  void _addPlayer() {
    final name = _playerController.text.trim();
    if (name.isEmpty) return;

    if (_playerCount >= _maxPlayers) {
      _showSnackBar('Maximo $_maxPlayers jugadores');
      return;
    }

    if (_manualPlayers.any((player) => player.toLowerCase() == name.toLowerCase())) {
      _showSnackBar('Ya existe un jugador con ese nombre');
      return;
    }

    setState(() {
      _manualPlayers.add(name);
      _playerController.clear();
      _clampImpostorCount();
    });
    _playerFocusNode.requestFocus();
  }

  void _removePlayer(int index) {
    setState(() {
      _manualPlayers.removeAt(index);
      _clampImpostorCount();
    });
  }

  void _toggleGroupPlayer(GroupPlayer player, bool shouldPlay) {
    setState(() {
      if (shouldPlay) {
        _excludedGroupPlayerIds.remove(player.id);
      } else {
        _excludedGroupPlayerIds.add(player.id);
      }
      _clampImpostorCount();
    });
  }

  void _syncGroupPlayers(List<GroupPlayer> players) {
    final hasChanged = players.length != _groupPlayers.length ||
        players.asMap().entries.any((entry) {
          final index = entry.key;
          if (index >= _groupPlayers.length) return true;

          final previous = _groupPlayers[index];
          final current = entry.value;
          return previous.id != current.id || previous.name != current.name;
        });

    if (!hasChanged) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _groupPlayers = List<GroupPlayer>.from(players);
        final validIds = players.map((player) => player.id).toSet();
        _excludedGroupPlayerIds.removeWhere((id) => !validIds.contains(id));
        _clampImpostorCount();
      });
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: GoogleFonts.poppins())),
    );
  }

  void _startGame() {
    final playerNames = _currentPlayers;
    if (playerNames.length < _minPlayers) {
      _showSnackBar('Se necesitan al menos $_minPlayers jugadores');
      return;
    }

    final config = GameConfig(
      playerNames: List<String>.unmodifiable(playerNames),
      impostorCount: _impostorCount,
      hintsEnabled: _hintsEnabled,
      durationSeconds: _durationSeconds,
      category: _selectedCategory,
      groupId: widget.groupId,
    );

    ref.read(gameProvider.notifier).startNewGame(config);
    context.push('/role-reveal');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Nueva Partida',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop()
              ? context.pop()
              : widget.groupId != null
                  ? context.go('/groups/${widget.groupId}')
                  : context.go('/'),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPlayersSection(),
                    const SizedBox(height: 28),
                    _buildCategorySection(),
                    const SizedBox(height: 28),
                    _buildImpostorCountSection(),
                    const SizedBox(height: 28),
                    _buildHintsToggle(),
                    const SizedBox(height: 28),
                    _buildTimerSection(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            _buildStartButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          icon: Icons.people_alt_rounded,
          title: 'Jugadores: $_playerCount/$_maxPlayers',
        ),
        const SizedBox(height: 12),
        if (_isGroupMode) _buildGroupPlayers() else _buildManualPlayerInput(),
        const SizedBox(height: 12),
        _buildPlayerChips(),
      ],
    );
  }

  Widget _buildGroupPlayers() {
    final groupPlayersAsync = ref.watch(groupPlayersProvider(widget.groupId!));

    return groupPlayersAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      ),
      error: (error, _) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.secondaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Error cargando jugadores del grupo',
          style: GoogleFonts.poppins(
            color: AppTheme.secondaryColor,
            fontSize: 13,
          ),
        ),
      ),
      data: (players) {
        _syncGroupPlayers(players);

        if (players.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Text(
              'Este grupo no tiene jugadores todavia.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.white54,
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.group, color: AppTheme.primaryColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Marca quien si juega esta partida',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: players.map((player) {
                  final isSelected =
                      !_excludedGroupPlayerIds.contains(player.id);
                  return FilterChip(
                    selected: isSelected,
                    label: Text(player.name),
                    labelStyle: GoogleFonts.poppins(
                      fontSize: 13,
                      color: isSelected ? Colors.white : Colors.white60,
                    ),
                    backgroundColor: AppTheme.cardColor,
                    selectedColor: AppTheme.primaryColor.withValues(alpha: 0.25),
                    checkmarkColor: Colors.white,
                    side: BorderSide(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : Colors.white.withValues(alpha: 0.12),
                    ),
                    onSelected: (value) => _toggleGroupPlayer(player, value),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              Text(
                'Juegan $_playerCount de ${players.length} integrantes',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildManualPlayerInput() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _playerController,
            focusNode: _playerFocusNode,
            style: GoogleFonts.poppins(color: Colors.white),
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Nombre del jugador',
              hintStyle: GoogleFonts.poppins(color: Colors.white30),
              prefixIcon: const Icon(
                Icons.person_add_alt_1_rounded,
                color: Colors.white30,
                size: 20,
              ),
            ),
            onSubmitted: (_) => _addPlayer(),
          ),
        ),
        const SizedBox(width: 12),
        Material(
          color: AppTheme.primaryColor,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: _addPlayer,
            borderRadius: BorderRadius.circular(12),
            child: const SizedBox(
              width: 50,
              height: 50,
              child: Icon(Icons.add_rounded, color: Colors.white, size: 28),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerChips() {
    final players = _currentPlayers;

    if (players.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          children: [
            Icon(
              Icons.person_outline_rounded,
              size: 36,
              color: Colors.white.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 8),
            Text(
              'Agrega al menos $_minPlayers jugadores',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.white30,
              ),
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List<Widget>.generate(players.length, (index) {
        final playerName = players[index];
        return Chip(
          label: Text(
            playerName,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          avatar: CircleAvatar(
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.4),
            child: Text(
              playerName[0].toUpperCase(),
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          deleteIcon: const Icon(Icons.close_rounded, size: 16),
          deleteIconColor: Colors.white54,
          onDeleted: _isGroupMode ? null : () => _removePlayer(index),
          backgroundColor: AppTheme.cardColor,
          side: BorderSide(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        );
      }),
    );
  }

  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          icon: Icons.category_rounded,
          title: 'Categoria',
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.7,
          children: WordCategory.values.map((category) {
            final info = _categoryData[category]!;
            final isSelected = _selectedCategory == category;

            return GestureDetector(
              onTap: () => setState(() => _selectedCategory = category),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor.withValues(alpha: 0.2)
                      : AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : Colors.white.withValues(alpha: 0.06),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(info.emoji, style: const TextStyle(fontSize: 28)),
                    const SizedBox(height: 6),
                    Text(
                      info.label,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildImpostorCountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          icon: Icons.psychology_alt_rounded,
          title: 'Impostores: $_impostorCount',
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              _roundIconButton(
                icon: Icons.remove_rounded,
                onTap: _impostorCount > 1
                    ? () => setState(() => _impostorCount--)
                    : null,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '$_impostorCount',
                      style: GoogleFonts.poppins(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.secondaryColor,
                      ),
                    ),
                    Text(
                      _impostorCount == 1 ? 'impostor' : 'impostores',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
              _roundIconButton(
                icon: Icons.add_rounded,
                onTap: _impostorCount < _maxImpostors
                    ? () => setState(() => _impostorCount++)
                    : null,
              ),
            ],
          ),
        ),
        if (_playerCount >= _minPlayers)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Maximo $_maxImpostors impostor${_maxImpostors == 1 ? '' : 'es'} para $_playerCount jugadores',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.white24,
              ),
            ),
          ),
      ],
    );
  }

  Widget _roundIconButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return Material(
      color: enabled
          ? AppTheme.primaryColor.withValues(alpha: 0.2)
          : Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            icon,
            color: enabled ? AppTheme.primaryColor : Colors.white12,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildHintsToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          'Pistas para impostores',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        subtitle: Text(
          _hintsEnabled
              ? 'Los impostores reciben una pista mas sutil'
              : 'Sin pistas, mayor dificultad',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.white30,
          ),
        ),
        secondary: Icon(
          _hintsEnabled ? Icons.lightbulb_rounded : Icons.lightbulb_outline,
          color: _hintsEnabled ? AppTheme.warningColor : Colors.white24,
          size: 26,
        ),
        value: _hintsEnabled,
        activeColor: AppTheme.primaryColor,
        onChanged: (value) => setState(() => _hintsEnabled = value),
      ),
    );
  }

  Widget _buildTimerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          icon: Icons.timer_rounded,
          title: 'Duracion: ${_formatDuration(_durationSeconds)}',
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _presetDurations.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final duration = _presetDurations[index];
              final isSelected = _durationSeconds == duration;

              return GestureDetector(
                onTap: () => setState(() => _durationSeconds = duration),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : Colors.white.withValues(alpha: 0.06),
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppTheme.primaryColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      _presetLabels[index],
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : Colors.white54,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppTheme.primaryColor,
            inactiveTrackColor: AppTheme.surfaceColor,
            thumbColor: AppTheme.primaryColor,
            overlayColor: AppTheme.primaryColor.withValues(alpha: 0.15),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: _durationSeconds.toDouble(),
            min: 60,
            max: 600,
            divisions: 54,
            onChanged: (value) => setState(() => _durationSeconds = value.round()),
          ),
        ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (remainingSeconds == 0) {
      return '$minutes min';
    }
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')} min';
  }

  Widget _buildStartButton() {
    final canStart = _playerCount >= _minPlayers;
    final missingPlayers = (_minPlayers - _playerCount).clamp(0, _minPlayers);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: canStart ? _startGame : null,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              canStart ? AppTheme.primaryColor : AppTheme.surfaceColor,
          foregroundColor: canStart ? Colors.white : Colors.white24,
          disabledBackgroundColor: AppTheme.surfaceColor,
          disabledForegroundColor: Colors.white24,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: canStart ? 6 : 0,
          shadowColor: AppTheme.primaryColor.withValues(alpha: 0.4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              canStart ? Icons.play_arrow_rounded : Icons.lock_rounded,
              size: 26,
            ),
            const SizedBox(width: 10),
            Text(
              canStart
                  ? 'Comenzar Partida'
                  : 'Faltan $missingPlayers jugador${missingPlayers == 1 ? '' : 'es'}',
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _CategoryInfo {
  final String label;
  final String emoji;

  const _CategoryInfo(this.label, this.emoji);
}
