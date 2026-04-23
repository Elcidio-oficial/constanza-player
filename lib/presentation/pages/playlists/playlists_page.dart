import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:constanza_player/core/theme/app_spacing.dart';
import 'package:constanza_player/core/utils/background_helper.dart';
import 'package:constanza_player/domain/entities/playlist.dart';
import 'package:constanza_player/domain/entities/song.dart';
import 'package:constanza_player/presentation/providers/playlist_provider.dart';
import 'package:constanza_player/presentation/providers/player_provider.dart';
import 'package:constanza_player/presentation/providers/theme_provider.dart';
import 'package:constanza_player/presentation/providers/library_provider.dart';
import 'package:constanza_player/presentation/widgets/song_tile/song_tile.dart';
import 'package:constanza_player/presentation/widgets/artwork_image.dart';
import 'package:constanza_player/presentation/widgets/background_wrapper.dart';
import 'package:constanza_player/core/utils/app_page_route.dart';
import 'package:go_router/go_router.dart';

/// Página de Playlists — Smart + Minhas Playlists.
class PlaylistsPage extends ConsumerWidget {
  const PlaylistsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final themeState = ref.watch(themeProvider);
    final smartPlaylists = ref.watch(smartPlaylistsProvider);
    final userPlaylists = ref.watch(userPlaylistsProvider);

    return Scaffold(
      backgroundColor: BackgroundHelper.scaffoldColor(colors, themeState),
      appBar: AppBar(
        backgroundColor: BackgroundHelper.appBarColor(colors, themeState),
        title: Text(
          'Playlists',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w300,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showCreateDialog(context, ref),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            sliver: SliverList.builder(
              itemCount: smartPlaylists.length,
              itemBuilder: (_, i) =>
                  _SmartPlaylistTile(playlist: smartPlaylists[i]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Text(
                    'MINHAS PLAYLISTS',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.35),
                      letterSpacing: 1.5,
                    ),
                  ),
                  if (userPlaylists.isNotEmpty) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: colors.onSurface.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${userPlaylists.length}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.35),
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Divider(
                      color: colors.outline.withValues(alpha: 0.2),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (userPlaylists.isEmpty)
            SliverToBoxAdapter(
              child: _EmptyPlaylists(
                onCreateTap: () => _showCreateDialog(context, ref),
              ),
            )
          else
            SliverList.builder(
              itemCount: userPlaylists.length,
              itemBuilder: (_, i) =>
                  _UserPlaylistTile(playlist: userPlaylists[i]),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
        ],
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final colors = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        title: Text(
          'Nova Playlist',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Nome da playlist',
                hintStyle: TextStyle(
                  color: colors.onSurface.withValues(alpha: 0.3),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  borderSide: BorderSide(color: colors.outline),
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
                hintText: 'Descrição (opcional)',
                hintStyle: TextStyle(
                  color: colors.onSurface.withValues(alpha: 0.25),
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
                final desc = descController.text.trim();
                ref
                    .read(playlistProvider.notifier)
                    .createPlaylist(
                      name,
                      description: desc.isEmpty ? null : desc,
                    );
                ctx.pop();
              }
            },
            child: Text('Criar', style: TextStyle(color: colors.onSurface)),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SMART PLAYLIST TILE — ícones coloridos + stats
// ============================================================

class _SmartPlaylistTile extends ConsumerWidget {
  const _SmartPlaylistTile({required this.playlist});
  final Playlist playlist;

  IconData get _icon => switch (playlist.id) {
    'fav' => Icons.favorite_rounded,
    'recent' => Icons.history_rounded,
    'most' => Icons.trending_up_rounded,
    _ => Icons.queue_music_rounded,
  };

  Color _accentColor(ColorScheme colors) => switch (playlist.id) {
    'fav' => colors.error,
    'recent' => colors.primary,
    'most' => Colors.amber.shade600,
    _ => colors.onSurface.withValues(alpha: 0.5),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = _accentColor(colors);

    // Para 'fav' puxar dados reais da library
    final songs = playlist.id == 'fav'
        ? ref.watch(
            libraryProvider.select(
              (s) => s.songs.where((s) => s.isFavorite).toList(),
            ),
          )
        : playlist.songs;

    final totalDuration = songs.fold<Duration>(
      Duration.zero,
      (sum, s) => sum + s.duration,
    );
    final hours = totalDuration.inHours;
    final mins = totalDuration.inMinutes.remainder(60);
    final durationStr = hours > 0 ? '${hours}h ${mins}min' : '$mins min';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      leading: songs.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              child: ArtworkImage.song(
                songId: songs.first.numericId,
                size: 52,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                placeholderIcon: _icon,
                placeholderIconSize: 24,
              ),
            )
          : Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(_icon, size: 22, color: accent),
            ),
      title: Text(
        playlist.name,
        style: theme.textTheme.titleSmall?.copyWith(color: colors.onSurface),
      ),
      subtitle: Text(
        songs.isEmpty
            ? 'Nenhuma música'
            : '${songs.length} música${songs.length != 1 ? 's' : ''} · $durationStr',
        style: theme.textTheme.bodySmall?.copyWith(
          color: colors.onSurface.withValues(alpha: 0.35),
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 14,
        color: colors.onSurface.withValues(alpha: 0.2),
      ),
      onTap: () {
        Navigator.of(
          context,
        ).push(AppPageRoute(page: PlaylistDetailPage(playlist: playlist)));
      },
    );
  }
}

// ============================================================
// PLAYLIST THUMBNAIL — imagem custom → artwork → ícone
// ============================================================

class _PlaylistThumbnail extends StatelessWidget {
  const _PlaylistThumbnail({
    required this.playlist,
    this.size = 44,
    this.borderRadius,
  });
  final Playlist playlist;
  final double size;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radius = borderRadius ?? BorderRadius.circular(AppSpacing.radiusSm);

    // 1. Imagem customizada
    if (playlist.hasCustomImage) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.file(
          File(playlist.imagePath!),
          key: ValueKey(playlist.imagePath),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackIcon(colors, radius),
        ),
      );
    }

    // 2. Artwork da primeira música
    if (playlist.songs.isNotEmpty) {
      return ClipRRect(
        borderRadius: radius,
        child: ArtworkImage.song(
          songId: playlist.songs.first.numericId,
          size: size,
          borderRadius: radius,
        ),
      );
    }

    // 3. Ícone fallback
    return _fallbackIcon(colors, radius);
  }

  Widget _fallbackIcon(ColorScheme colors, BorderRadius radius) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.outline.withValues(alpha: 0.12),
        borderRadius: radius,
      ),
      child: Icon(
        Icons.music_note_rounded,
        size: size * 0.5,
        color: colors.onSurface.withValues(alpha: 0.25),
      ),
    );
  }
}

// ============================================================
// USER PLAYLIST TILE — thumbnail + descrição + stats
// ============================================================

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
    final colors = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: colors.onSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        duration: const Duration(seconds: 2),
      ),
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

class _EmptyPlaylists extends StatelessWidget {
  const _EmptyPlaylists({required this.onCreateTap});
  final VoidCallback onCreateTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxl,
      ),
      child: Column(
        children: [
          Icon(
            Icons.playlist_add_rounded,
            size: 48,
            color: colors.onSurface.withValues(alpha: 0.15),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Nenhuma playlist criada',
            style: theme.textTheme.titleSmall?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Crie sua primeira playlist',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.25),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          GestureDetector(
            onTap: onCreateTap,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                border: Border.all(
                  color: colors.outline.withValues(alpha: 0.3),
                ),
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
              child: Text(
                '+ Nova Playlist',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// PLAYLIST DETAIL PAGE — Premium (nível de Album/Artist Detail)
// ============================================================

class PlaylistDetailPage extends ConsumerWidget {
  const PlaylistDetailPage({super.key, required this.playlist});
  final Playlist playlist;

  IconData get _icon => switch (playlist.id) {
    'fav' => Icons.favorite_rounded,
    'recent' => Icons.history_rounded,
    'most' => Icons.trending_up_rounded,
    _ => Icons.queue_music_rounded,
  };

  Color _accentColor(ColorScheme colors) => switch (playlist.id) {
    'fav' => colors.error,
    'recent' => colors.primary,
    'most' => Colors.amber.shade600,
    _ => colors.tertiary,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final themeState = ref.watch(themeProvider);
    final accent = _accentColor(colors);

    final currentPlaylist = ref.watch(
      playlistProvider.select(
        (playlists) => playlists.firstWhere((p) => p.id == playlist.id),
      ),
    );

    // 'fav' → deriva das músicas favoritas na biblioteca
    final songs = playlist.id == 'fav'
        ? ref.watch(
            libraryProvider.select(
              (s) => s.songs.where((s) => s.isFavorite).toList(),
            ),
          )
        : currentPlaylist.songs;

    // Duração total
    final totalDuration = songs.fold<Duration>(
      Duration.zero,
      (sum, s) => sum + s.duration,
    );
    final totalHours = totalDuration.inHours;
    final totalMins = totalDuration.inMinutes.remainder(60);
    final durationLabel = totalHours > 0
        ? '${totalHours}h ${totalMins}min'
        : '$totalMins min';

    // Favoritas na playlist
    final favCount = songs.where((s) => s.isFavorite).length;

    // Ouvindo agora?
    final currentSong = ref.watch(playerProvider.select((s) => s.currentSong));
    final isPlaylistPlaying =
        currentSong != null && songs.any((s) => s.id == currentSong.id);

    final emptyMessage = switch (playlist.id) {
      'fav' => 'Nenhuma música favorita\nToque ♥ em uma música para adicionar',
      'recent' =>
        'Nenhuma música tocada ainda\nReproduza músicas para ver aqui',
      'most' => 'Nenhuma música tocada ainda\nReproduza músicas para ver aqui',
      _ => 'Playlist vazia\nAdicione músicas pelo menu ⋮ de qualquer música',
    };

    final emptyIcon = switch (playlist.id) {
      'fav' => Icons.favorite_border_rounded,
      'recent' => Icons.history_rounded,
      'most' => Icons.trending_up_rounded,
      _ => Icons.music_off_rounded,
    };

    return BackgroundWrapper(
      child: Scaffold(
        backgroundColor: BackgroundHelper.scaffoldColor(colors, themeState),
        body: CustomScrollView(
          slivers: [
            // ─── HEADER PREMIUM ───
            SliverAppBar(
              expandedHeight: 300,
              pinned: true,
              backgroundColor: BackgroundHelper.appBarColor(colors, themeState),
              leading: _BackButton(colors: colors),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _showPlaylistMenu(
                      context,
                      ref,
                      songs,
                      currentPlaylist,
                      durationLabel,
                    ),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: colors.surface.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.outline.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Icon(
                        Icons.more_vert_rounded,
                        color: colors.onSurface,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  currentPlaylist.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                titlePadding: const EdgeInsets.only(
                  left: 56,
                  right: 56,
                  bottom: 16,
                ),
                background: _PlaylistHeaderBackground(
                  playlist: currentPlaylist,
                  songs: songs,
                  icon: _icon,
                  accent: accent,
                  colors: colors,
                ),
              ),
            ),

            // ─── INFO + AÇÕES ───
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Descrição
                    if (currentPlaylist.description != null &&
                        currentPlaylist.description!.isNotEmpty) ...[
                      Text(
                        currentPlaylist.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.5),
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                    // Stats
                    Text(
                      [
                        '${songs.length} música${songs.length != 1 ? 's' : ''}',
                        if (songs.isNotEmpty) durationLabel,
                        if (favCount > 0) '$favCount ♥',
                      ].join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                    // Ouvindo agora badge
                    if (isPlaylistPlaying) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.equalizer_rounded,
                            size: 14,
                            color: colors.tertiary,
                          ),
                          const SizedBox(width: AppSpacing.xxs),
                          Text(
                            'Ouvindo agora',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.tertiary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (songs.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      // Botões de ação
                      Row(
                        children: [
                          Expanded(
                            child: _PremiumActionButton(
                              icon: Icons.play_arrow_rounded,
                              label: 'Reproduzir',
                              filled: true,
                              colors: colors,
                              theme: theme,
                              onTap: () {
                                ref
                                    .read(playerProvider.notifier)
                                    .playSong(songs.first, queue: songs);
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _PremiumActionButton(
                              icon: Icons.shuffle_rounded,
                              label: 'Aleatório',
                              filled: false,
                              colors: colors,
                              theme: theme,
                              onTap: () {
                                ref
                                    .read(playerProvider.notifier)
                                    .playSong(
                                      songs.first,
                                      queue: songs,
                                      shuffle: true,
                                    );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ─── DIVIDER ───
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Divider(
                  color: colors.outline.withValues(alpha: 0.1),
                  indent: AppSpacing.md,
                  endIndent: AppSpacing.md,
                ),
              ),
            ),

            // ─── LISTA DE MÚSICAS ───
            if (songs.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          emptyIcon,
                          size: 48,
                          color: colors.onSurface.withValues(alpha: 0.15),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          emptyMessage,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurface.withValues(alpha: 0.4),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverList.builder(
                itemCount: songs.length,
                itemBuilder: (context, index) {
                  final song = songs[index];

                  // User playlists: swipe para remover
                  if (!currentPlaylist.isSmartPlaylist) {
                    return Dismissible(
                      key: ValueKey('${playlist.id}_${song.id}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: AppSpacing.lg),
                        color: colors.error.withValues(alpha: 0.15),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          color: colors.error,
                        ),
                      ),
                      confirmDismiss: (_) async => true,
                      onDismissed: (_) {
                        ref
                            .read(playlistProvider.notifier)
                            .removeSongFromPlaylist(playlist.id, song.id);
                        _showSnack(
                          context,
                          'Removido de "${currentPlaylist.name}"',
                        );
                      },
                      child: SongTile(
                        song: song,
                        showIndex: index + 1,
                        useArtistLinks: true,
                        onTap: () {
                          ref
                              .read(playerProvider.notifier)
                              .playSong(song, queue: songs);
                        },
                      ),
                    );
                  }

                  return SongTile(
                    song: song,
                    showIndex: index + 1,
                    useArtistLinks: true,
                    onTap: () {
                      ref
                          .read(playerProvider.notifier)
                          .playSong(song, queue: songs);
                    },
                  );
                },
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  void _showPlaylistMenu(
    BuildContext context,
    WidgetRef ref,
    List<Song> songs,
    Playlist currentPlaylist,
    String durationLabel,
  ) {
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
                      _PlaylistThumbnail(
                        playlist: currentPlaylist,
                        size: 48,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSm,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentPlaylist.name,
                              style: theme.textTheme.titleSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${songs.length} música${songs.length != 1 ? 's' : ''} · $durationLabel',
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
                if (songs.isNotEmpty) ...[
                  ListTile(
                    leading: const Icon(Icons.playlist_play_rounded),
                    title: const Text('Reproduzir em seguida'),
                    onTap: () {
                      ctx.pop();
                      final player = ref.read(playerProvider.notifier);
                      for (final song in songs.reversed) {
                        player.addNextInQueue(song);
                      }
                      _showSnack(context, 'Adicionado à fila');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.queue_music_rounded),
                    title: const Text('Adicionar à fila'),
                    onTap: () {
                      ctx.pop();
                      final player = ref.read(playerProvider.notifier);
                      for (final song in songs) {
                        player.addToQueue(song);
                      }
                      _showSnack(context, 'Adicionado à fila');
                    },
                  ),
                ],
                ListTile(
                  leading: const Icon(Icons.share_outlined),
                  title: const Text('Partilhar'),
                  onTap: () {
                    ctx.pop();
                    final buf = StringBuffer()
                      ..writeln(currentPlaylist.name)
                      ..writeln(
                        '${songs.length} música${songs.length != 1 ? 's' : ''} · $durationLabel',
                      )
                      ..writeln();
                    if (songs.isNotEmpty) {
                      buf.writeln('Músicas:');
                      for (var i = 0; i < songs.length; i++) {
                        buf.writeln(
                          '${i + 1}. ${songs[i].title} — ${songs[i].artist}',
                        );
                      }
                    }
                    Clipboard.setData(
                      ClipboardData(text: buf.toString().trim()),
                    );
                    _showSnack(context, 'Info da playlist copiada!');
                  },
                ),
                if (songs.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.file_upload_outlined),
                    title: const Text('Exportar Playlist (M3U)'),
                    onTap: () {
                      ctx.pop();
                      final m3u = ref
                          .read(playlistProvider.notifier)
                          .exportPlaylistM3U(currentPlaylist.id);
                      Clipboard.setData(ClipboardData(text: m3u));
                      _showSnack(
                        context,
                        'Playlist copiada para a area de transferencia',
                      );
                    },
                  ),
                // Imagem (todas as playlists)
                ListTile(
                  leading: const Icon(Icons.image_outlined),
                  title: const Text('Alterar Imagem'),
                  onTap: () {
                    ctx.pop();
                    _pickImage(context, ref, currentPlaylist.id);
                  },
                ),
                if (currentPlaylist.hasCustomImage)
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
                          .removePlaylistImage(currentPlaylist.id);
                      _showSnack(context, 'Imagem removida');
                    },
                  ),
                // Editar/excluir (somente user playlists)
                if (!currentPlaylist.isSmartPlaylist) ...[
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('Editar Playlist'),
                    onTap: () {
                      ctx.pop();
                      _showEditDialog(context, ref, currentPlaylist);
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.delete_outline, color: colors.error),
                    title: Text(
                      'Excluir Playlist',
                      style: TextStyle(color: colors.error),
                    ),
                    onTap: () {
                      ctx.pop();
                      _showDeleteConfirmation(context, ref, currentPlaylist);
                    },
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(
    BuildContext context,
    WidgetRef ref,
    String playlistId,
  ) async {
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
          .setPlaylistImage(playlistId, picked.path);
      if (context.mounted) {
        _showSnack(context, 'Imagem atualizada');
      }
    } catch (_) {
      if (context.mounted) {
        _showSnack(context, 'Erro ao selecionar imagem');
      }
    }
  }

  void _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    Playlist pl,
  ) {
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
          'Deseja excluir "${pl.name}"? Essa ação não pode ser desfeita.',
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
              ref.read(playlistProvider.notifier).deletePlaylist(pl.id);
              context.pop(); // Volta da detail page
            },
            child: Text('Excluir', style: TextStyle(color: colors.error)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    Playlist currentPlaylist,
  ) {
    final nameController = TextEditingController(text: currentPlaylist.name);
    final descController = TextEditingController(
      text: currentPlaylist.description ?? '',
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
    final colors = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: colors.onSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ============================================================
// HEADER BACKGROUND — imagem custom → mosaico → artwork → ícone
// ============================================================

class _PlaylistHeaderBackground extends StatelessWidget {
  const _PlaylistHeaderBackground({
    required this.playlist,
    required this.songs,
    required this.icon,
    required this.accent,
    required this.colors,
  });
  final Playlist playlist;
  final List<Song> songs;
  final IconData icon;
  final Color accent;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // === IMAGEM ou GRADIENTE (full-width) ===
        _buildBackground(),

        // === Gradiente inferior (legibilidade do título) ===
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 140,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors.surface.withValues(alpha: 0.0),
                  colors.surface.withValues(alpha: 0.7),
                  colors.surface,
                ],
              ),
            ),
          ),
        ),

        // === Gradiente superior (legibilidade do botão voltar) ===
        if (_hasImage)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 100,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.black.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

        // === Ícone central (só quando não tem imagem nem músicas) ===
        if (!_hasImage)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 40, bottom: 48),
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  border: Border.all(color: accent.withValues(alpha: 0.15)),
                ),
                child: Icon(
                  icon,
                  size: 64,
                  color: accent.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
      ],
    );
  }

  bool get _hasImage => playlist.hasCustomImage || songs.isNotEmpty;

  Widget _buildBackground() {
    // 1. Custom image — full-width cover
    if (playlist.hasCustomImage) {
      return Image.file(
        File(playlist.imagePath!),
        key: ValueKey(playlist.imagePath),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _gradientFallback(),
      );
    }

    // 2. Mosaico 2x2 full-width (4+ músicas)
    if (songs.length >= 4) {
      return _FullWidthMosaic(songs: songs, colors: colors);
    }

    // 3. First song artwork full-width
    if (songs.isNotEmpty) {
      return ArtworkImage.song(
        songId: songs.first.numericId,
        size: 300,
        borderRadius: BorderRadius.zero,
        placeholderIcon: icon,
        placeholderIconSize: 64,
      );
    }

    // 4. Gradient fallback
    return _gradientFallback();
  }

  Widget _gradientFallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.5, 1.0],
          colors: [
            accent.withValues(alpha: 0.08),
            accent.withValues(alpha: 0.03),
            colors.surface,
          ],
        ),
      ),
    );
  }
}

// ============================================================
// MOSAICO FULL-WIDTH 2x2 para header
// ============================================================

class _FullWidthMosaic extends StatelessWidget {
  const _FullWidthMosaic({required this.songs, required this.colors});
  final List<Song> songs;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final unique = <int, Song>{};
    for (final s in songs) {
      if (unique.length >= 4) break;
      unique.putIfAbsent(s.numericId, () => s);
    }
    final display = unique.values.toList();
    while (display.length < 4) {
      display.add(songs[display.length % songs.length]);
    }

    return GridView.count(
      crossAxisCount: 2,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      mainAxisSpacing: 1,
      crossAxisSpacing: 1,
      children: display
          .take(4)
          .map(
            (s) => ArtworkImage.song(
              songId: s.numericId,
              size: 200,
              borderRadius: BorderRadius.zero,
            ),
          )
          .toList(),
    );
  }
}

// ============================================================
// BOTÃO VOLTAR PREMIUM
// ============================================================

class _BackButton extends StatelessWidget {
  const _BackButton({required this.colors});
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: GestureDetector(
        onTap: () => context.pop(),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.8),
            shape: BoxShape.circle,
            border: Border.all(color: colors.outline.withValues(alpha: 0.1)),
          ),
          child: Icon(
            Icons.arrow_back_rounded,
            color: colors.onSurface,
            size: 20,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// BOTÃO DE AÇÃO PREMIUM
// ============================================================

class _PremiumActionButton extends StatelessWidget {
  const _PremiumActionButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.colors,
    required this.theme,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool filled;
  final ColorScheme colors;
  final ThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: filled
              ? colors.primary
              : colors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: filled
              ? null
              : Border.all(color: colors.primary.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: filled ? colors.onPrimary : colors.primary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: filled ? colors.onPrimary : colors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
