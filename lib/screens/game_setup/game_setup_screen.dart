import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/word_bank.dart';
import '../../database/database.dart';
import '../../models/game_state.dart';
import '../../models/quick_game_preset.dart';
import '../../providers/game_provider.dart';
import '../../providers/group_provider.dart';
import '../../theme/app_theme.dart';
import 'widgets/category_section.dart';
import 'widgets/hints_toggle.dart';
import 'widgets/impostor_count_section.dart';
import 'widgets/player_list.dart';
import 'widgets/section_header.dart';
import 'widgets/start_button.dart';
import 'widgets/timer_section.dart';

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
  List<int>? _pendingGroupPlayerOrder;
  int? _draggingIndex;

  Set<WordCategory> _selectedCategories = {...WordCategory.values};
  int _impostorCount = 1;
  bool _hintsEnabled = true;
  int _durationSeconds = 120;

  static const int _minPlayers = 3;
  static const int _maxPlayers = 20;

  bool get _isGroupMode => widget.groupId != null;

  List<GroupPlayer> get _activeGroupPlayers => _groupPlayers
      .where((player) => !_excludedGroupPlayerIds.contains(player.id))
      .toList();

  List<String> get _currentPlayers => _isGroupMode
      ? _activeGroupPlayers.map((player) => player.name).toList()
      : List<String>.from(_manualPlayers);

  /// All group players with active/excluded status, for the unified list.
  List<({String name, bool isActive})> get _allGroupPlayersWithStatus =>
      _groupPlayers
          .map((p) => (
                name: p.name,
                isActive: !_excludedGroupPlayerIds.contains(p.id),
              ))
          .toList();

  int get _playerCount => _currentPlayers.length;

  int get _maxImpostors =>
      (_playerCount / 3).floor().clamp(1, _maxPlayers);

  @override
  void initState() {
    super.initState();
    final preset = _isGroupMode
        ? ref.read(lastGroupGamePresetsProvider)[widget.groupId!]
        : ref.read(lastQuickGamePresetProvider);
    if (preset != null) {
      if (!_isGroupMode) {
        _manualPlayers.addAll(preset.playerNames);
      } else {
        _excludedGroupPlayerIds.addAll(preset.excludedGroupPlayerIds);
        _pendingGroupPlayerOrder = preset.groupPlayerOrder.isNotEmpty
            ? preset.groupPlayerOrder
            : null;
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
    if (_playerCount == 0) {
      return;
    }
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
        _groupPlayers.removeWhere((p) => removed.contains(p.id));
        for (final p in players) {
          final idx = _groupPlayers.indexWhere((g) => g.id == p.id);
          if (idx != -1) _groupPlayers[idx] = p;
        }
        for (final p in players) {
          if (added.contains(p.id)) _groupPlayers.add(p);
        }

        // Apply saved order from preset (only once)
        if (_pendingGroupPlayerOrder != null) {
          final orderMap = <int, int>{};
          for (int i = 0; i < _pendingGroupPlayerOrder!.length; i++) {
            orderMap[_pendingGroupPlayerOrder![i]] = i;
          }
          _groupPlayers.sort((a, b) {
            final orderA = orderMap[a.id] ?? 999;
            final orderB = orderMap[b.id] ?? 999;
            return orderA.compareTo(orderB);
          });
          _pendingGroupPlayerOrder = null;
        }

        final validIds = newIds;
        _excludedGroupPlayerIds.removeWhere((id) => !validIds.contains(id));
        _clampImpostorCount();
      });
    });
  }

  void _onReorderPlayers(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      if (_isGroupMode) {
        final player = _groupPlayers.removeAt(oldIndex);
        _groupPlayers.insert(newIndex, player);
      } else {
        final player = _manualPlayers.removeAt(oldIndex);
        _manualPlayers.insert(newIndex, player);
      }
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: GoogleFonts.poppins())),
    );
  }

  void _handleBackNavigation() {
    if (context.canPop()) {
      context.pop();
      return;
    }

    if (widget.groupId != null) {
      context.go('/groups/${widget.groupId}');
      return;
    }

    context.go('/');
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

    // Save preset (including group state) before starting
    final preset = QuickGamePreset(
      playerNames: List<String>.unmodifiable(playerNames),
      impostorCount: _impostorCount,
      hintsEnabled: _hintsEnabled,
      durationSeconds: _durationSeconds,
      categories: _selectedCategories.toList(),
      excludedGroupPlayerIds: Set<int>.from(_excludedGroupPlayerIds),
      groupPlayerOrder: _groupPlayers.map((p) => p.id).toList(),
    );

    if (_isGroupMode) {
      ref
          .read(lastGroupGamePresetsProvider.notifier)
          .saveForGroup(widget.groupId!, preset);
    } else {
      ref.read(lastQuickGamePresetProvider.notifier).save(preset);
    }

    ref.read(gameProvider.notifier).startNewGame(config);

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.16),
      builder: (_) => Center(
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
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _handleBackNavigation();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Nueva Partida',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _handleBackNavigation,
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
                      CategorySection(
                        selectedCategories: _selectedCategories,
                        onToggle: (category) => setState(() {
                          if (_selectedCategories.contains(category)) {
                            if (_selectedCategories.length > 1) {
                              _selectedCategories.remove(category);
                            }
                          } else {
                            _selectedCategories.add(category);
                          }
                        }),
                        onSelectAll: () => setState(() {
                          _selectedCategories = {...WordCategory.values};
                        }),
                      ),
                      const SizedBox(height: 28),
                      ImpostorCountSection(
                        impostorCount: _impostorCount,
                        maxImpostors: _maxImpostors,
                        playerCount: _playerCount,
                        minPlayers: _minPlayers,
                        onDecrement: _impostorCount > 1
                            ? () => setState(() => _impostorCount--)
                            : null,
                        onIncrement: _impostorCount < _maxImpostors
                            ? () => setState(() => _impostorCount++)
                            : null,
                      ),
                      const SizedBox(height: 28),
                      HintsToggle(
                        hintsEnabled: _hintsEnabled,
                        onChanged: (value) =>
                            setState(() => _hintsEnabled = value),
                      ),
                      const SizedBox(height: 28),
                      TimerSection(
                        durationSeconds: _durationSeconds,
                        onDurationChanged: (value) =>
                            setState(() => _durationSeconds = value),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              StartButton(
                playerCount: _playerCount,
                minPlayers: _minPlayers,
                onStart: _startGame,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayersSection() {
    if (_isGroupMode) {
      return _buildGroupPlayersSection();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          icon: Icons.people_alt_rounded,
          title: 'Jugadores: $_playerCount/$_maxPlayers',
        ),
        const SizedBox(height: 12),
        _buildManualPlayerInput(),
        const SizedBox(height: 12),
        PlayerList(
          players: _manualPlayers
              .map((name) => PlayerListItem(name: name))
              .toList(),
          minPlayers: _minPlayers,
          isGroupMode: false,
          draggingIndex: _draggingIndex,
          onDragStart: (index) => setState(() => _draggingIndex = index),
          onDragEnd: () => setState(() => _draggingIndex = null),
          onReorder: _onReorderPlayers,
          onRemovePlayer: _removePlayer,
        ),
      ],
    );
  }

  Widget _buildGroupPlayersSection() {
    final groupPlayersAsync = ref.watch(groupPlayersProvider(widget.groupId!));

    return groupPlayersAsync.when(
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: Icons.people_alt_rounded,
            title: 'Jugadores: $_playerCount/$_maxPlayers',
          ),
          const SizedBox(height: 12),
          Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            ),
          ),
        ],
      ),
      error: (error, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: Icons.people_alt_rounded,
            title: 'Jugadores: $_playerCount/$_maxPlayers',
          ),
          const SizedBox(height: 12),
          Container(
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
        ],
      ),
      data: (players) {
        _syncGroupPlayers(players);

        if (players.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                icon: Icons.people_alt_rounded,
                title: 'Jugadores: $_playerCount/$_maxPlayers',
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.textSecondary.withValues(alpha: 0.1)),
                ),
                child: Text(
                  'Este grupo no tiene jugadores todavia.',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          );
        }

        final allItems = _allGroupPlayersWithStatus
            .map((p) => PlayerListItem(name: p.name, isActive: p.isActive))
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              icon: Icons.people_alt_rounded,
              title: 'Jugadores: $_playerCount/${_groupPlayers.length}',
            ),
            const SizedBox(height: 12),
            PlayerList(
              players: allItems,
              minPlayers: _minPlayers,
              isGroupMode: true,
              draggingIndex: _draggingIndex,
              onDragStart: (index) => setState(() => _draggingIndex = index),
              onDragEnd: () => setState(() => _draggingIndex = null),
              onReorder: _onReorderPlayers,
              onTogglePlayer: (index) {
                final player = _groupPlayers[index];
                _toggleGroupPlayer(
                    player, _excludedGroupPlayerIds.contains(player.id));
              },
            ),
          ],
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
            style: GoogleFonts.poppins(color: AppTheme.textPrimary),
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Nombre del jugador',
              hintStyle: GoogleFonts.poppins(color: AppTheme.textSecondary.withValues(alpha: 0.5)),
              prefixIcon: Icon(
                Icons.person_add_alt_1_rounded,
                color: AppTheme.textSecondary.withValues(alpha: 0.5),
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
}
