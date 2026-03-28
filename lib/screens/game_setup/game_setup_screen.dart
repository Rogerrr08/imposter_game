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
  List<GroupPlayer> _groupPlayers = [];
  final Set<int> _excludedGroupPlayerIds = <int>{};
  int? _draggingIndex;

  Set<WordCategory> _selectedCategories = {...WordCategory.values};
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
    WordCategory.animales: _CategoryInfo('Animales', '🐾'),
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
    final preset = ref.read(lastQuickGamePresetProvider);
    if (preset != null) {
      if (!_isGroupMode) {
        _manualPlayers.addAll(preset.playerNames);
      }
      _selectedCategories = {...preset.categories};
      _impostorCount = preset.impostorCount;
      _hintsEnabled = preset.hintsEnabled;
      _durationSeconds = preset.durationSeconds;
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
    final currentIds = _groupPlayers.map((p) => p.id).toSet();
    final newIds = players.map((p) => p.id).toSet();

    // Only sync if players were added/removed/renamed, not just reordered
    final added = newIds.difference(currentIds);
    final removed = currentIds.difference(newIds);
    final nameChanged = players.any((p) {
      final existing = _groupPlayers.where((g) => g.id == p.id).firstOrNull;
      return existing != null && existing.name != p.name;
    });

    if (added.isEmpty && removed.isEmpty && !nameChanged) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        // Remove deleted players
        _groupPlayers.removeWhere((p) => removed.contains(p.id));
        // Update renamed players
        for (final p in players) {
          final idx = _groupPlayers.indexWhere((g) => g.id == p.id);
          if (idx != -1) _groupPlayers[idx] = p;
        }
        // Append new players at the end
        for (final p in players) {
          if (added.contains(p.id)) _groupPlayers.add(p);
        }
        final validIds = newIds;
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

  Future<void> _startGame() async {
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
      categories: _selectedCategories.toList(),
      groupId: widget.groupId,
    );

    ref.read(gameProvider.notifier).startNewGame(config);

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 400));
    if (context.mounted) {
      Navigator.of(context).pop();
      context.push('/role-reveal');
    }
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
            onEditingComplete: _addPlayer,
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

  void _onReorderPlayers(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      if (_isGroupMode) {
        final active = _activeGroupPlayers;
        final player = active[oldIndex];
        final oldGlobalIndex = _groupPlayers.indexOf(player);
        _groupPlayers.removeAt(oldGlobalIndex);
        // Find insert position in the global list
        if (newIndex >= active.length - 1) {
          // Moving to end: insert after the last active player
          final lastActive = active.where((p) => p != player).lastOrNull;
          final insertAfter = lastActive != null
              ? _groupPlayers.indexOf(lastActive) + 1
              : _groupPlayers.length;
          _groupPlayers.insert(insertAfter, player);
        } else {
          final target = active[newIndex >= oldIndex ? newIndex + 1 : newIndex];
          final newGlobalIndex = _groupPlayers.indexOf(target);
          _groupPlayers.insert(newGlobalIndex, player);
        }
      } else {
        final player = _manualPlayers.removeAt(oldIndex);
        _manualPlayers.insert(newIndex, player);
      }
    });
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

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      proxyDecorator: (child, index, animation) {
        return _ShakeWidget(child: child);
      },
      onReorderStart: (index) => setState(() => _draggingIndex = index),
      onReorderEnd: (_) => setState(() => _draggingIndex = null),
      itemCount: players.length,
      onReorder: _onReorderPlayers,
      itemBuilder: (context, index) {
        final playerName = players[index];
        final isDragging = _draggingIndex == index;
        return Container(
          key: ValueKey(playerName),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDragging
                ? AppTheme.primaryColor.withValues(alpha: 0.15)
                : AppTheme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDragging
                  ? AppTheme.secondaryColor
                  : AppTheme.primaryColor.withValues(alpha: 0.3),
              width: isDragging ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.drag_handle_rounded,
                color: isDragging ? AppTheme.secondaryColor : Colors.white24,
                size: 20,
              ),
              const SizedBox(width: 10),
              CircleAvatar(
                radius: 14,
                backgroundColor: isDragging
                    ? AppTheme.secondaryColor.withValues(alpha: 0.4)
                    : AppTheme.primaryColor.withValues(alpha: 0.4),
                child: Text(
                  playerName[0].toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  playerName,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDragging ? AppTheme.secondaryColor : Colors.white,
                  ),
                ),
              ),
              if (!_isGroupMode)
                GestureDetector(
                  onTap: () => _removePlayer(index),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Colors.white54,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _toggleCategory(WordCategory category) {
    setState(() {
      if (_selectedCategories.contains(category)) {
        if (_selectedCategories.length > 1) {
          _selectedCategories.remove(category);
        }
      } else {
        _selectedCategories.add(category);
      }
    });
  }

  Widget _buildCategorySection() {
    final allSelected =
        _selectedCategories.length == WordCategory.values.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          icon: Icons.category_rounded,
          title: 'Categorías (aleatorio)',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: WordCategory.values.map((category) {
            final info = _categoryData[category]!;
            final isSelected = _selectedCategories.contains(category);

            return FilterChip(
              selected: isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(info.emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(info.label),
                ],
              ),
              labelStyle: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? Colors.white : Colors.white60,
              ),
              backgroundColor: AppTheme.cardColor,
              selectedColor: AppTheme.primaryColor.withValues(alpha: 0.25),
              checkmarkColor: Colors.white,
              side: BorderSide(
                color: isSelected
                    ? AppTheme.primaryColor
                    : Colors.white.withValues(alpha: 0.1),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              onSelected: (_) => _toggleCategory(category),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            setState(() {
              if (allSelected) {
                // Can't deselect all, do nothing
              } else {
                _selectedCategories = {...WordCategory.values};
              }
            });
          },
          child: Text(
            allSelected
                ? 'Todas seleccionadas'
                : 'Seleccionar todas',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: allSelected ? Colors.white38 : AppTheme.primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
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

class _ShakeWidget extends StatefulWidget {
  final Widget child;

  const _ShakeWidget({required this.child});

  @override
  State<_ShakeWidget> createState() => _ShakeWidgetState();
}

class _ShakeWidgetState extends State<_ShakeWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 80),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) => Transform.rotate(
        angle: (_controller.value - 0.5) * 0.04,
        child: child,
      ),
      child: widget.child,
    );
  }
}
