// ignore_for_file: deprecated_member_use, unused_local_variable, curly_braces_in_flow_control_structures, unused_element_parameter
part of '../now_playing_page.dart';

class _LandscapeLayout extends StatelessWidget {
  const _LandscapeLayout({
    required this.mq,
    required this.theme,
    required this.colors,
    required this.accentColor,
    required this.artColor,
    required this.song,
    required this.npStyle,
    required this.titleBlock,
  });

  final MediaQueryData mq;
  final ThemeData theme;
  final ColorScheme colors;
  final Color accentColor;
  final Color? artColor;
  final Song song;
  final NowPlayingStyle npStyle;
  final Widget titleBlock;

  @override
  Widget build(BuildContext context) {
    // Em landscape, o width vira o eixo dominante. A altura disponível é
    // o limitante do artwork — uso height pra dimensionar o carousel.
    return Padding(
      padding: EdgeInsets.only(
        top: mq.padding.top,
        bottom: mq.padding.bottom,
        left: mq.padding.left,
        right: mq.padding.right,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Lado esquerdo: artwork ──
          Expanded(
            flex: 5,
            child: Center(
              child: _LandscapeArtworkCarousel(
                npStyle: npStyle,
                colors: colors,
                artColor: artColor,
              ),
            ),
          ),
          // ── Lado direito: header + info + controles ──
          Expanded(
            flex: 6,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Header(colors: colors, song: song),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        titleBlock,
                        const SizedBox(height: AppSpacing.md),
                        _ProgressBar(
                          theme: theme,
                          colors: colors,
                          accentColor: accentColor,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _MainControls(colors: colors, accentColor: accentColor),
                        const SizedBox(height: AppSpacing.md),
                        _SecondaryActions(
                          colors: colors,
                          theme: theme,
                          accentColor: accentColor,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        _UpNextPreview(colors: colors, theme: theme),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Carousel variant para landscape — dimensiona pelo height
class _LandscapeArtworkCarousel extends ConsumerWidget {
  const _LandscapeArtworkCarousel({
    required this.npStyle,
    required this.colors,
    required this.artColor,
  });

  final NowPlayingStyle npStyle;
  final ColorScheme colors;
  final Color? artColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Em landscape, o artwork cabe no menor dos dois: altura disponível
    // ou metade da largura. O _ArtworkCarousel interno já usa width do
    // MediaQuery; envolver em SizedBox quadrado mantém proporção.
    final mq = MediaQuery.of(context);
    final targetSize = (mq.size.height * 0.78).clamp(0.0, mq.size.width * 0.48);
    return SizedBox(
      width: targetSize,
      height: targetSize,
      child: MediaQuery(
        // Força o _ArtworkCarousel a usar largura = targetSize (e não screen width)
        data: mq.copyWith(size: Size(targetSize, targetSize)),
        child: _ArtworkCarousel(
          npStyle: npStyle,
          colors: colors,
          artColor: artColor,
        ),
      ),
    );
  }
}

// ============================================================
// HEADER — minimal com indicadores
// ============================================================

class _Header extends ConsumerWidget {
  const _Header({required this.colors, required this.song});
  final ColorScheme colors;
  final Song song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 32,
              color: colors.onSurface.withValues(alpha: 0.9),
            ),
            onPressed: () => dismissNowPlaying(context),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'TOCANDO AGORA',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.fadedText(0.45),
                    letterSpacing: 2.5,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                // Status indicators row
                Consumer(
                  builder: (_, ref, __) {
                    final audioState = ref.watch(audioSettingsProvider);
                    final speed = audioState.playbackSpeed;
                    final hasTimer = audioState.hasSleepTimer;
                    final hasSpeed = (speed - 1.0).abs() > 0.01;
                    if (!hasTimer && !hasSpeed) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasTimer) ...[
                            Consumer(
                              builder: (_, cRef, __) {
                                final artColor = cRef.watch(
                                  artworkColorProvider,
                                );
                                return _SleepTimerCircle(
                                  endTime: audioState.sleepTimerEndTime,
                                  totalMinutes: audioState.sleepTimerMinutes,
                                  color: artColor ?? colors.primary,
                                );
                              },
                            ),
                            const SizedBox(width: 4),
                            Text(
                              audioState.sleepTimerLabel,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colors.fadedText(0.35),
                                fontSize: 9,
                              ),
                            ),
                          ],
                          if (hasTimer && hasSpeed) const SizedBox(width: 8),
                          if (hasSpeed)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: colors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusXs,
                                ),
                              ),
                              child: Text(
                                audioState.speedLabel,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colors.primary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.more_vert_rounded, color: colors.fadedText(0.6)),
            onPressed: () => _showSongMenu(context, ref),
          ),
        ],
      ),
    );
  }

  void _showSongMenu(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final playerState = ref.read(playerProvider);
    final currentSong = playerState.currentSong;
    if (currentSong == null) return;

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
                // Song header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      ArtworkImage.song(
                        songId: currentSong.numericId,
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
                              currentSong.title,
                              style: theme.textTheme.titleSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              currentSong.artist,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.fadedText(0.5),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Divider(color: colors.outline.withValues(alpha: 0.15)),
                // Actions
                // ── Favoritos ──
                StatefulBuilder(
                  builder: (_, setState) {
                    final isFav =
                        ref.read(playerProvider).currentSong?.isFavorite ??
                        false;
                    return ListTile(
                      leading: Icon(
                        isFav
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: isFav
                            ? colors.error
                            : colors.onSurface.withValues(alpha: 0.7),
                      ),
                      title: Text(
                        isFav
                            ? AppLocalizations.of(context).npRemoveFavorite
                            : AppLocalizations.of(context).npAddFavorite,
                        style: theme.textTheme.bodyMedium,
                      ),
                      onTap: () {
                        ref.read(playerProvider.notifier).toggleFavorite();
                        final updatedSongs = ref.read(libraryProvider).songs;
                        ref
                            .read(playlistProvider.notifier)
                            .syncFavorites(updatedSongs);
                        setState(() {});
                      },
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.playlist_play_rounded,
                    color: colors.onSurface.withValues(alpha: 0.7),
                  ),
                  title: Text(
                    AppLocalizations.of(context).commonPlayNext,
                    style: theme.textTheme.bodyMedium,
                  ),
                  onTap: () {
                    ctx.pop();
                    ref
                        .read(playerProvider.notifier)
                        .addNextInQueue(currentSong);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.of(context).npAddedToQueue,
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.playlist_add_rounded,
                    color: colors.onSurface.withValues(alpha: 0.7),
                  ),
                  title: Text(
                    AppLocalizations.of(context).npAddToPlaylist,
                    style: theme.textTheme.bodyMedium,
                  ),
                  onTap: () {
                    ctx.pop();
                    _showAddToPlaylistDialog(context, ref, currentSong);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.person_outline_rounded,
                    color: colors.onSurface.withValues(alpha: 0.7),
                  ),
                  title: Text(
                    AppLocalizations.of(context).npGoToArtist,
                    style: theme.textTheme.bodyMedium,
                  ),
                  onTap: () {
                    ctx.pop();
                    final allArtists = ref.read(libraryProvider).artists;
                    final names = ArtistLinksText.splitArtists(
                      currentSong.artist,
                    );
                    final found = names
                        .map(
                          (n) => allArtists
                              .where(
                                (a) => a.name.toLowerCase() == n.toLowerCase(),
                              )
                              .firstOrNull,
                        )
                        .nonNulls
                        .toList();
                    if (found.length == 1) {
                      Navigator.of(context).push(
                        AppPageRoute(
                          page: ArtistDetailPage(artist: found.first),
                        ),
                      );
                    } else if (found.length > 1) {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: colors.surfaceContainer,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(AppSpacing.radiusXl),
                          ),
                        ),
                        builder: (innerCtx) => SafeArea(
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
                                child: Text(
                                  AppLocalizations.of(context).npChooseArtist,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: colors.onSurface.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                ),
                              ),
                              Divider(
                                color: colors.outline.withValues(alpha: 0.15),
                              ),
                              for (final a in found)
                                ListTile(
                                  leading: const Icon(
                                    Icons.person_outline_rounded,
                                  ),
                                  title: Text(a.name),
                                  onTap: () {
                                    Navigator.pop(innerCtx);
                                    Navigator.of(context).push(
                                      AppPageRoute(
                                        page: ArtistDetailPage(artist: a),
                                      ),
                                    );
                                  },
                                ),
                              const SizedBox(height: AppSpacing.md),
                            ],
                          ),
                        ),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.album_outlined,
                    color: colors.onSurface.withValues(alpha: 0.7),
                  ),
                  title: Text(
                    AppLocalizations.of(context).npGoToAlbum,
                    style: theme.textTheme.bodyMedium,
                  ),
                  onTap: () {
                    ctx.pop();
                    final albums = ref.read(libraryProvider).albums;
                    final album = albums
                        .where(
                          (a) =>
                              a.name.toLowerCase() ==
                              currentSong.album.toLowerCase(),
                        )
                        .firstOrNull;
                    if (album != null) {
                      Navigator.of(
                        context,
                      ).push(AppPageRoute(page: AlbumDetailPage(album: album)));
                    }
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.share_outlined,
                    color: colors.onSurface.withValues(alpha: 0.7),
                  ),
                  title: Text(
                    AppLocalizations.of(context).commonShare,
                    style: theme.textTheme.bodyMedium,
                  ),
                  onTap: () {
                    ctx.pop();
                    ShareService.shareSongs(
                      context: context,
                      songs: [currentSong],
                      palette: ref.read(artworkPaletteProvider),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.edit_rounded,
                    color: colors.onSurface.withValues(alpha: 0.7),
                  ),
                  title: Text(
                    AppLocalizations.of(context).npEditDetails,
                    style: theme.textTheme.bodyMedium,
                  ),
                  onTap: () {
                    ctx.pop();
                    Navigator.push(
                      context,
                      AppPageRoute(page: SongEditPage(song: currentSong)),
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
    Song song,
  ) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final userPlaylists = ref.read(userPlaylistsProvider);

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
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    AppLocalizations.of(context).npAddToPlaylist,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (userPlaylists.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      AppLocalizations.of(context).npNoPlaylistsCreated,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.fadedText(0.4),
                      ),
                    ),
                  )
                else
                  ...userPlaylists.map(
                    (p) => ListTile(
                      leading: Icon(
                        Icons.queue_music_rounded,
                        color: colors.fadedText(0.5),
                      ),
                      title: Text(p.name),
                      subtitle: Text(
                        '${p.songCount} músicas',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.fadedText(0.4),
                        ),
                      ),
                      onTap: () {
                        ref
                            .read(playlistProvider.notifier)
                            .addSongToPlaylist(p.id, song);
                        ctx.pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              AppLocalizations.of(
                                context,
                              ).npAddedToPlaylistShort(p.name),
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
// ARTWORK CAROUSEL — ViewPager2-style with PageTransformer
// ============================================================
