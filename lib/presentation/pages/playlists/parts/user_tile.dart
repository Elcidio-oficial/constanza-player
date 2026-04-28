// ignore_for_file: curly_braces_in_flow_control_structures, unused_element_parameter
part of '../playlists_page.dart';

class _UserPlaylistTile extends ConsumerWidget {
  const _UserPlaylistTile({required this.playlist});
  final Playlist playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // Watch live data from provider to ensure image updates propagate
    final livePlaylist = ref.watch(
      playlistProvider.select(
        (playlists) => playlists.firstWhere(
          (p) => p.id == playlist.id,
          orElse: () => playlist,
        ),
      ),
    );

    final timeAgo = _formatTimeAgo(livePlaylist.updatedAt);

    // Calcular duração
    final totalDuration = livePlaylist.songs.fold<Duration>(
      Duration.zero,
      (sum, s) => sum + s.duration,
    );
    final hours = totalDuration.inHours;
    final mins = totalDuration.inMinutes.remainder(60);
    final durationStr = hours > 0 ? '${hours}h ${mins}min' : '$mins min';

    // Montar subtitle
    final parts = <String>[
      '${livePlaylist.songCount} música${livePlaylist.songCount != 1 ? 's' : ''}',
    ];
    if (livePlaylist.songs.isNotEmpty) parts.add(durationStr);
    if (timeAgo.isNotEmpty) parts.add(timeAgo);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      leading: _PlaylistThumbnail(playlist: livePlaylist),
      title: Text(
        livePlaylist.name,
        style: theme.textTheme.titleSmall?.copyWith(color: colors.onSurface),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (livePlaylist.description != null &&
              livePlaylist.description!.isNotEmpty)
            Text(
              livePlaylist.description!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.5),
                fontStyle: FontStyle.italic,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          Text(
            parts.join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.4),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 14,
        color: colors.onSurface.withValues(alpha: 0.2),
      ),
      onTap: () {
        Navigator.of(
          context,
        ).push(AppPageRoute(page: PlaylistDetailPage(playlist: livePlaylist)));
      },
      onLongPress: () => _showOptions(context, ref),
    );
  }

  void _showOptions(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: AppSpacing.xs),
                Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      _PlaylistThumbnail(playlist: playlist, size: 40),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              playlist.name,
                              style: theme.textTheme.titleSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${playlist.songCount} música${playlist.songCount != 1 ? 's' : ''}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Divider(color: colors.outline.withValues(alpha: 0.15)),
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Editar Playlist'),
                  onTap: () {
                    ctx.pop();
                    _showEditDialog(context, ref);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.image_outlined),
                  title: const Text('Alterar Imagem'),
                  onTap: () {
                    ctx.pop();
                    _pickImage(context, ref);
                  },
                ),
                if (playlist.hasCustomImage)
                  ListTile(
                    leading: Icon(
                      Icons.hide_image_outlined,
                      color: colors.onSurface.withValues(alpha: 0.7),
                    ),
                    title: const Text('Remover Imagem'),
                    onTap: () {
                      ctx.pop();
                      ref
                          .read(playlistProvider.notifier)
                          .removePlaylistImage(playlist.id);
                      _showSnack(context, 'Imagem removida');
                    },
                  ),
                ListTile(
                  leading: Icon(Icons.delete_outline, color: colors.error),
                  title: Text('Excluir', style: TextStyle(color: colors.error)),
                  onTap: () {
                    ctx.pop();
                    _showDeleteConfirmation(context, ref);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(BuildContext context, WidgetRef ref) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 85,
      );
      if (picked == null) return;
      await ref
          .read(playlistProvider.notifier)
          .setPlaylistImage(playlist.id, picked.path);
      if (context.mounted) {
        _showSnack(context, 'Imagem atualizada');
      }
    } catch (_) {
      if (context.mounted) {
        _showSnack(context, 'Erro ao selecionar imagem');
      }
    }
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        title: const Text('Excluir Playlist'),
        content: Text(
          'Deseja excluir "${playlist.name}"? Essa ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(),
            child: Text(
              'Cancelar',
              style: TextStyle(color: colors.onSurface.withValues(alpha: 0.5)),
            ),
          ),
          TextButton(
            onPressed: () {
              ctx.pop();
              ref.read(playlistProvider.notifier).deletePlaylist(playlist.id);
            },
            child: Text('Excluir', style: TextStyle(color: colors.error)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController(text: playlist.name);
    final descController = TextEditingController(
      text: playlist.description ?? '',
    );
    final colors = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        title: const Text('Editar Playlist'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Nome',
                labelStyle: TextStyle(
                  color: colors.onSurface.withValues(alpha: 0.5),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  borderSide: BorderSide(color: colors.onSurface),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: descController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Descrição',
                labelStyle: TextStyle(
                  color: colors.onSurface.withValues(alpha: 0.4),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  borderSide: BorderSide(
                    color: colors.outline.withValues(alpha: 0.5),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  borderSide: BorderSide(color: colors.onSurface),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(),
            child: Text(
              'Cancelar',
              style: TextStyle(color: colors.onSurface.withValues(alpha: 0.5)),
            ),
          ),
          TextButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                final notifier = ref.read(playlistProvider.notifier);
                notifier.renamePlaylist(playlist.id, name);
                notifier.updateDescription(
                  playlist.id,
                  descController.text.trim(),
                );
                ctx.pop();
              }
            },
            child: Text('Salvar', style: TextStyle(color: colors.onSurface)),
          ),
        ],
      ),
    );
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  String _formatTimeAgo(DateTime? date) {
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'hoje';
    if (diff.inDays == 1) return 'ontem';
    if (diff.inDays < 7) return 'há ${diff.inDays} dias';
    if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return 'há $weeks semana${weeks > 1 ? 's' : ''}';
    }
    return 'há ${(diff.inDays / 30).floor()} mês(es)';
  }
}

// ============================================================
// EMPTY STATE
// ============================================================
