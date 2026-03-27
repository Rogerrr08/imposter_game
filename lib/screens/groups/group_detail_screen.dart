import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../../database/database.dart';
import '../../providers/database_provider.dart';
import '../../providers/group_provider.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  final int groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  final _addPlayerController = TextEditingController();
  final _addPlayerFocusNode = FocusNode();

  @override
  void dispose() {
    _addPlayerController.dispose();
    _addPlayerFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(groupDetailProvider(widget.groupId));
    final playersAsync = ref.watch(groupPlayersProvider(widget.groupId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: groupAsync.when(
          loading: () => Text(
            'Cargando...',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          error: (_, __) => Text(
            'Error',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          data: (group) => Text(
            group?.name ?? 'Grupo',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
        ),
        actions: [
          groupAsync.whenOrNull(
                data: (group) => group == null ? null : IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 22),
                  tooltip: 'Editar nombre',
                  onPressed: () => _showEditGroupNameDialog(context, group.name),
                ),
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: groupAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppTheme.secondaryColor),
                const SizedBox(height: 16),
                Text(
                  'Error al cargar el grupo',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        data: (group) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---- Players section ----
              _buildSectionHeader(
                icon: Icons.people_rounded,
                title: 'Jugadores',
              ),
              const SizedBox(height: 12),

              // Add player row
              _buildAddPlayerRow(),
              const SizedBox(height: 12),

              // Players list
              _buildPlayersList(playersAsync),

              const SizedBox(height: 32),

              // ---- Action buttons ----
              _buildSectionHeader(
                icon: Icons.sports_esports_rounded,
                title: 'Acciones',
              ),
              const SizedBox(height: 16),

              // Play with this group
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/setup', extra: widget.groupId),
                  icon: const Icon(Icons.play_arrow_rounded, size: 24),
                  label: Text(
                    'Jugar con este grupo',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Rankings and History row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/rankings/${widget.groupId}'),
                      icon: const Icon(Icons.leaderboard_rounded, size: 20),
                      label: Text(
                        'Rankings',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.warningColor,
                        side: const BorderSide(color: AppTheme.warningColor),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/history/${widget.groupId}'),
                      icon: const Icon(Icons.history_rounded, size: 20),
                      label: Text(
                        'Historial',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.successColor,
                        side: const BorderSide(color: AppTheme.successColor),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Icon(icon, size: 22, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildAddPlayerRow() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _addPlayerController,
                focusNode: _addPlayerFocusNode,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Nombre del jugador',
                  hintStyle: GoogleFonts.poppins(color: Colors.white38, fontSize: 14),
                  border: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                onSubmitted: (_) => _addPlayer(),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: _addPlayer,
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.person_add_rounded, size: 22, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addPlayer() async {
    final name = _addPlayerController.text.trim();
    if (name.isEmpty) return;

    final db = ref.read(databaseProvider);
    await GroupPlayersService(db).addPlayer(widget.groupId, name);
    ref.invalidate(groupPlayersProvider(widget.groupId));
    _addPlayerController.clear();
    _addPlayerFocusNode.requestFocus();
  }

  Widget _buildPlayersList(AsyncValue<List<GroupPlayer>> playersAsync) {
    return playersAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Error al cargar jugadores',
          style: GoogleFonts.poppins(color: AppTheme.secondaryColor),
        ),
      ),
      data: (players) {
        if (players.isEmpty) {
          return Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.person_add_alt_1_rounded,
                    size: 48,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No hay jugadores a\u00fan',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Agrega jugadores usando el campo de arriba',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white38,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          margin: EdgeInsets.zero,
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: players.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: Colors.white.withValues(alpha: 0.08),
            ),
            itemBuilder: (context, index) {
              final player = players[index];
              return _PlayerTile(
                player: player,
                groupId: widget.groupId,
                index: index + 1,
              );
            },
          ),
        );
      },
    );
  }

  void _showEditGroupNameDialog(BuildContext context, String currentName) {
    final controller = TextEditingController(text: currentName);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Editar Nombre',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Nombre del grupo',
              hintStyle: GoogleFonts.poppins(color: Colors.white38),
              prefixIcon: const Icon(Icons.group_rounded, color: AppTheme.primaryColor),
            ),
            style: GoogleFonts.poppins(color: Colors.white),
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
              style: GoogleFonts.poppins(color: Colors.white54),
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
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerTile extends ConsumerWidget {
  final GroupPlayer player;
  final int groupId;
  final int index;

  const _PlayerTile({
    required this.player,
    required this.groupId,
    required this.index,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey(player.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppTheme.secondaryColor.withValues(alpha: 0.15),
        child: const Icon(
          Icons.delete_rounded,
          color: AppTheme.secondaryColor,
          size: 22,
        ),
      ),
      confirmDismiss: (_) => _showDeletePlayerConfirmation(context),
      onDismissed: (_) async {
        final db = ref.read(databaseProvider);
        await GroupPlayersService(db).removePlayer(player.id);
        ref.invalidate(groupPlayersProvider(groupId));
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
          child: Text(
            '$index',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
        title: Text(
          player.name,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_rounded, size: 18),
              color: Colors.white38,
              tooltip: 'Editar nombre',
              onPressed: () => _showEditPlayerDialog(context, ref),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              color: AppTheme.secondaryColor.withValues(alpha: 0.7),
              tooltip: 'Eliminar jugador',
              onPressed: () async {
                final confirmed = await _showDeletePlayerConfirmation(context);
                if (confirmed == true) {
                  final db = ref.read(databaseProvider);
                  await GroupPlayersService(db).removePlayer(player.id);
                  ref.invalidate(groupPlayersProvider(groupId));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showDeletePlayerConfirmation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Eliminar jugador',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Text(
          '\u00bfEliminar a "${player.name}" del grupo?',
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.poppins(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondaryColor,
            ),
            child: Text(
              'Eliminar',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
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
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Nombre del jugador',
              hintStyle: GoogleFonts.poppins(color: Colors.white38),
              prefixIcon: const Icon(Icons.person_rounded, color: AppTheme.primaryColor),
            ),
            style: GoogleFonts.poppins(color: Colors.white),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'El nombre no puede estar vac\u00edo';
              }
              return null;
            },
            onFieldSubmitted: (_) async {
              if (formKey.currentState!.validate()) {
                final db = ref.read(databaseProvider);
                await GroupPlayersService(db).updatePlayerName(player.id, controller.text.trim());
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
              style: GoogleFonts.poppins(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final db = ref.read(databaseProvider);
                await GroupPlayersService(db).updatePlayerName(player.id, controller.text.trim());
                ref.invalidate(groupPlayersProvider(groupId));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              }
            },
            child: Text(
              'Guardar',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
