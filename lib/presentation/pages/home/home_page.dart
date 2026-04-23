import 'dart:math';
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
import 'package:constanza_player/presentation/providers/audio_analysis_provider.dart';
import 'package:constanza_player/presentation/widgets/song_tile/song_tile.dart';
import 'package:constanza_player/presentation/widgets/artwork_image.dart';
import 'package:constanza_player/presentation/pages/settings/settings_page.dart';
import 'package:constanza_player/presentation/widgets/artist_image.dart';
import 'package:constanza_player/services/audio_analysis_service.dart';
import 'package:constanza_player/presentation/pages/now_playing/now_playing_page.dart';
import 'package:go_router/go_router.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 6) return 'Boa madrugada';
    if (h < 12) return 'Bom dia';
    if (h < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  String get _moodSuggestion {
    final h = DateTime.now().hour;
    if (h < 6) return 'Músicas calmas para a madrugada';
    if (h < 10) return 'Comece o dia com energia';
    if (h < 14) return 'Ritmo para o seu dia';
    if (h < 18) return 'Som da tarde';
    if (h < 22) return 'Relaxe com suas favoritas';
    return 'Sons para o fim do dia';
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

    final favSongs = ref.watch(
      playlistProvider.select(
        (p) => p.where((pl) => pl.id == 'fav').firstOrNull?.songs ?? const [],
      ),
    );
    final recentSongs = ref.watch(
      playlistProvider.select(
        (p) =>
            p.where((pl) => pl.id == 'recent').firstOrNull?.songs ?? const [],
      ),
    );
    final mostSongs = ref.watch(
      playlistProvider.select(
        (p) => p.where((pl) => pl.id == 'most').firstOrNull?.songs ?? const [],
      ),
    );

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

    // ── Data preparation ─────────────────────────────────────
    final addedRecently = List<Song>.of(songs)
      ..sort((a, b) {
        final aDate = a.dateAdded ?? DateTime(1970);
        final bDate = b.dateAdded ?? DateTime(1970);
        return bDate.compareTo(aDate);
      });
    final recentlyAdded = addedRecently.take(20).toList();

    final totalDur = songs.fold<Duration>(
      Duration.zero,
      (sum, s) => sum + s.duration,
    );
    final totalHours = totalDur.inHours;
    final totalMins = totalDur.inMinutes.remainder(60);
    final durationLabel = totalHours > 0
        ? '${totalHours}h ${totalMins}min'
        : '$totalMins min';

    // Player state for hero card
    final playerState = ref.watch(playerProvider);
    final currentSong = playerState.currentSong;

    // Analysis for current song
    final analysisState = ref.watch(audioAnalysisProvider);

    // Mood-based quick picks (time-aware suggestion)
    final moodPicks = _getMoodPicks(songs, recentSongs, favSongs);

    int sectionIdx = 0;

    return CustomScrollView(
      slivers: [
        // ─── HEADER ───────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 100,
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
                    shadows: themeState.hasBackground
                        ? [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.7),
                              blurRadius: 6,
                            ),
                          ]
                        : null,
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
                    shadows: themeState.hasBackground
                        ? [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.8),
                              blurRadius: 8,
                            ),
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 16,
                            ),
                          ]
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ─── NOW PLAYING HERO CARD ───────────────────────────
        if (currentSong != null)
          SliverToBoxAdapter(
            child:
                _NowPlayingHero(
                      song: currentSong,
                      isPlaying: playerState.isPlaying,
                      progress: playerState.progress,
                      analysis: analysisState.result,
                      colors: colors,
                      theme: theme,
                      onTap: () => _openNowPlaying(context),
                      onPlayPause: () {
                        final notifier = ref.read(playerProvider.notifier);
                        notifier.togglePlayPause();
                      },
                    )
                    .animate()
                    .fadeIn(duration: 400.ms, curve: Curves.easeOut)
                    .slideY(begin: 0.03, end: 0, duration: 400.ms),
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
                      onTap: () => context.push(
                        '/song-list',
                        extra: {'title': 'Favoritas', 'songs': favSongs},
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
                      onTap: () => context.push(
                        '/song-list',
                        extra: {
                          'title': 'Tocadas Recentemente',
                          'songs': recentSongs,
                        },
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
                      onTap: () => context.push(
                        '/song-list',
                        extra: {'title': 'Mais Tocadas', 'songs': mostSongs},
                      ),
                      colors: colors,
                      theme: theme,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  _QuickChip(
                    icon: Icons.category_rounded,
                    label: 'Gêneros',
                    onTap: () => context.push('/genres'),
                    colors: colors,
                    theme: theme,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _QuickChip(
                    icon: Icons.edit_note_rounded,
                    label: 'Compositores',
                    onTap: () => context.push('/composers'),
                    colors: colors,
                    theme: theme,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _QuickChip(
                    icon: Icons.bar_chart_rounded,
                    label: 'Estatísticas',
                    onTap: () => context.push('/statistics'),
                    colors: colors,
                    theme: theme,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _QuickChip(
                    icon: Icons.history_rounded,
                    label: 'Histórico',
                    onTap: () => context.push('/history'),
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

        // ─── MOOD PICKS (time-aware) ─────────────────────────
        if (moodPicks.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _SectionHeader(
              title: _moodSuggestion,
              colors: colors,
              theme: theme,
              sectionIndex: sectionIdx++,
              icon: Icons.auto_awesome_rounded,
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                itemCount: moodPicks.length.clamp(0, 15),
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final song = moodPicks[index];
                  final isPlaying = song.id == currentSongId;
                  final analysis = AudioAnalysisService.getCached(song.id);
                  return _PremiumSongCard(
                    song: song,
                    isPlaying: isPlaying,
                    size: 140,
                    analysis: analysis,
                    colors: colors,
                    theme: theme,
                    onTap: () => ref
                        .read(playerProvider.notifier)
                        .playSong(song, queue: moodPicks),
                  );
                },
              ),
            ),
          ),
        ],

        // ─── FAVORITAS ───────────────────────────────────────
        if (favSongs.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'Favoritas',
              colors: colors,
              theme: theme,
              sectionIndex: sectionIdx++,
              icon: Icons.favorite_rounded,
              onSeeAll: () => context.push(
                '/song-list',
                extra: {'title': 'Favoritas', 'songs': favSongs},
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                itemCount: favSongs.length.clamp(0, 20),
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final song = favSongs[index];
                  final isPlaying = song.id == currentSongId;
                  final analysis = AudioAnalysisService.getCached(song.id);
                  return _PremiumSongCard(
                    song: song,
                    isPlaying: isPlaying,
                    size: 140,
                    analysis: analysis,
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

        // ─── TOCADAS RECENTEMENTE ────────────────────────────
        if (recentSongs.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'Tocadas Recentemente',
              colors: colors,
              theme: theme,
              sectionIndex: sectionIdx++,
              icon: Icons.history_rounded,
              onSeeAll: () => context.push(
                '/song-list',
                extra: {'title': 'Tocadas Recentemente', 'songs': recentSongs},
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                itemCount: recentSongs.length.clamp(0, 20),
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final song = recentSongs[index];
                  final isPlaying = song.id == currentSongId;
                  return _SongCard(
                    song: song,
                    isPlaying: isPlaying,
                    size: 120,
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

        // ─── MAIS TOCADAS ────────────────────────────────────
        if (mostSongs.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'Mais Tocadas',
              colors: colors,
              theme: theme,
              sectionIndex: sectionIdx++,
              icon: Icons.trending_up_rounded,
              onSeeAll: () => context.push(
                '/song-list',
                extra: {'title': 'Mais Tocadas', 'songs': mostSongs},
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                itemCount: mostSongs.length.clamp(0, 20),
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final song = mostSongs[index];
                  final isPlaying = song.id == currentSongId;
                  return _SongCard(
                    song: song,
                    isPlaying: isPlaying,
                    size: 120,
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

        // ─── ADICIONADAS RECENTEMENTE ────────────────────────
        if (recentlyAdded.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'Adicionadas Recentemente',
              colors: colors,
              theme: theme,
              sectionIndex: sectionIdx++,
              icon: Icons.new_releases_rounded,
              onSeeAll: () => context.push(
                '/song-list',
                extra: {
                  'title': 'Adicionadas Recentemente',
                  'songs': recentlyAdded,
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                itemCount: recentlyAdded.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final song = recentlyAdded[index];
                  final isPlaying = song.id == currentSongId;
                  return _SongCard(
                    song: song,
                    isPlaying: isPlaying,
                    size: 120,
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
              sectionIndex: sectionIdx++,
              icon: Icons.album_rounded,
              onSeeAll: () => context.push(
                '/song-list',
                extra: {'title': 'Todas as Músicas', 'songs': songs},
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 175,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                itemCount: albums.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final album = albums[index];
                  return GestureDetector(
                    onTap: () => context.push('/album', extra: album),
                    child: SizedBox(
                      width: 130,
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
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ArtworkImage.album(
                              albumId: album.numericId,
                              size: 130,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusMd,
                              ),
                              placeholderIcon: Icons.album_rounded,
                              placeholderIconSize: 44,
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
              sectionIndex: sectionIdx++,
              icon: Icons.person_rounded,
              onSeeAll: () => context.push(
                '/song-list',
                extra: {'title': 'Todas as Músicas', 'songs': songs},
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                itemCount: artists.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.md),
                itemBuilder: (context, index) {
                  final artist = artists[index];
                  return GestureDetector(
                    onTap: () => context.push('/artist', extra: artist),
                    child: SizedBox(
                      width: 80,
                      child: Column(
                        children: [
                          ArtistImage(artistName: artist.name, size: 72),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            artist.name,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSurface.withValues(alpha: 0.55),
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

        // ─── LIBRARY STATS BAR ────────────────────────────────
        SliverToBoxAdapter(
          child:
              _LibraryStatsBar(
                    songCount: songs.length,
                    albumCount: albums.length,
                    artistCount: artists.length,
                    durationLabel: durationLabel,
                    colors: colors,
                    theme: theme,
                  )
                  .animate(delay: Duration(milliseconds: 60 * sectionIdx))
                  .fadeIn(duration: 350.ms)
                  .slideY(begin: 0.04, end: 0, duration: 350.ms),
        ),

        // ─── TODAS AS MÚSICAS ──────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
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
              onTap: () => ref
                  .read(playerProvider.notifier)
                  .playSong(song, queue: songs),
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  void _openNowPlaying(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const NowPlayingPage(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  /// Mood-based picks: combine favorites + recent + random based on time of day.
  List<Song> _getMoodPicks(
    List<Song> songs,
    List<Song> recent,
    List<Song> favs,
  ) {
    if (songs.isEmpty) return [];
    final rng = Random(DateTime.now().day); // Stable per day
    final picks = <Song>[];
    final seen = <String>{};

    void addUnique(Song s) {
      if (seen.add(s.id)) picks.add(s);
    }

    // Mix favorites and recents
    for (var i = 0; i < min(5, favs.length); i++) {
      addUnique(favs[i]);
    }
    for (var i = 0; i < min(5, recent.length); i++) {
      addUnique(recent[i]);
    }

    // Fill with random songs
    final shuffled = List<Song>.of(songs)..shuffle(rng);
    for (final s in shuffled) {
      if (picks.length >= 15) break;
      addUnique(s);
    }

    return picks;
  }
}

// ============================================================
// NOW PLAYING HERO CARD — premium card at top when music is playing
// ============================================================

class _NowPlayingHero extends StatelessWidget {
  const _NowPlayingHero({
    required this.song,
    required this.isPlaying,
    required this.progress,
    required this.analysis,
    required this.colors,
    required this.theme,
    required this.onTap,
    required this.onPlayPause,
  });

  final Song song;
  final bool isPlaying;
  final double progress;
  final AudioAnalysisResult? analysis;
  final ColorScheme colors;
  final ThemeData theme;
  final VoidCallback onTap;
  final VoidCallback onPlayPause;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.primary.withValues(alpha: 0.15),
                colors.primaryContainer.withValues(alpha: 0.08),
                colors.surface.withValues(alpha: 0.4),
              ],
            ),
            border: Border.all(color: colors.primary.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    // Artwork with glow
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colors.primary.withValues(alpha: 0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ArtworkImage.song(
                        songId: song.numericId,
                        size: 64,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd,
                        ),
                        placeholderIcon: Icons.music_note_rounded,
                        placeholderIconSize: 28,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    // Song info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (isPlaying)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: _PulsingDot(color: colors.primary),
                                ),
                              Expanded(
                                child: Text(
                                  isPlaying ? 'Tocando agora' : 'Pausado',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colors.primary.withValues(
                                      alpha: 0.7,
                                    ),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            song.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            song.artist,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurface.withValues(alpha: 0.5),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (analysis != null &&
                              analysis!.fullLabel.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              analysis!.fullLabel,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colors.tertiary.withValues(alpha: 0.6),
                                fontWeight: FontWeight.w500,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // Play/Pause button
                    GestureDetector(
                      onTap: onPlayPause,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: colors.primary.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: colors.onPrimary,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Progress bar
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(AppSpacing.radiusLg),
                  bottomRight: Radius.circular(AppSpacing.radiusLg),
                ),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: colors.onSurface.withValues(alpha: 0.06),
                  valueColor: AlwaysStoppedAnimation(
                    colors.primary.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// PREMIUM SONG CARD — with BPM/Key badge
// ============================================================

class _PremiumSongCard extends StatelessWidget {
  const _PremiumSongCard({
    required this.song,
    required this.isPlaying,
    required this.size,
    required this.analysis,
    required this.colors,
    required this.theme,
    required this.onTap,
  });
  final Song song;
  final bool isPlaying;
  final double size;
  final AudioAnalysisResult? analysis;
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
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    boxShadow: [
                      BoxShadow(
                        color: isPlaying
                            ? colors.primary.withValues(alpha: 0.15)
                            : Colors.black.withValues(alpha: 0.1),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ArtworkImage.song(
                    songId: song.numericId,
                    size: size,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
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
                // BPM badge
                if (analysis != null && analysis!.hasBpm)
                  Positioned(
                    left: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${analysis!.bpm} BPM',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                          fontSize: 9,
                        ),
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    song.artist,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.4),
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (analysis != null && analysis!.hasKey) ...[
                  const SizedBox(width: 4),
                  Text(
                    '${analysis!.key}${analysis!.scale == "Minor" ? "m" : ""}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.tertiary.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w600,
                      fontSize: 9,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// LIBRARY STATS BAR — compact summary
// ============================================================

class _LibraryStatsBar extends StatelessWidget {
  const _LibraryStatsBar({
    required this.songCount,
    required this.albumCount,
    required this.artistCount,
    required this.durationLabel,
    required this.colors,
    required this.theme,
  });
  final int songCount;
  final int albumCount;
  final int artistCount;
  final String durationLabel;
  final ColorScheme colors;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: colors.onSurface.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: colors.outline.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(
              value: '$songCount',
              label: 'Músicas',
              colors: colors,
              theme: theme,
            ),
            Container(
              width: 1,
              height: 24,
              color: colors.outline.withValues(alpha: 0.1),
            ),
            _StatItem(
              value: '$albumCount',
              label: 'Álbuns',
              colors: colors,
              theme: theme,
            ),
            Container(
              width: 1,
              height: 24,
              color: colors.outline.withValues(alpha: 0.1),
            ),
            _StatItem(
              value: '$artistCount',
              label: 'Artistas',
              colors: colors,
              theme: theme,
            ),
            Container(
              width: 1,
              height: 24,
              color: colors.outline.withValues(alpha: 0.1),
            ),
            _StatItem(
              value: durationLabel,
              label: 'Duração',
              colors: colors,
              theme: theme,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.value,
    required this.label,
    required this.colors,
    required this.theme,
  });
  final String value;
  final String label;
  final ColorScheme colors;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.onSurface.withValues(alpha: 0.35),
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// PULSING DOT — animated indicator
// ============================================================

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});
  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: _ctrl,
      builder: (context, value, child) {
        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: 0.5 + 0.5 * value),
          ),
        );
      },
    );
  }
}

// ============================================================
// STANDARD SONG CARD (unchanged from original)
// ============================================================

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
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
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
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    placeholderIcon: Icons.music_note_rounded,
                    placeholderIconSize: size * 0.33,
                  ),
                ),
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

// ============================================================
// QUICK CHIP
// ============================================================

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
          border: Border.all(color: colors.outline.withValues(alpha: 0.1)),
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

// ============================================================
// SECTION HEADER — with icon and staggered animation
// ============================================================

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.colors,
    required this.theme,
    this.onSeeAll,
    this.sectionIndex = 0,
    this.icon,
  });
  final String title;
  final ColorScheme colors;
  final ThemeData theme;
  final VoidCallback? onSeeAll;
  final int sectionIndex;
  final IconData? icon;

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
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: colors.primary.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w500,
                  ),
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
        )
        .animate(delay: Duration(milliseconds: 60 * sectionIndex))
        .fadeIn(duration: 350.ms, curve: Curves.easeOut)
        .slideY(begin: 0.04, end: 0, duration: 350.ms, curve: Curves.easeOut);
  }
}
