part of '../car_mode_page.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ──────────────────────────────────────────────────────────────────────────────

class _TopBar extends ConsumerWidget {
  const _TopBar({
    required this.l10n,
    required this.dimmed,
    required this.currentView,
    required this.onDim,
    required this.onQueue,
  });

  final AppLocalizations l10n;
  final bool dimmed;
  final CarModeView currentView;
  final VoidCallback onDim;
  final VoidCallback onQueue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLyrics = currentView == CarModeView.lyrics;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          _GlassButton(
            icon: Icons.arrow_back_ios_new_rounded,
            size: 44,
            iconSize: 20,
            onTap: () => Navigator.of(context).pop(),
            tooltip: l10n.carModeExit,
          ),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.directions_car_rounded,
                color: Colors.white.withValues(alpha: 0.35),
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                (isLyrics ? l10n.carModeViewLyrics : l10n.carModeTitle)
                    .toUpperCase(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.4,
                ),
              ),
            ],
          ),
          const Spacer(),
          _GlassButton(
            icon: isLyrics ? Icons.music_note_rounded : Icons.lyrics_rounded,
            size: 44,
            iconSize: 20,
            active: isLyrics,
            onTap: () => ref
                .read(themeProvider.notifier)
                .setCarModeView(
                  isLyrics ? CarModeView.player : CarModeView.lyrics,
                ),
            tooltip: l10n.carModeSwitchView,
          ),
          const SizedBox(width: 6),
          _GlassButton(
            icon: dimmed
                ? Icons.brightness_high_rounded
                : Icons.brightness_3_rounded,
            size: 44,
            iconSize: 20,
            onTap: onDim,
            tooltip: l10n.carModeDim,
          ),
          const SizedBox(width: 6),
          _GlassButton(
            icon: Icons.queue_music_rounded,
            size: 44,
            iconSize: 20,
            onTap: onQueue,
            tooltip: l10n.carModeQueue,
          ),
        ],
      ),
    );
  }
}

class _SafetyBanner extends StatelessWidget {
  const _SafetyBanner({required this.ctrl, required this.l10n});

  final AnimationController ctrl;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: ctrl, curve: Curves.easeOut),
      child: FadeTransition(
        opacity: ctrl,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.remove_red_eye_outlined,
                color: Colors.white.withValues(alpha: 0.5),
                size: 14,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.carModeSafetyNotice,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtworkCard extends StatelessWidget {
  const _ArtworkCard({required this.songId, required this.size});

  final int songId;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 40,
            spreadRadius: 4,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: ArtworkImage.song(
          songId: songId,
          size: size,
          placeholderIcon: Icons.music_note_rounded,
          placeholderIconSize: size * 0.3,
        ),
      ),
    );
  }
}

class _SongInfo extends StatelessWidget {
  const _SongInfo({required this.song, required this.accent});

  final Song? song;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        children: [
          Text(
            song?.title ?? '',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 5),
          Text(
            [
              if ((song?.artist ?? '').isNotEmpty) song!.artist,
              if ((song?.album ?? '').isNotEmpty) song!.album,
            ].join(' · '),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ProgressSection extends ConsumerWidget {
  const _ProgressSection({required this.player, required this.accent});

  final PlayerState player;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(themeProvider.select((s) => s.mediaBarStyle));
    final waveform = ref
        .watch(waveformProvider(player.currentSong?.uri ?? ''))
        .value;
    // Car Mode lives on a dark backdrop — derive lively gradient stops from the
    // accent so visualizer styles read well without a full palette.
    final hsl = HSLColor.fromColor(accent);
    final secondary = hsl
        .withHue((hsl.hue + 18) % 360)
        .withLightness((hsl.lightness + 0.12).clamp(0.0, 1.0))
        .toColor();
    final tertiary = hsl
        .withHue((hsl.hue + 36) % 360)
        .withLightness((hsl.lightness + 0.20).clamp(0.0, 1.0))
        .toColor();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          MediaSeekBar(
            progress: player.progress.clamp(0.0, 1.0),
            style: style,
            seed: player.currentSong?.id.hashCode ?? 0,
            waveform: waveform,
            position: player.position,
            animate: player.isPlaying,
            activeColor: accent,
            inactiveColor: Colors.white.withValues(alpha: 0.15),
            neutralColor: Colors.white,
            secondaryColor: secondary,
            tertiaryColor: tertiary,
            onSeek: (v) {
              final ms = (v * player.duration.inMilliseconds).round();
              ref
                  .read(playerProvider.notifier)
                  .seek(Duration(milliseconds: ms));
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  player.positionFormatted,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  player.durationFormatted,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                    fontFeatures: const [FontFeature.tabularFigures()],
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

class _MainControls extends ConsumerWidget {
  const _MainControls({
    required this.player,
    required this.accent,
    this.compact = false,
  });

  final PlayerState player;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(playerProvider.notifier);
    final btnSize = compact ? 60.0 : 68.0;
    final playSize = compact ? 80.0 : 90.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CarBtn(
          icon: Icons.skip_previous_rounded,
          size: btnSize,
          iconSize: compact ? 32 : 36,
          color: Colors.white.withValues(
            alpha: player.hasPrevious ? 0.85 : 0.3,
          ),
          onTap: player.hasPrevious ? () => notifier.previous() : null,
        ),
        const SizedBox(width: 16),
        _CarBtn(
          icon: player.isLoading
              ? Icons.hourglass_top_rounded
              : player.isPlaying
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          size: playSize,
          iconSize: compact ? 42 : 48,
          color: Colors.white,
          bgColor: accent,
          shadow: true,
          onTap: () => notifier.togglePlayPause(),
        ),
        const SizedBox(width: 16),
        _CarBtn(
          icon: Icons.skip_next_rounded,
          size: btnSize,
          iconSize: compact ? 32 : 36,
          color: Colors.white.withValues(alpha: player.hasNext ? 0.85 : 0.3),
          onTap: player.hasNext ? () => notifier.next() : null,
        ),
      ],
    );
  }
}

class _SecondaryControls extends ConsumerWidget {
  const _SecondaryControls({required this.player, required this.accent});

  final PlayerState player;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(playerProvider.notifier);
    final isFav = player.currentSong?.isFavorite ?? false;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _GlassButton(
          icon: player.shuffleEnabled
              ? Icons.shuffle_on_rounded
              : Icons.shuffle_rounded,
          size: 52,
          iconSize: 24,
          active: player.shuffleEnabled,
          activeColor: accent,
          onTap: () => notifier.toggleShuffle(),
        ),
        const SizedBox(width: 20),
        _GlassButton(
          icon: isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          size: 52,
          iconSize: 24,
          active: isFav,
          activeColor: const Color(0xFFFF5C6E),
          onTap: () => notifier.toggleFavorite(),
        ),
        const SizedBox(width: 20),
        _GlassButton(
          icon: player.repeatMode == RepeatMode.one
              ? Icons.repeat_one_rounded
              : Icons.repeat_rounded,
          size: 52,
          iconSize: 24,
          active: player.repeatMode != RepeatMode.off,
          activeColor: accent,
          onTap: () => notifier.cycleRepeatMode(),
        ),
      ],
    );
  }
}

class _VolumeRow extends StatelessWidget {
  const _VolumeRow({
    required this.volume,
    required this.accent,
    required this.onVolume,
    required this.l10n,
  });

  final double volume;
  final Color accent;
  final void Function(double) onVolume;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final pct = (volume * 100).round();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          _GlassButton(
            icon: Icons.volume_down_rounded,
            size: 48,
            iconSize: 22,
            onTap: () => onVolume(-0.1),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  Container(
                    height: 6,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                  FractionallySizedBox(
                    widthFactor: volume,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          _GlassButton(
            icon: Icons.volume_up_rounded,
            size: 48,
            iconSize: 22,
            onTap: () => onVolume(0.1),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            child: Text(
              '$pct%',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 12,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
