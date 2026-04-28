import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:constanza_player/core/theme/app_spacing.dart';
import 'package:constanza_player/core/utils/background_helper.dart';
import 'package:constanza_player/domain/entities/album.dart';
import 'package:constanza_player/domain/entities/song.dart';
import 'package:constanza_player/presentation/providers/player_provider.dart';
import 'package:constanza_player/presentation/providers/theme_provider.dart';
import 'package:constanza_player/presentation/providers/library_provider.dart';
import 'package:constanza_player/presentation/providers/playlist_provider.dart';
import 'package:constanza_player/presentation/widgets/song_tile/song_tile.dart';
import 'package:constanza_player/presentation/widgets/artwork_image.dart';
import 'package:constanza_player/presentation/widgets/artist_links_text.dart';
import 'package:constanza_player/presentation/widgets/background_wrapper.dart';
import 'package:go_router/go_router.dart';

class AlbumDetailPage extends ConsumerWidget {
  const AlbumDetailPage({super.key, required this.album});
  final Album album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final themeState = ref.watch(themeProvider);
    final albumSongs = ref
        .watch(libraryProvider)
        .sortedSongs
        .where((s) => s.album.toLowerCase() == album.name.toLowerCase())
        .toList();

    // Duração total do álbum
    final totalDuration = albumSongs.fold<Duration>(
      Duration.zero,
      (sum, s) => sum + s.duration,
    );
    final totalHours = totalDuration.inHours;
    final totalMins = totalDuration.inMinutes.remainder(60);
    final durationLabel = totalHours > 0
        ? '${totalHours}h ${totalMins}min'
        : '$totalMins min';

    // Ouvindo agora?
    final currentSong = ref.watch(playerProvider.select((s) => s.currentSong));
    final isAlbumPlaying =
        currentSong != null && albumSongs.any((s) => s.id == currentSong.id);

    return BackgroundWrapper(
      child: Scaffold(
        backgroundColor: BackgroundHelper.scaffoldColor(colors, themeState),
        body: CustomScrollView(
          slivers: [
            // ─── HEADER PREMIUM ───
            SliverAppBar(
              expandedHeight: 320,
              pinned: true,
              backgroundColor: BackgroundHelper.appBarColor(colors, themeState),
              leading: _BackButton(colors: colors),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () =>
                        _showAlbumMenu(context, ref, albumSongs, durationLabel),
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
                  album.name,
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
                background: _AlbumHeaderBackground(
                  album: album,
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
                    // Artista(s) — cada nome navega para tela do artista
                    ArtistLinksText(
                      artist: album.artist,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    // Metadata
                    Text(
                      [
                        if (album.year != null) '${album.year}',
                        '${albumSongs.length} música${albumSongs.length != 1 ? 's' : ''}',
                        if (durationLabel.isNotEmpty) durationLabel,
                      ].join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                    // Ouvindo agora badge
                    if (isAlbumPlaying) ...[
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
                              if (albumSongs.isNotEmpty) {
                                ref
                                    .read(playerProvider.notifier)
                                    .playSong(
                                      albumSongs.first,
                                      queue: albumSongs,
                                    );
                              }
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
                              if (albumSongs.isNotEmpty) {
                                ref
                                    .read(playerProvider.notifier)
                                    .playSong(
                                      albumSongs.first,
                                      queue: albumSongs,
                                      shuffle: true,
                                    );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
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
            if (albumSongs.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.music_off_rounded,
                        size: 48,
                        color: colors.onSurface.withValues(alpha: 0.1),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Nenhuma música encontrada',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList.builder(
                itemCount: albumSongs.length,
                itemBuilder: (context, index) {
                  final song = albumSongs[index];
                  return SongTile(
                    song: song,
                    showIndex: index + 1,
                    useArtistLinks: true,
                    onTap: () {
                      ref
                          .read(playerProvider.notifier)
                          .playSong(song, queue: albumSongs);
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

  void _showAlbumMenu(
    BuildContext context,
    WidgetRef ref,
    List<Song> albumSongs,
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
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.75,
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
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      ArtworkImage.album(
                        albumId: album.numericId,
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
                              album.name,
                              style: theme.textTheme.titleSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              album.artist,
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
                  leading: const Icon(Icons.playlist_play_rounded),
                  title: const Text('Reproduzir em seguida'),
                  onTap: () {
                    ctx.pop();
                    final player = ref.read(playerProvider.notifier);
                    for (final song in albumSongs.reversed) {
                      player.addNextInQueue(song);
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Adicionado à fila'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.queue_music_rounded),
                  title: const Text('Adicionar à fila'),
                  onTap: () {
                    ctx.pop();
                    final player = ref.read(playerProvider.notifier);
                    for (final song in albumSongs) {
                      player.addToQueue(song);
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Adicionado à fila'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.playlist_add_rounded),
                  title: const Text('Adicionar a Playlist'),
                  onTap: () {
                    ctx.pop();
                    _showAddToPlaylistDialog(context, ref, albumSongs);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.share_outlined),
                  title: const Text('Partilhar'),
                  onTap: () {
                    ctx.pop();
                    final buf = StringBuffer()
                      ..writeln('${album.name} — ${album.artist}')
                      ..writeln(
                        [
                          if (album.year != null) '${album.year}',
                          '${albumSongs.length} música${albumSongs.length != 1 ? 's' : ''}',
                          durationLabel,
                        ].join(' · '),
                      )
                      ..writeln()
                      ..writeln('Faixas:');
                    for (var i = 0; i < albumSongs.length; i++) {
                      buf.writeln('${i + 1}. ${albumSongs[i].title}');
                    }
                    Clipboard.setData(
                      ClipboardData(text: buf.toString().trim()),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Info do álbum copiada!'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
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

  void _showAddToPlaylistDialog(
    BuildContext context,
    WidgetRef ref,
    List<Song> songs,
  ) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final playlists = ref.read(userPlaylistsProvider);

    if (playlists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Crie uma playlist primeiro'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.6,
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
                Text(
                  'Adicionar a Playlist',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                Divider(color: colors.outline.withValues(alpha: 0.15)),
                ...playlists.map(
                  (p) => ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colors.outline.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSm,
                        ),
                      ),
                      child: Icon(
                        Icons.queue_music_rounded,
                        size: 20,
                        color: colors.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                    title: Text(p.name, style: theme.textTheme.titleSmall),
                    subtitle: Text(
                      '${p.songCount} música${p.songCount != 1 ? 's' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                    onTap: () {
                      ctx.pop();
                      for (final song in songs) {
                        ref
                            .read(playlistProvider.notifier)
                            .addSongToPlaylist(p.id, song);
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${songs.length} música${songs.length != 1 ? 's' : ''} adicionada${songs.length != 1 ? 's' : ''} a "${p.name}"',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// HEADER BACKGROUND — artwork premium com gradiente
// ============================================================

class _AlbumHeaderBackground extends StatelessWidget {
  const _AlbumHeaderBackground({required this.album, required this.colors});
  final Album album;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Full-width album artwork hero
        Positioned.fill(
          child: ArtworkImage.album(
            albumId: album.numericId,
            size: MediaQuery.sizeOf(context).width.toDouble(),
            borderRadius: BorderRadius.zero,
            placeholderIcon: Icons.album_rounded,
            placeholderIconSize: 80,
          ),
        ),
        // Top gradient for status bar readability
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 120,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Bottom gradient for title readability
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 160,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  colors.surface,
                  colors.surface.withValues(alpha: 0.8),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
      ],
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
