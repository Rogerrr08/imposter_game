import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../providers/group_provider.dart';

class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  void _handleBackNavigation(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _handleBackNavigation(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Mis Grupos',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => _handleBackNavigation(context),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showCreateGroupDialog(context, ref),
          backgroundColor: AppTheme.primaryColor,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: Text(
            'Nuevo Grupo',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        body: groupsAsync.when(
          loading: () => Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor),
          ),
          error: (error, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: AppTheme.secondaryColor),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar los grupos',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          data: (groups) {
            if (groups.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.group_add_rounded,
                        size: 80,
                        color: AppTheme.primaryColor.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'No hay grupos aún',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Crea un grupo para guardar jugadores\ny llevar un historial de partidas.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: () => _showCreateGroupDialog(context, ref),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Crear Grupo'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                return _GroupCard(group: group);
              },
            );
          },
        ),
      ),
    );
  }

  void _showCreateGroupDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Nuevo Grupo',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: false,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Nombre del grupo',
              hintStyle: GoogleFonts.poppins(color: AppTheme.textSecondary.withValues(alpha: 0.5)),
              prefixIcon: Icon(Icons.group_rounded, color: AppTheme.primaryColor),
            ),
            style: GoogleFonts.poppins(color: AppTheme.textPrimary),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Ingresa un nombre para el grupo';
              }
              return null;
            },
            onFieldSubmitted: (_) {
              _createGroupAndOpen(
                context: context,
                dialogContext: dialogContext,
                ref: ref,
                formKey: formKey,
                controller: controller,
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancelar',
              style: GoogleFonts.poppins(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => _createGroupAndOpen(
              context: context,
              dialogContext: dialogContext,
              ref: ref,
              formKey: formKey,
              controller: controller,
            ),
            child: Text(
              'Crear',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createGroupAndOpen({
    required BuildContext context,
    required BuildContext dialogContext,
    required WidgetRef ref,
    required GlobalKey<FormState> formKey,
    required TextEditingController controller,
  }) async {
    if (!formKey.currentState!.validate()) return;

    final groupId = await ref
        .read(groupsProvider.notifier)
        .createGroup(controller.text.trim());

    if (dialogContext.mounted) {
      Navigator.pop(dialogContext);
    }

    if (context.mounted) {
      _navigateWithLoading(context, '/groups/$groupId');
    }
  }

  Future<void> _navigateWithLoading(BuildContext context, String route) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: AppTheme.textSecondary,
      builder: (_) => Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 400));
    if (context.mounted) {
      Navigator.of(context).pop();
      context.push(route);
    }
  }
}

class _GroupCard extends ConsumerWidget {
  final dynamic group;

  const _GroupCard({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playersAsync = ref.watch(groupPlayersProvider(group.id));
    final dateFormat = DateFormat('dd MMM yyyy', 'es');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: ValueKey(group.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: AppTheme.secondaryColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.delete_rounded,
            color: AppTheme.secondaryColor,
            size: 28,
          ),
        ),
        confirmDismiss: (_) => _showDeleteConfirmation(context),
        onDismissed: (_) {
          ref.read(groupsProvider.notifier).deleteGroup(group.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Grupo "${group.name}" eliminado',
                style: GoogleFonts.poppins(),
              ),
              action: SnackBarAction(
                label: 'OK',
                textColor: AppTheme.primaryColor,
                onPressed: () {},
              ),
            ),
          );
        },
        child: Card(
          margin: EdgeInsets.zero,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _navigateWithLoading(context, '/groups/${group.id}'),
            onLongPress: () async {
              final shouldDelete = await _showDeleteConfirmation(context);
              if (shouldDelete == true && context.mounted) {
                ref.read(groupsProvider.notifier).deleteGroup(group.id);
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Group icon
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.group_rounded,
                      color: AppTheme.primaryColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Group info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.person_rounded,
                              size: 14,
                              color: AppTheme.textSecondary.withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 4),
                            playersAsync.when(
                              loading: () => Text(
                                '...',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              error: (_, __) => Text(
                                '?',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              data: (players) => Text(
                                '${players.length} jugador${players.length == 1 ? '' : 'es'}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 12,
                              color: AppTheme.textSecondary.withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              dateFormat.format(group.createdAt),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Arrow
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textSecondary.withValues(alpha: 0.3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _navigateWithLoading(BuildContext context, String route) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: AppTheme.textSecondary,
      builder: (_) => Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 400));
    if (context.mounted) {
      Navigator.of(context).pop();
      context.push(route);
    }
  }

  Future<bool?> _showDeleteConfirmation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Eliminar grupo',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Text(
          '\u00bfEst\u00e1s seguro de que quieres eliminar el grupo "${group.name}"?\n\nEsta acci\u00f3n no se puede deshacer.',
          style: GoogleFonts.poppins(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.poppins(color: AppTheme.textSecondary),
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
}
