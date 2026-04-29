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
import 'package:constanza_player/presentation/widgets/artwork_image.dart';
import 'package:constanza_player/presentation/widgets/profile_header.dart';
import 'package:constanza_player/presentation/widgets/artist_image.dart';
import 'package:constanza_player/services/audio_analysis_service.dart';
import 'package:constanza_player/presentation/pages/now_playing/now_playing_page.dart';
import 'package:constanza_player/l10n/gen/app_localizations.dart';
import 'package:go_router/go_router.dart';

// ── Part files ──
part 'parts/now_playing_hero.dart';
part 'parts/premium_song_card.dart';
part 'parts/stats_bar.dart';
part 'parts/song_card.dart';
part 'parts/minor_widgets.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  String _moodSuggestion(AppLocalizations l10n) {
    final h = DateTime.now().hour;
    if (h < 6) return l10n.homeMoodLateNight;
    if (h < 10) return l10n.homeMoodMorning;
    if (h < 14) return l10n.homeMoodMidday;
    if (h < 18) return l10n.homeMoodAfternoon;
    if (h < 22) return l10n.homeMoodEvening;
    return l10n.homeMoodNight;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
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
        l10n,
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
    AppLocalizations l10n,
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
              l10n.libraryLoading,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      );
    }

    if (libraryState.status == LibraryStatus.noPermission) {
      return SingleChildScrollView(
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
              l10n.permissionMissing,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.permissionMissingDesc,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.35),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.tonal(
              onPressed: () =>
                  ref.read(libraryProvider.notifier).retryPermission(),
              child: Text(l10n.permissionAllow),
            ),
          ],
        ),
      );
    }

    if (libraryState.status == LibraryStatus.needsFolderSetup) {
      return SingleChildScrollView(
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
              l10n.libraryNeedsFolderSetup,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.libraryNeedsFolderSetupDesc,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.35),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.tonal(
              onPressed: () => context.push('/folders'),
              child: Text(l10n.libraryFolderPicker),
            ),
          ],
        ),
      );
    }

    if (libraryState.status == LibraryStatus.empty ||
        (!libraryState.isLoading && songs.isEmpty)) {
      return SingleChildScrollView(
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
              l10n.libraryEmpty,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.libraryEmptyDesc,
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

    // Mood-based quick picks (time-aware suggestion)
    final moodPicks = _getMoodPicks(songs, recentSongs, favSongs);

    int sectionIdx = 0;

    return CustomScrollView(
      slivers: [
        // ─── HEADER ───────────────────────────────────────────
        SliverAppBar(
          pinned: false,
          floating: true,
          snap: true,
          toolbarHeight: 76,
          backgroundColor: BackgroundHelper.appBarColor(colors, themeState),
          elevation: 0,
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          title: const ProfileHeader(),
        ),

        // ─── NOW PLAYING HERO CARD ───────────────────────────
        if (currentSong != null)
          SliverToBoxAdapter(
            child:
                _NowPlayingHero(
                      song: currentSong,
                      isPlaying: playerState.isPlaying,
                      progress: playerState.progress,
                      colors: colors,
                      theme: theme,
                      onTap: () => _openNowPlaying(context),
                      onPlayPause: () =>
                          ref.read(playerProvider.notifier).togglePlayPause(),
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
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.primary.withValues(alpha: 0.22),
                      colors.tertiary.withValues(alpha: 0.12),
                      colors.primary.withValues(alpha: 0.06),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [colors.primary, colors.tertiary],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colors.primary.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.shuffle_rounded,
                        color: colors.onPrimary,
                        size: 22,
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
              title: _moodSuggestion(l10n),
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
              onSeeAll: () => context.push('/albums'),
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
              onSeeAll: () => context.push('/artists'),
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
// NOW PLAYING HERO CARD
// ============================================================
