part of '../car_mode_page.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Blurred background artwork
// ──────────────────────────────────────────────────────────────────────────────

class _ArtworkBackground extends StatelessWidget {
  const _ArtworkBackground({required this.songId, required this.fade});

  final int songId;
  final Animation<double> fade;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fade,
      child: ArtworkImage.song(
        songId: songId,
        size: MediaQuery.sizeOf(context).longestSide,
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Portrait Layout
// ──────────────────────────────────────────────────────────────────────────────

class _PortraitLayout extends ConsumerWidget {
  const _PortraitLayout({
    required this.player,
    required this.song,
    required this.accent,
    required this.volume,
    required this.dimmed,
    required this.artworkFade,
    required this.bannerCtrl,
    required this.currentView,
    required this.onDim,
    required this.onVolume,
    required this.onQueue,
  });

  final PlayerState player;
  final Song? song;
  final Color accent;
  final double volume;
  final bool dimmed;
  final Animation<double> artworkFade;
  final AnimationController bannerCtrl;
  final CarModeView currentView;
  final VoidCallback onDim;
  final void Function(double) onVolume;
  final VoidCallback onQueue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final size = MediaQuery.sizeOf(context);

    return Column(
      children: [
        // ── Top bar ──────────────────────────────────────────────
        _TopBar(
          l10n: l10n,
          dimmed: dimmed,
          currentView: currentView,
          onDim: onDim,
          onQueue: onQueue,
        ),

        // ── Safety banner ────────────────────────────────────────
        _SafetyBanner(ctrl: bannerCtrl, l10n: l10n),

        const Spacer(),

        // ── Artwork ──────────────────────────────────────────────
        FadeTransition(
          opacity: artworkFade,
          child: _ArtworkCard(
            songId: song?.numericId ?? 0,
            size: size.width * 0.58,
          ),
        ),

        const SizedBox(height: 24),

        // ── Song info ────────────────────────────────────────────
        _SongInfo(song: song, accent: accent),

        const SizedBox(height: 20),

        // ── Progress ─────────────────────────────────────────────
        _ProgressSection(player: player, accent: accent),

        const Spacer(),

        // ── Main controls ────────────────────────────────────────
        _MainControls(player: player, accent: accent),

        const SizedBox(height: 20),

        // ── Secondary row ────────────────────────────────────────
        _SecondaryControls(player: player, accent: accent),

        const SizedBox(height: 16),

        // ── Volume ───────────────────────────────────────────────
        _VolumeRow(
          volume: volume,
          accent: accent,
          onVolume: onVolume,
          l10n: l10n,
        ),

        const SizedBox(height: 20),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Landscape Layout
// ──────────────────────────────────────────────────────────────────────────────

class _LandscapeLayout extends ConsumerWidget {
  const _LandscapeLayout({
    required this.player,
    required this.song,
    required this.accent,
    required this.volume,
    required this.dimmed,
    required this.artworkFade,
    required this.bannerCtrl,
    required this.currentView,
    required this.onDim,
    required this.onVolume,
    required this.onQueue,
  });

  final PlayerState player;
  final Song? song;
  final Color accent;
  final double volume;
  final bool dimmed;
  final Animation<double> artworkFade;
  final AnimationController bannerCtrl;
  final CarModeView currentView;
  final VoidCallback onDim;
  final void Function(double) onVolume;
  final VoidCallback onQueue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final size = MediaQuery.sizeOf(context);

    return Row(
      children: [
        // ── Left: artwork ─────────────────────────────────────────
        Expanded(
          flex: 4,
          child: Center(
            child: FadeTransition(
              opacity: artworkFade,
              child: _ArtworkCard(
                songId: song?.numericId ?? 0,
                size: size.height * 0.7,
              ),
            ),
          ),
        ),

        // ── Right: controls ───────────────────────────────────────
        Expanded(
          flex: 6,
          child: Column(
            children: [
              _TopBar(
                l10n: l10n,
                dimmed: dimmed,
                currentView: currentView,
                onDim: onDim,
                onQueue: onQueue,
              ),
              _SafetyBanner(ctrl: bannerCtrl, l10n: l10n),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      _SongInfo(song: song, accent: accent),
                      const SizedBox(height: 12),
                      _ProgressSection(player: player, accent: accent),
                      const SizedBox(height: 12),
                      _MainControls(
                        player: player,
                        accent: accent,
                        compact: true,
                      ),
                      const SizedBox(height: 10),
                      _SecondaryControls(player: player, accent: accent),
                      const SizedBox(height: 10),
                      _VolumeRow(
                        volume: volume,
                        accent: accent,
                        onVolume: onVolume,
                        l10n: l10n,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
