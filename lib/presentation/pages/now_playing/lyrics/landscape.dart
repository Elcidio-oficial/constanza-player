// ignore_for_file: curly_braces_in_flow_control_structures, unused_element_parameter
part of '../now_playing_page.dart';

class _LyricsLandscapeBody extends ConsumerWidget {
  const _LyricsLandscapeBody({
    required this.song,
    required this.colors,
    required this.theme,
    required this.lyricsContent,
  });

  final Song song;
  final ColorScheme colors;
  final ThemeData theme;
  final Widget lyricsContent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Painel esquerdo: artwork + info + controles mini ──
        Expanded(
          flex: 4,
          child: _LyricsSidePanel(song: song, colors: colors, theme: theme),
        ),
        // Divisor vertical sutil
        Container(
          width: 1,
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          color: Colors.white.withValues(alpha: 0.06),
        ),
        // ── Painel direito: letras ──
        Expanded(flex: 7, child: lyricsContent),
      ],
    );
  }
}

class _LyricsSidePanel extends ConsumerWidget {
  const _LyricsSidePanel({
    required this.song,
    required this.colors,
    required this.theme,
  });

  final Song song;
  final ColorScheme colors;
  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying = ref.watch(playerProvider.select((s) => s.isPlaying));
    final position = ref.watch(playerProvider.select((s) => s.position));
    final duration = ref.watch(playerProvider.select((s) => s.duration));
    final shuffleOn = ref.watch(playerProvider.select((s) => s.shuffleEnabled));
    final palette = ref.watch(artworkPaletteProvider);
    final isFavorite = ref.watch(
      libraryProvider.select(
        (s) => s.songs.any((x) => x.id == song.id && x.isFavorite),
      ),
    );

    final accent = palette?.vibrant ?? colors.primary;
    final durMs = duration.inMilliseconds.clamp(1, 1 << 30);
    final progress = (position.inMilliseconds / durMs).clamp(0.0, 1.0);
    final remaining = duration - position;

    String fmt(Duration d) {
      final m = d.inMinutes;
      final s = d.inSeconds.remainder(60);
      return '$m:${s.toString().padLeft(2, '0')}';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Reserva conservadora p/ título+artista+slider+tempos+transport.
        final isTight = constraints.maxHeight < 420;
        final reservedBelowArt = isTight ? 230.0 : 260.0;
        final maxArtByHeight = (constraints.maxHeight - reservedBelowArt).clamp(
          80.0,
          320.0,
        );
        final maxArtByWidth = constraints.maxWidth * 0.82;
        final artSize = maxArtByHeight < maxArtByWidth
            ? maxArtByHeight
            : maxArtByWidth;

        final gapTitleSlider = isTight ? 8.0 : AppSpacing.md;
        final gapArtTitle = isTight ? 8.0 : AppSpacing.md;
        final gapTransport = isTight ? 4.0 : AppSpacing.sm;
        final outerV = isTight ? 4.0 : AppSpacing.md;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            outerV,
            AppSpacing.md,
            outerV,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Artwork ──
              SizedBox(
                width: artSize,
                height: artSize,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    ),
                    child: ArtworkImage.song(
                      songId: song.numericId,
                      size: artSize,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      placeholderIconSize: 56,
                    ),
                  ),
                ),
              ),
              SizedBox(height: gapArtTitle),
              // ── Título + artista ──
              Text(
                song.title,
                textAlign: TextAlign.center,
                maxLines: isTight ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                song.artist,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
              SizedBox(height: gapTitleSlider),
              // ── Slider ──
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  activeTrackColor: accent,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
                  thumbColor: accent,
                  overlayColor: accent.withValues(alpha: 0.15),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 5,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 12,
                  ),
                ),
                child: Slider(
                  value: progress,
                  onChanged: (v) {
                    if (duration.inMilliseconds > 0) {
                      ref
                          .read(playerProvider.notifier)
                          .seek(
                            Duration(
                              milliseconds: (v * duration.inMilliseconds)
                                  .round(),
                            ),
                          );
                    }
                  },
                ),
              ),
              // ── Tempos ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      fmt(position),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      '-${fmt(remaining.isNegative ? Duration.zero : remaining)}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: gapTransport),
              // ── Transport ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _MiniIconBtn(
                    icon: Icons.shuffle_rounded,
                    color: shuffleOn
                        ? accent
                        : Colors.white.withValues(alpha: 0.75),
                    size: 22,
                    onTap: () =>
                        ref.read(playerProvider.notifier).toggleShuffle(),
                  ),
                  _MiniIconBtn(
                    icon: Icons.skip_previous_rounded,
                    color: Colors.white,
                    size: 30,
                    onTap: () => ref.read(playerProvider.notifier).previous(),
                  ),
                  _MiniPlayButton(
                    isPlaying: isPlaying,
                    accent: accent,
                    onTap: () =>
                        ref.read(playerProvider.notifier).togglePlayPause(),
                  ),
                  _MiniIconBtn(
                    icon: Icons.skip_next_rounded,
                    color: Colors.white,
                    size: 30,
                    onTap: () => ref.read(playerProvider.notifier).next(),
                  ),
                  _MiniIconBtn(
                    icon: isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: isFavorite
                        ? accent
                        : Colors.white.withValues(alpha: 0.75),
                    size: 22,
                    onTap: () =>
                        ref.read(playerProvider.notifier).toggleFavorite(),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================
// QUICK SYNC PAGE — tela dedicada para sincronização rápida
// ============================================================
