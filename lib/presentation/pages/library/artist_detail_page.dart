import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:constanza_player/core/theme/app_spacing.dart';
import 'package:constanza_player/core/utils/background_helper.dart';
import 'package:constanza_player/domain/entities/album.dart';
import 'package:constanza_player/domain/entities/artist.dart';
import 'package:constanza_player/domain/entities/song.dart';
import 'package:constanza_player/presentation/providers/artist_image_provider.dart';
import 'package:constanza_player/presentation/providers/player_provider.dart';
import 'package:constanza_player/presentation/providers/playlist_provider.dart';
import 'package:constanza_player/presentation/providers/theme_provider.dart';
import 'package:constanza_player/presentation/providers/library_provider.dart';
import 'package:constanza_player/presentation/widgets/song_tile/song_tile.dart';
import 'package:constanza_player/presentation/widgets/artwork_image.dart';
import 'package:constanza_player/presentation/widgets/background_wrapper.dart';
import 'package:constanza_player/presentation/pages/library/album_detail_page.dart';
import 'package:constanza_player/core/utils/app_page_route.dart';
import 'package:go_router/go_router.dart';

/// Verifica se [songArtist] inclui [artistName] como um dos artistas.
/// Suporta qualquer número de artistas com separadores variados.
bool _artistMatches(String songArtist, String artistName) {
  final target = artistName.toLowerCase().trim();
  if (songArtist.toLowerCase().trim() == target) return true;

  // Expandir feat. parentético antes de dividir
  var field = songArtist.replaceAllMapped(
    RegExp(
      r'\(\s*(?:feat\.?|ft\.?|featuring)\s+([^)]+)\)',
      caseSensitive: false,
    ),
    (m) => ' feat. ${m.group(1)}',
  );

  final parts = field.split(
    RegExp(
      r'\s*[,;/]\s*'
      r'|\s+(?:feat\.?|ft\.?|featuring)\s+'
      r'|\s+[&×·]\s+'
      r'|\s+x\s+',
      caseSensitive: false,
    ),
  );
  return parts.any((p) => p.trim().toLowerCase() == target);
}

class ArtistDetailPage extends ConsumerWidget {
  const ArtistDetailPage({super.key, required this.artist});
  final Artist artist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final themeState = ref.watch(themeProvider);
    final libState = ref.watch(libraryProvider);
    final artistSongs = libState.sortedSongs
        .where((s) => _artistMatches(s.artist, artist.name))
        .toList();
    final artistAlbums =
        libState.albums
            .where((a) => _artistMatches(a.artist, artist.name))
            .toList()
          ..sort((a, b) {
            final ay = a.year ?? 0;
            final by = b.year ?? 0;
            return by.compareTo(ay);
          });

    // Duração total
    final totalDuration = artistSongs.fold<Duration>(
      Duration.zero,
      (sum, s) => sum + s.duration,
    );
    final totalHours = totalDuration.inHours;
    final totalMins = totalDuration.inMinutes.remainder(60);
    final durationLabel = totalHours > 0
        ? '${totalHours}h ${totalMins}min'
        : '$totalMins min';

    // Favoritas
    final favCount = artistSongs.where((s) => s.isFavorite).length;

    // Mais tocadas do artista (top 5)
    final mostSongs = ref.watch(
      playlistProvider.select(
        (p) => p.where((pl) => pl.id == 'most').firstOrNull?.songs ?? const [],
      ),
    );
    final artistTopSongs = mostSongs
        .where((s) => s.artist.toLowerCase() == artist.name.toLowerCase())
        .take(5)
        .toList();

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
                    onTap: () => _showArtistMenu(
                      context,
                      ref,
                      artistSongs,
                      artistAlbums,
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
                  artist.name,
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
                background: _ArtistHeaderBackground(
                  artist: artist,
                  colors: colors,
                  theme: theme,
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
                    // Stats
                    Text(
                      '${artistSongs.length} música${artistSongs.length != 1 ? 's' : ''}'
                      ' · ${artistAlbums.length} álbun${artistAlbums.length != 1 ? 's' : ''}'
                      ' · $durationLabel'
                      '${favCount > 0 ? ' · $favCount ♥' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // Botões
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
                              if (artistSongs.isNotEmpty) {
                                ref
                                    .read(playerProvider.notifier)
                                    .playSong(
                                      artistSongs.first,
                                      queue: artistSongs,
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
                              if (artistSongs.isNotEmpty) {
                                ref
                                    .read(playerProvider.notifier)
                                    .playSong(
                                      artistSongs.first,
                                      queue: artistSongs,
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

            // ─── MAIS TOCADAS DO ARTISTA ───
            if (artistTopSongs.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.xl,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Mais Tocadas',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      Text(
                        '${artistTopSongs.length}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.25),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Divider(
                  color: colors.outline.withValues(alpha: 0.1),
                  indent: AppSpacing.md,
                  endIndent: AppSpacing.md,
                ),
              ),
              SliverList.builder(
                itemCount: artistTopSongs.length,
                itemBuilder: (context, index) {
                  final song = artistTopSongs[index];
                  return SongTile(
                    song: song,
                    showIndex: index + 1,
                    useArtistLinks: true,
                    onTap: () {
                      ref
                          .read(playerProvider.notifier)
                          .playSong(song, queue: artistTopSongs);
                    },
                  );
                },
              ),
            ],

            // ─── ÁLBUNS DO ARTISTA ───
            if (artistAlbums.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.xl,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Álbuns',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      Text(
                        '${artistAlbums.length}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.25),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 170,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    itemCount: artistAlbums.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final alb = artistAlbums[index];
                      return GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          AppPageRoute(page: AlbumDetailPage(album: alb)),
                        ),
                        child: SizedBox(
                          width: 120,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusMd,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.08,
                                      ),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: ArtworkImage.album(
                                  albumId: alb.numericId,
                                  size: 120,
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusMd,
                                  ),
                                  placeholderIcon: Icons.album_rounded,
                                  placeholderIconSize: 40,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                alb.name,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: colors.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                [
                                  if (alb.year != null) '${alb.year}',
                                  '${alb.songCount} faixa${alb.songCount != 1 ? 's' : ''}',
                                ].join(' · '),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colors.onSurface.withValues(
                                    alpha: 0.4,
                                  ),
                                  fontSize: 10,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],

            // ─── MÚSICAS DO ARTISTA ───
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xl,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Músicas',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    Text(
                      '${artistSongs.length}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.25),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Divider(
                color: colors.outline.withValues(alpha: 0.1),
                indent: AppSpacing.md,
                endIndent: AppSpacing.md,
              ),
            ),
            SliverList.builder(
              itemCount: artistSongs.length,
              itemBuilder: (context, index) {
                final song = artistSongs[index];
                return SongTile(
                  song: song,
                  useArtistLinks: true,
                  onTap: () {
                    ref
                        .read(playerProvider.notifier)
                        .playSong(song, queue: artistSongs);
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

  void _showArtistMenu(
    BuildContext context,
    WidgetRef ref,
    List<Song> artistSongs,
    List<Album> artistAlbums,
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
          maxHeight: MediaQuery.of(ctx).size.height * 0.75,
        ),
        child: SingleChildScrollView(
          child: SafeArea(
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
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: colors.onSurface.withValues(alpha: 0.07),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            artist.name.isNotEmpty
                                ? artist.name[0].toUpperCase()
                                : '?',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colors.onSurface.withValues(alpha: 0.4),
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              artist.name,
                              style: theme.textTheme.titleSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${artistSongs.length} música${artistSongs.length != 1 ? 's' : ''}',
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
                    for (final song in artistSongs.reversed) {
                      player.addNextInQueue(song);
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Adicionado à fila'),
                        backgroundColor: colors.onSurface,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSm,
                          ),
                        ),
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
                    for (final song in artistSongs) {
                      player.addToQueue(song);
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Adicionado à fila'),
                        backgroundColor: colors.onSurface,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSm,
                          ),
                        ),
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
                    _showAddToPlaylistDialog(context, ref, artistSongs);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.share_outlined),
                  title: const Text('Partilhar'),
                  onTap: () {
                    ctx.pop();
                    final buf = StringBuffer()
                      ..writeln(artist.name)
                      ..writeln(
                        '${artistSongs.length} música${artistSongs.length != 1 ? 's' : ''}'
                        ' · ${artistAlbums.length} álbun${artistAlbums.length != 1 ? 's' : ''}',
                      )
                      ..writeln()
                      ..writeln('Músicas:');
                    for (var i = 0; i < artistSongs.length; i++) {
                      buf.writeln('${i + 1}. ${artistSongs[i].title}');
                    }
                    Clipboard.setData(
                      ClipboardData(text: buf.toString().trim()),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Info do artista copiada!'),
                        backgroundColor: colors.onSurface,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSm,
                          ),
                        ),
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
          backgroundColor: colors.onSurface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
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
          maxHeight: MediaQuery.of(ctx).size.height * 0.6,
        ),
        child: SingleChildScrollView(
          child: SafeArea(
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
                          backgroundColor: colors.onSurface,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusSm,
                            ),
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
// HEADER BACKGROUND — foto online ou avatar com gradiente
// ============================================================

class _ArtistHeaderBackground extends ConsumerWidget {
  const _ArtistHeaderBackground({
    required this.artist,
    required this.colors,
    required this.theme,
  });
  final Artist artist;
  final ColorScheme colors;
  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(artistImageProvider);
    final notifier = ref.read(artistImageProvider.notifier);
    final imageUrl = notifier.getImageUrl(artist.name);
    final hasPhoto = imageUrl != null;

    return Stack(
      fit: StackFit.expand,
      children: [
        // === FOTO ou GRADIENTE ===
        if (hasPhoto)
          CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            fadeInDuration: const Duration(milliseconds: 400),
            placeholder: (_, __) => _gradientFallback(),
            errorWidget: (_, __, ___) => _gradientFallback(),
          )
        else
          _gradientFallback(),

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
        if (hasPhoto)
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

        // === Avatar com letra (só quando não tem foto) ===
        if (!hasPhoto)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 40, bottom: 48),
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.onSurface.withValues(alpha: 0.07),
                  border: Border.all(
                    color: colors.outline.withValues(alpha: 0.08),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                      spreadRadius: -4,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    artist.name.isNotEmpty ? artist.name[0].toUpperCase() : '?',
                    style: theme.textTheme.displayLarge?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.25),
                      fontWeight: FontWeight.w200,
                      fontSize: 56,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _gradientFallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.5, 1.0],
          colors: [
            colors.onSurface.withValues(alpha: 0.06),
            colors.onSurface.withValues(alpha: 0.03),
            colors.surface,
          ],
        ),
      ),
    );
  }
}

// ============================================================
// BOTÃO VOLTAR
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
