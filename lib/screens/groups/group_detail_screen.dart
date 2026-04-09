import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../database/database.dart';
import '../../providers/database_provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/group_provider.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  final int groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  void _handleBackNavigation() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/groups');
  }

  Future<void> _openGroupGameSetup() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.16),
      builder: (_) => Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    Navigator.of(context).pop();
    context.push('/setup', extra: widget.groupId);
  }

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(groupDetailProvider(widget.groupId));
    final playersAsync = ref.watch(groupPlayersProvider(widget.groupId));

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _handleBackNavigation();
      },
      child: Scaffold(
        body: groupAsync.when(
          loading: () => Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor),
          ),
          error: (error, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: AppTheme.secondaryColor),
                const SizedBox(height: 16),
                Text(
                  'Error al cargar el grupo',
                  style: TextStyle(fontFamily: 'Nunito',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          data: (group) => SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Top bar ───────────────────────────
                  Row(
                    children: [
                      IconButton(
                        onPressed: _handleBackNavigation,
                        icon: Icon(
                          Icons.arrow_back_rounded,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () =>
                            _showEditGroupNameDialog(group?.name ?? ''),
                        icon: Icon(
                          Icons.edit_rounded,
                          size: 20,
                          color: AppTheme.textSecondary,
                        ),
                        tooltip: 'Editar nombre',
                      ),
                      IconButton(
                        onPressed: () =>
                            _confirmDeleteGroup(group?.name ?? ''),
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                          color: AppTheme.textSecondary,
                        ),
                        tooltip: 'Eliminar grupo',
                      ),
                    ],
                  ),

                  // ─── Group header ─────────────────────
                  const SizedBox(height: 8),
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.group_rounded,
                            size: 36,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          group?.name ?? 'Grupo',
                          style: TextStyle(fontFamily: 'Nunito',
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        playersAsync.when(
                          data: (players) => Text(
                            '${players.length} jugador${players.length == 1 ? '' : 'es'}',
                            style: TextStyle(fontFamily: 'Nunito',
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),

                  // ─── Play CTA ─────────────────────────
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openGroupGameSetup,
                      icon: const Icon(Icons.play_arrow_rounded, size: 26),
                      label: Text(
                        'Jugar con este grupo',
                        style: TextStyle(fontFamily: 'Nunito',
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),

                  // ─── Quick actions row ────────────────
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionTile(
                          icon: Icons.leaderboard_rounded,
                          label: 'Rankings',
                          color: AppTheme.warningColor,
                          onTap: () {
                            final cat = ref.read(rankingCategoryFilterProvider);
                            final mode = ref.read(rankingGameModeFilterProvider);
                            ref.invalidate(rankingsProvider((
                              groupId: widget.groupId,
                              category: cat,
                              mode: mode,
                            )));
                            context.push('/rankings/${widget.groupId}');
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionTile(
                          icon: Icons.history_rounded,
                          label: 'Historial',
                          color: AppTheme.successColor,
                          onTap: () {
                            final cat = ref.read(historyCategoryFilterProvider);
                            final mode = ref.read(historyGameModeFilterProvider);
                            ref.invalidate(gameHistoryProvider((
                              groupId: widget.groupId,
                              category: cat,
                              mode: mode,
                            )));
                            context.push('/history/${widget.groupId}');
                          },
                        ),
                      ),
                    ],
                  ),

                  // ─── Players section ──────────────────
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Icon(Icons.people_rounded,
                          size: 20, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        'Jugadores',
                        style: TextStyle(fontFamily: 'Nunito',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildPlayersChips(playersAsync),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Players as chips ──────────────────────────────────────

  Widget _buildPlayersChips(AsyncValue<List<GroupPlayer>> playersAsync) {
    return playersAsync.when(
      loading: () => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      ),
      error: (_, __) => Text(
        'Error al cargar jugadores',
        style: TextStyle(fontFamily: 'Nunito',color: AppTheme.secondaryColor),
      ),
      data: (players) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...players.map((player) => _PlayerChip(
                  player: player,
                  groupId: widget.groupId,
                )),
            // Add player chip
            ActionChip(
              avatar: Icon(Icons.add_rounded,
                  size: 18, color: AppTheme.primaryColor),
              label: Text(
                'Agregar',
                style: TextStyle(fontFamily: 'Nunito',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.08),
              side: BorderSide(
                color: AppTheme.primaryColor.withValues(alpha: 0.25),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              onPressed: () => _showAddPlayerDialog(),
            ),
          ],
        );
      },
    );
  }

  // ─── Add player dialog ─────────────────────────────────────

  void _showAddPlayerDialog() {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Agregar Jugador',
          style: TextStyle(fontFamily: 'Nunito',fontWeight: FontWeight.w700),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: false,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Nombre del jugador',
              hintStyle: TextStyle(fontFamily: 'Nunito',
                  color: AppTheme.textSecondary.withValues(alpha: 0.5)),
              prefixIcon:
                  Icon(Icons.person_rounded, color: AppTheme.primaryColor),
            ),
            style: TextStyle(fontFamily: 'Nunito',color: AppTheme.textPrimary),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'El nombre no puede estar vac\u00edo';
              }
              return null;
            },
            onFieldSubmitted: (_) async {
              if (formKey.currentState!.validate()) {
                final db = ref.read(databaseProvider);
                await GroupPlayersService(db)
                    .addPlayer(widget.groupId, controller.text.trim());
                ref.invalidate(groupPlayersProvider(widget.groupId));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancelar',
              style: TextStyle(fontFamily: 'Nunito',color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final db = ref.read(databaseProvider);
                await GroupPlayersService(db)
                    .addPlayer(widget.groupId, controller.text.trim());
                ref.invalidate(groupPlayersProvider(widget.groupId));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              }
            },
            child: Text(
              'Agregar',
              style: TextStyle(fontFamily: 'Nunito',fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Edit group name dialog ────────────────────────────────

  void _showEditGroupNameDialog(String currentName) {
    final controller = TextEditingController(text: currentName);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Editar Nombre',
          style: TextStyle(fontFamily: 'Nunito',fontWeight: FontWeight.w700),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: false,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Nombre del grupo',
              hintStyle: TextStyle(fontFamily: 'Nunito',
                  color: AppTheme.textSecondary.withValues(alpha: 0.5)),
              prefixIcon:
                  Icon(Icons.group_rounded, color: AppTheme.primaryColor),
            ),
            style: TextStyle(fontFamily: 'Nunito',color: AppTheme.textPrimary),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'El nombre no puede estar vac\u00edo';
              }
              return null;
            },
            onFieldSubmitted: (_) {
              if (formKey.currentState!.validate()) {
                ref.read(groupsProvider.notifier).updateGroupName(
                      widget.groupId,
                      controller.text.trim(),
                    );
                Navigator.pop(dialogContext);
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancelar',
              style: TextStyle(fontFamily: 'Nunito',color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                ref.read(groupsProvider.notifier).updateGroupName(
                      widget.groupId,
                      controller.text.trim(),
                    );
                Navigator.pop(dialogContext);
              }
            },
            child: Text(
              'Guardar',
              style: TextStyle(fontFamily: 'Nunito',fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Delete group confirmation ─────────────────────────────

  Future<void> _confirmDeleteGroup(String groupName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Eliminar grupo',
          style: TextStyle(fontFamily: 'Nunito',fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Se eliminar\u00E1n el grupo "$groupName", sus jugadores, su historial y su ranking. Esta acci\u00F3n no se puede deshacer.',
          style: TextStyle(fontFamily: 'Nunito',color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Cancelar',
              style: TextStyle(fontFamily: 'Nunito',color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondaryColor,
            ),
            child: Text(
              'Eliminar',
              style: TextStyle(fontFamily: 'Nunito',fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await ref.read(groupsProvider.notifier).deleteGroup(widget.groupId);
    if (!mounted) return;
    context.go('/groups');
  }
}

// ─── Action Tile Widget ──────────────────────────────────────

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(fontFamily: 'Nunito',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Player Chip Widget ──────────────────────────────────────

class _PlayerChip extends ConsumerWidget {
  final GroupPlayer player;
  final int groupId;

  const _PlayerChip({
    required this.player,
    required this.groupId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onLongPress: () => _showPlayerOptions(context, ref),
      child: Chip(
        avatar: CircleAvatar(
          radius: 13,
          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
          child: Text(
            player.name[0].toUpperCase(),
            style: TextStyle(fontFamily: 'Nunito',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
        label: Text(
          player.name,
          style: TextStyle(fontFamily: 'Nunito',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        backgroundColor: AppTheme.cardColor,
        side: BorderSide(
          color: AppTheme.textSecondary.withValues(alpha: 0.12),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  void _showPlayerOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    player.name,
                    style: TextStyle(fontFamily: 'Nunito',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.edit_rounded,
                      color: AppTheme.primaryColor),
                  title: Text(
                    'Editar nombre',
                    style: TextStyle(fontFamily: 'Nunito',
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showEditPlayerDialog(context, ref);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete_rounded,
                      color: AppTheme.secondaryColor),
                  title: Text(
                    'Eliminar del grupo',
                    style: TextStyle(fontFamily: 'Nunito',
                      fontWeight: FontWeight.w600,
                      color: AppTheme.secondaryColor,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _confirmDeletePlayer(context, ref);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditPlayerDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: player.name);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Editar Jugador',
          style: TextStyle(fontFamily: 'Nunito',fontWeight: FontWeight.w700),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: false,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Nombre del jugador',
              hintStyle: TextStyle(fontFamily: 'Nunito',
                  color: AppTheme.textSecondary.withValues(alpha: 0.5)),
              prefixIcon:
                  Icon(Icons.person_rounded, color: AppTheme.primaryColor),
            ),
            style: TextStyle(fontFamily: 'Nunito',color: AppTheme.textPrimary),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'El nombre no puede estar vac\u00edo';
              }
              return null;
            },
            onFieldSubmitted: (_) async {
              if (formKey.currentState!.validate()) {
                final db = ref.read(databaseProvider);
                await GroupPlayersService(db)
                    .updatePlayerName(player.id, controller.text.trim());
                ref.invalidate(groupPlayersProvider(groupId));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancelar',
              style: TextStyle(fontFamily: 'Nunito',color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final db = ref.read(databaseProvider);
                await GroupPlayersService(db)
                    .updatePlayerName(player.id, controller.text.trim());
                ref.invalidate(groupPlayersProvider(groupId));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              }
            },
            child: Text(
              'Guardar',
              style: TextStyle(fontFamily: 'Nunito',fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeletePlayer(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Eliminar jugador',
          style: TextStyle(fontFamily: 'Nunito',fontWeight: FontWeight.w700),
        ),
        content: Text(
          '\u00BFEliminar a "${player.name}" del grupo?',
          style: TextStyle(fontFamily: 'Nunito',color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Cancelar',
              style: TextStyle(fontFamily: 'Nunito',color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondaryColor,
            ),
            child: Text(
              'Eliminar',
              style: TextStyle(fontFamily: 'Nunito',fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final db = ref.read(databaseProvider);
    await GroupPlayersService(db).removePlayer(player.id);
    ref.invalidate(groupPlayersProvider(groupId));
  }
}
