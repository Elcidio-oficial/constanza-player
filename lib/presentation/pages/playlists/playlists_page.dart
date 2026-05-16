import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:constanza_player/core/theme/app_spacing.dart';
import 'package:constanza_player/core/utils/background_helper.dart';
import 'package:constanza_player/domain/entities/playlist.dart';
import 'package:constanza_player/domain/entities/song.dart';
import 'package:constanza_player/presentation/providers/artwork_provider.dart';
import 'package:constanza_player/presentation/providers/playlist_provider.dart';
import 'package:constanza_player/presentation/providers/player_provider.dart';
import 'package:constanza_player/presentation/providers/theme_provider.dart';
import 'package:constanza_player/presentation/providers/library_provider.dart';
import 'package:constanza_player/presentation/widgets/song_tile/song_tile.dart';
import 'package:constanza_player/presentation/widgets/artwork_image.dart';
import 'package:constanza_player/presentation/widgets/background_wrapper.dart';
import 'package:constanza_player/core/utils/app_page_route.dart';
import 'package:constanza_player/services/share_service.dart';
import 'package:constanza_player/l10n/gen/app_localizations.dart';
import 'package:go_router/go_router.dart';

// ── Part files ──
part 'parts/tiles.dart';
part 'parts/user_tile.dart';
part 'parts/empty.dart';
part 'parts/detail_widgets.dart';

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
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: BackgroundHelper.scaffoldColor(colors, themeState),
      appBar: AppBar(
        backgroundColor: BackgroundHelper.appBarColor(colors, themeState),
        title: Text(
          l10n.playlistsTitle,
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
                    l10n.playlistsMyPlaylists,
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
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        title: Text(
          l10n.playlistsNewTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.playlistsNamePlaceholder,
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
                hintText: l10n.playlistsDescriptionPlaceholder,
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
              l10n.commonCancel,
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
            child: Text(
              l10n.playlistsCreate,
              style: TextStyle(color: colors.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SMART PLAYLIST TILE — ícones coloridos + stats
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
                        AppLocalizations.of(context).playlistsCount(songs.length),
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
                            AppLocalizations.of(context).albumDetailListening,
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
                              label: AppLocalizations.of(context).albumDetailPlay,
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
                              label: AppLocalizations.of(context).albumDetailShuffle,
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
                          AppLocalizations.of(context).playlistsRemovedFrom(currentPlaylist.name),
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
                              '${AppLocalizations.of(context).playlistsCount(songs.length)} · $durationLabel',
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
                    title: Text(AppLocalizations.of(context).playlistsPlayNext),
                    onTap: () {
                      ctx.pop();
                      final player = ref.read(playerProvider.notifier);
                      for (final song in songs.reversed) {
                        player.addNextInQueue(song);
                      }
                      _showSnack(context, AppLocalizations.of(context).npAddedToQueue);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.queue_music_rounded),
                    title: Text(AppLocalizations.of(context).commonAddToQueue),
                    onTap: () {
                      ctx.pop();
                      final player = ref.read(playerProvider.notifier);
                      for (final song in songs) {
                        player.addToQueue(song);
                      }
                      _showSnack(context, AppLocalizations.of(context).npAddedToQueue);
                    },
                  ),
                ],
                ListTile(
                  leading: const Icon(Icons.share_outlined),
                  title: Text(AppLocalizations.of(context).commonShare),
                  onTap: () {
                    ctx.pop();
                    ShareService.sharePlaylist(
                      context: context,
                      playlist: currentPlaylist,
                      songs: songs,
                      palette: ref.read(artworkPaletteProvider),
                    );
                  },
                ),
                if (songs.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.file_upload_outlined),
                    title: Text(AppLocalizations.of(context).playlistsExportM3U),
                    onTap: () {
                      ctx.pop();
                      final m3u = ref
                          .read(playlistProvider.notifier)
                          .exportPlaylistM3U(currentPlaylist.id);
                      Clipboard.setData(ClipboardData(text: m3u));
                      _showSnack(
                        context,
                        AppLocalizations.of(context).playlistsM3UCopied,
                      );
                    },
                  ),
                // Imagem (todas as playlists)
                ListTile(
                  leading: const Icon(Icons.image_outlined),
                  title: Text(AppLocalizations.of(context).playlistsChangeImage),
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
                    title: Text(AppLocalizations.of(context).playlistsRemoveImage),
                    onTap: () {
                      ctx.pop();
                      ref
                          .read(playlistProvider.notifier)
                          .removePlaylistImage(currentPlaylist.id);
                      _showSnack(context, AppLocalizations.of(context).playlistsImageRemoved);
                    },
                  ),
                // Editar/excluir (somente user playlists)
                if (!currentPlaylist.isSmartPlaylist) ...[
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: Text(AppLocalizations.of(context).playlistsEditPlaylist),
                    onTap: () {
                      ctx.pop();
                      _showEditDialog(context, ref, currentPlaylist);
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.delete_outline, color: colors.error),
                    title: Text(
                      AppLocalizations.of(context).playlistsExcludeTitle,
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
        _showSnack(context, AppLocalizations.of(context).playlistsImageUpdated);
      }
    } catch (_) {
      if (context.mounted) {
        _showSnack(context, AppLocalizations.of(context).playlistsImageError);
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
        title: Text(AppLocalizations.of(context).playlistsExcludeTitle),
        content: Text(AppLocalizations.of(context).playlistsExcludeBody(pl.name)),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(),
            child: Text(
              AppLocalizations.of(context).commonCancel,
              style: TextStyle(color: colors.onSurface.withValues(alpha: 0.5)),
            ),
          ),
          TextButton(
            onPressed: () {
              ctx.pop();
              ref.read(playlistProvider.notifier).deletePlaylist(pl.id);
              context.pop();
            },
            child: Text(AppLocalizations.of(context).playlistsExclude, style: TextStyle(color: colors.error)),
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
        title: Text(AppLocalizations.of(context).playlistsEditPlaylist),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).playlistsNameField,
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
                labelText: AppLocalizations.of(context).playlistsDescriptionField,
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
              AppLocalizations.of(context).commonCancel,
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
            child: Text(AppLocalizations.of(context).commonSave, style: TextStyle(color: colors.onSurface)),
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
}

// ============================================================
// HEADER BACKGROUND — imagem custom → mosaico → artwork → ícone
// ============================================================
