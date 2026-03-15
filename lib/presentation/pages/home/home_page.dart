import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:constanza_player/core/theme/app_spacing.dart';
import 'package:constanza_player/core/utils/background_helper.dart';
import 'package:constanza_player/domain/entities/song.dart';
import 'package:constanza_player/domain/entities/album.dart';
import 'package:constanza_player/domain/entities/artist.dart';
import 'package:constanza_player/presentation/providers/player_provider.dart';
import 'package:constanza_player/presentation/providers/theme_provider.dart';
import 'package:constanza_player/presentation/providers/library_provider.dart';
import 'package:constanza_player/presentation/providers/playlist_provider.dart';
import 'package:constanza_player/presentation/widgets/song_tile/song_tile.dart';
import 'package:constanza_player/presentation/widgets/artwork_image.dart';
import 'package:constanza_player/presentation/pages/library/album_detail_page.dart';
import 'package:constanza_player/presentation/pages/library/artist_detail_page.dart';
import 'package:constanza_player/presentation/pages/library/song_list_page.dart';
import 'package:constanza_player/presentation/pages/settings/settings_page.dart';
import 'package:constanza_player/presentation/pages/library/genres_page.dart';
import 'package:constanza_player/presentation/pages/library/composers_page.dart';
import 'package:constanza_player/presentation/pages/library/statistics_page.dart';
import 'package:constanza_player/presentation/pages/library/history_page.dart';
import 'package:constanza_player/presentation/widgets/artist_image.dart';
import 'package:constanza_player/core/utils/app_page_route.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 6) return 'Boa madrugada';
    if (h < 12) return 'Bom dia';
    if (h < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final themeState = ref.watch(themeProvider);
    final libraryState = ref.watch(libraryProvider);
    final songs = libraryState.sortedSongs;
    final albums = libraryState.albums;
    final artists = libraryState.artists;

    // Smart playlists
    final favSongs = ref.watch(
      playlistProvider.select(
        (p) => p.firstWhere((pl) => pl.id == 'fav').songs,
      ),
    );
    final recentSongs = ref.watch(
      playlistProvider.select(
        (p) => p.firstWhere((pl) => pl.id == 'recent').songs,
      ),
    );
    final mostSongs = ref.watch(
      playlistProvider.select(
        (p) => p.firstWhere((pl) => pl.id == 'most').songs,
      ),
    );

    // Currently playing song ID (for "now playing" indicator)
    final currentSongId = ref.watch(
      playerProvider.select((s) => s.currentSong?.id),
    );

    return Scaffold(
      backgroundColor: BackgroundHelper.scaffoldColor(colors, themeState),
      body: _buildBody(
        context,
        ref,
        theme,
        colors,
        themeState,
        libraryState,
        songs,
        albums,
        artists,
        favSongs,
        recentSongs,
        mostSongs,
        currentSongId,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    ColorScheme colors,
    ThemeState themeState,
    LibraryState libraryState,
    List<Song> songs,
    List<Album> albums,
    List<Artist> artists,
    List<Song> favSongs,
    List<Song> recentSongs,
    List<Song> mostSongs,
    String? currentSongId,
  ) {
    if (libraryState.isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: colors.onSurface.withValues(alpha: 0.5),
              strokeWidth: 2,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'A carregar biblioteca...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      );
    }

    if (libraryState.status == LibraryStatus.noPermission) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.folder_off_rounded,
                size: 64,
                color: colors.onSurface.withValues(alpha: 0.15),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Permissão necessária',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Permita o acesso aos ficheiros de áudio para ver a sua biblioteca.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.35),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.tonal(
                onPressed: () =>
                    ref.read(libraryProvider.notifier).retryPermission(),
                child: const Text('Permitir Acesso'),
              ),
            ],
          ),
        ),
      );
    }

    if (libraryState.status == LibraryStatus.needsFolderSetup) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.folder_open_rounded,
                size: 64,
                color: colors.onSurface.withValues(alpha: 0.15),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Selecione suas pastas',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Escolha as pastas que contêm suas músicas para começar.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.35),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.tonal(
                onPressed: () => SettingsPage.showFolderPicker(context, ref),
                child: const Text('Selecionar Pastas'),
              ),
            ],
          ),
        ),
      );
    }

    if (libraryState.status == LibraryStatus.empty ||
        (!libraryState.isLoading && songs.isEmpty)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.music_off_rounded,
                size: 64,
                color: colors.onSurface.withValues(alpha: 0.15),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Nenhuma música encontrada',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Adicione ficheiros de áudio ao dispositivo e tente novamente.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.35),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.tonal(
                onPressed: () => ref.read(libraryProvider.notifier).rescan(),
                child: const Text('Re-escanear'),
              ),
            ],
          ),
        ),
      );
    }

    // Compute recently added songs
    final addedRecently = List<Song>.of(songs)
      ..sort((a, b) {
        final aDate = a.dateAdded ?? DateTime(1970);
        final bDate = b.dateAdded ?? DateTime(1970);
        return bDate.compareTo(aDate);
      });
    final recentlyAdded = addedRecently.take(20).toList();

    // Compute total duration for stats
    final totalDur = songs.fold<Duration>(
      Duration.zero,
      (sum, s) => sum + s.duration,
    );
    final totalHours = totalDur.inHours;
    final totalMins = totalDur.inMinutes.remainder(60);
    final durationLabel = totalHours > 0
        ? '${totalHours}h ${totalMins}min'
        : '$totalMins min';

    return CustomScrollView(
      slivers: [
        // ─── HEADER ───────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 110,
          floating: true,
          snap: true,
          backgroundColor: BackgroundHelper.appBarColor(colors, themeState),
          elevation: 0,
          actions: const [SizedBox(width: 48)],
          flexibleSpace: FlexibleSpaceBar(
            expandedTitleScale: 1.0,
            titlePadding: const EdgeInsets.only(
              left: AppSpacing.md,
              bottom: 14,
            ),
            title: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.35),
                    letterSpacing: 1.2,
                    fontSize: 9,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Constanza',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w200,
                    fontSize: 24,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ─── QUICK ACTION CHIPS ──────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              0,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (favSongs.isNotEmpty) ...[
                    _QuickChip(
                      icon: Icons.favorite_rounded,
                      label: 'Favoritas',
                      onTap: () => Navigator.push(
                        context,
                        AppPageRoute(
                          page: SongListPage(
                            title: 'Favoritas',
                            songs: favSongs,
                          ),
                        ),
                      ),
                      colors: colors,
                      theme: theme,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  if (recentSongs.isNotEmpty) ...[
                    _QuickChip(
                      icon: Icons.history_rounded,
                      label: 'Recentes',
                      onTap: () => Navigator.push(
                        context,
                        AppPageRoute(
                          page: SongListPage(
                            title: 'Tocadas Recentemente',
                            songs: recentSongs,
                          ),
                        ),
                      ),
                      colors: colors,
                      theme: theme,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  if (mostSongs.isNotEmpty) ...[
                    _QuickChip(
                      icon: Icons.trending_up_rounded,
                      label: 'Mais Tocadas',
                      onTap: () => Navigator.push(
                        context,
                        AppPageRoute(
                          page: SongListPage(
                            title: 'Mais Tocadas',
                            songs: mostSongs,
                          ),
                        ),
                      ),
                      colors: colors,
                      theme: theme,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  _QuickChip(
                    icon: Icons.category_rounded,
                    label: 'Gêneros',
                    onTap: () => Navigator.push(
                      context,
                      AppPageRoute(page: const GenresPage()),
                    ),
                    colors: colors,
                    theme: theme,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _QuickChip(
                    icon: Icons.edit_note_rounded,
                    label: 'Compositores',
                    onTap: () => Navigator.push(
                      context,
                      AppPageRoute(page: const ComposersPage()),
                    ),
                    colors: colors,
                    theme: theme,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _QuickChip(
                    icon: Icons.bar_chart_rounded,
                    label: 'Estatísticas',
                    onTap: () => Navigator.push(
                      context,
                      AppPageRoute(page: const StatisticsPage()),
                    ),
                    colors: colors,
                    theme: theme,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _QuickChip(
                    icon: Icons.history_rounded,
                    label: 'Histórico',
                    onTap: () => Navigator.push(
                      context,
                      AppPageRoute(page: const HistoryPage()),
                    ),
                    colors: colors,
                    theme: theme,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _QuickChip(
                    icon: Icons.shuffle_rounded,
                    label: 'Aleatório',
                    onTap: () {
                      if (songs.isNotEmpty) {
                        ref
                            .read(playerProvider.notifier)
                            .playSong(songs.first, queue: songs, shuffle: true);
                      }
                    },
                    colors: colors,
                    theme: theme,
                  ),
                ],
              ),
            ),
          ),
        ),

        // ─── SHUFFLE HERO ─────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: GestureDetector(
              onTap: () {
                if (songs.isNotEmpty) {
                  ref
                      .read(playerProvider.notifier)
                      .playSong(songs.first, queue: songs, shuffle: true);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colors.primary.withValues(alpha: 0.12),
                      colors.primary.withValues(alpha: 0.04),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.shuffle_rounded,
                        color: colors.onPrimary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reproduzir Tudo',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${songs.length} músicas · $durationLabel · modo aleatório',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurface.withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.play_arrow_rounded,
                      color: colors.primary.withValues(alpha: 0.6),
                      size: 26,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ─── FAVORITAS ───────────────────────────────────────
        if (favSongs.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'Favoritas',
              colors: colors,
              theme: theme,
              sectionIndex: 0,
              onSeeAll: () => Navigator.push(
                context,
                AppPageRoute(
                  page: SongListPage(
                    title: 'Favoritas',
                    songs: favSongs,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 185,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                itemCount: favSongs.length.clamp(0, 20),
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final song = favSongs[index];
                  final isPlaying = song.id == currentSongId;
                  return _SongCard(
                    song: song,
                    isPlaying: isPlaying,
                    size: 130,
                    colors: colors,
                    theme: theme,
                    onTap: () => ref
                        .read(playerProvider.notifier)
                        .playSong(song, queue: favSongs),
                  );
                },
              ),
            ),
          ),
        ],

        // ─── TOCADAS RECENTEMENTE ──────────────────────────────
        if (recentSongs.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'Tocadas Recentemente',
              colors: colors,
              theme: theme,
              sectionIndex: 1,
              onSeeAll: () => Navigator.push(
                context,
                AppPageRoute(
                  page: SongListPage(
                    title: 'Tocadas Recentemente',
                    songs: recentSongs,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 170,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                itemCount: recentSongs.length.clamp(0, 20),
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final song = recentSongs[index];
                  final isPlaying = song.id == currentSongId;
                  return _SongCard(
                    song: song,
                    isPlaying: isPlaying,
                    size: 115,
                    colors: colors,
                    theme: theme,
                    onTap: () => ref
                        .read(playerProvider.notifier)
                        .playSong(song, queue: recentSongs),
                  );
                },
              ),
            ),
          ),
        ],

        // ─── MAIS TOCADAS ──────────────────────────────────────
        if (mostSongs.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'Mais Tocadas',
              colors: colors,
              theme: theme,
              sectionIndex: 2,
              onSeeAll: () => Navigator.push(
                context,
                AppPageRoute(
                  page: SongListPage(
                    title: 'Mais Tocadas',
                    songs: mostSongs,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 170,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                itemCount: mostSongs.length.clamp(0, 20),
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final song = mostSongs[index];
                  final isPlaying = song.id == currentSongId;
                  return _SongCard(
                    song: song,
                    isPlaying: isPlaying,
                    size: 115,
                    colors: colors,
                    theme: theme,
                    onTap: () => ref
                        .read(playerProvider.notifier)
                        .playSong(song, queue: mostSongs),
                  );
                },
              ),
            ),
          ),
        ],

        // ─── ADICIONADAS RECENTEMENTE ─────────────────────────
        if (recentlyAdded.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'Adicionadas Recentemente',
              colors: colors,
              theme: theme,
              sectionIndex: 3,
              onSeeAll: () => Navigator.push(
                context,
                AppPageRoute(
                  page: SongListPage(
                    title: 'Adicionadas Recentemente',
                    songs: recentlyAdded,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 170,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                itemCount: recentlyAdded.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final song = recentlyAdded[index];
                  final isPlaying = song.id == currentSongId;
                  return _SongCard(
                    song: song,
                    isPlaying: isPlaying,
                    size: 115,
                    colors: colors,
                    theme: theme,
                    onTap: () => ref
                        .read(playerProvider.notifier)
                        .playSong(song, queue: recentlyAdded),
                  );
                },
              ),
            ),
          ),
        ],

        // ─── ÁLBUNS ───────────────────────────────────────────
        if (albums.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'Álbuns',
              colors: colors,
              theme: theme,
              sectionIndex: 4,
              onSeeAll: () => Navigator.push(
                context,
                AppPageRoute(
                  page: SongListPage(
                    title: 'Todas as Músicas',
                    songs: songs,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 165,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                itemCount: albums.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final album = albums[index];
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      AppPageRoute(
                        page: AlbumDetailPage(album: album),
                      ),
                    ),
                    child: SizedBox(
                      width: 120,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusMd),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ArtworkImage.album(
                              albumId: album.numericId,
                              size: 120,
                              borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusMd),
                              placeholderIcon: Icons.album_rounded,
                              placeholderIconSize: 40,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            album.name,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colors.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            album.artist,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSurface.withValues(alpha: 0.35),
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

        // ─── ARTISTAS ─────────────────────────────────────────
        if (artists.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'Artistas',
              colors: colors,
              theme: theme,
              sectionIndex: 5,
              onSeeAll: () => Navigator.push(
                context,
                AppPageRoute(
                  page: SongListPage(
                    title: 'Todas as Músicas',
                    songs: songs,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                itemCount: artists.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.md),
                itemBuilder: (context, index) {
                  final artist = artists[index];
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      AppPageRoute(
                        page: ArtistDetailPage(artist: artist),
                      ),
                    ),
                    child: SizedBox(
                      width: 80,
                      child: Column(
                        children: [
                          ArtistImage(
                            artistName: artist.name,
                            size: 72,
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            artist.name,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color:
                                  colors.onSurface.withValues(alpha: 0.55),
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
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

        // ─── TODAS AS MÚSICAS ──────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Todas as Músicas',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w400,
                  ),
                ),
                Text(
                  '${songs.length} · $durationLabel',
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
            indent: AppSpacing.md,
            endIndent: AppSpacing.md,
            color: colors.outline.withValues(alpha: 0.12),
          ),
        ),
        SliverList.builder(
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            return SongTile(
              song: song,
              onTap: () {
                ref.read(playerProvider.notifier).playSong(song, queue: songs);
              },
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

// ============================================================
// WIDGETS AUXILIARES
// ============================================================

/// Card reutilizável para carrosséis de músicas — com indicador "tocando agora".
class _SongCard extends StatelessWidget {
  const _SongCard({
    required this.song,
    required this.isPlaying,
    required this.size,
    required this.colors,
    required this.theme,
    required this.onTap,
  });
  final Song song;
  final bool isPlaying;
  final double size;
  final ColorScheme colors;
  final ThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ArtworkImage.song(
                    songId: song.numericId,
                    size: size,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd),
                    placeholderIcon: Icons.music_note_rounded,
                    placeholderIconSize: size * 0.33,
                  ),
                ),
                // Now playing indicator
                if (isPlaying)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colors.primary.withValues(alpha: 0.4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.equalizer_rounded,
                        size: 12,
                        color: colors.onPrimary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              song.title,
              style: theme.textTheme.labelMedium?.copyWith(
                color: isPlaying ? colors.primary : colors.onSurface,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              song.artist,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.4),
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Chip de ação rápida.
class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.colors,
    required this.theme,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ColorScheme colors;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: colors.onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(
            color: colors.outline.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colors.primary.withValues(alpha: 0.8)),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section header com link "Ver tudo".
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.colors,
    required this.theme,
    this.onSeeAll,
    this.sectionIndex = 0,
  });
  final String title;
  final ColorScheme colors;
  final ThemeData theme;
  final VoidCallback? onSeeAll;
  final int sectionIndex;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.5),
              fontWeight: FontWeight.w400,
            ),
          ),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Text(
                'Ver tudo',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.primary.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    ).animate(delay: Duration(milliseconds: 60 * sectionIndex))
      .fadeIn(duration: 350.ms, curve: Curves.easeOut)
      .slideY(begin: 0.04, end: 0, duration: 350.ms, curve: Curves.easeOut);
  }
}
