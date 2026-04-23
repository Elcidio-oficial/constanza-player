import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:constanza_player/presentation/providers/player_provider.dart';
import 'package:constanza_player/presentation/providers/artwork_provider.dart';
import 'package:constanza_player/presentation/widgets/artwork_image.dart';
import 'package:go_router/go_router.dart';

/// Modo Carro — interface simplificada com botões extra grandes.
///
/// Otimizado para uso com uma mão enquanto conduz:
/// - Botões gigantes (min 72px touch target)
/// - Texto grande e legível
/// - Sem elementos secundários
/// - Fundo escuro para não distrair
class CarModePage extends ConsumerWidget {
  const CarModePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final artColor = ref.watch(artworkColorProvider);
    final song = player.currentSong;
    final accent = artColor ?? const Color(0xFF6750A4);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: isLandscape
            ? _buildLandscape(context, ref, player, song, accent)
            : _buildPortrait(context, ref, player, song, accent),
      ),
    );
  }

  Widget _buildLandscape(
    BuildContext context,
    WidgetRef ref,
    PlayerState player,
    dynamic song,
    Color accent,
  ) {
    return Row(
      children: [
        // Left: artwork
        Expanded(
          flex: 4,
          child: Center(
            child: ArtworkImage.song(
              songId: song?.numericId ?? 0,
              size: MediaQuery.sizeOf(context).height * 0.65,
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
        // Right: controls
        Expanded(
          flex: 5,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Song info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Text(
                      song?.title ?? 'Sem música',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      song?.artist ?? '',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Progress
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 6,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8,
                    ),
                    activeTrackColor: accent,
                    inactiveTrackColor: Colors.white12,
                    thumbColor: accent,
                    overlayColor: accent.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: player.progress,
                    onChanged: (v) {
                      final ms = (v * player.duration.inMilliseconds).round();
                      ref
                          .read(playerProvider.notifier)
                          .seek(Duration(milliseconds: ms));
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _CarButton(
                    icon: Icons.skip_previous_rounded,
                    size: 56,
                    iconSize: 32,
                    color: Colors.white70,
                    onTap: () => ref.read(playerProvider.notifier).previous(),
                  ),
                  _CarButton(
                    icon: player.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 72,
                    iconSize: 40,
                    color: Colors.white,
                    bgColor: accent,
                    onTap: () =>
                        ref.read(playerProvider.notifier).togglePlayPause(),
                  ),
                  _CarButton(
                    icon: Icons.skip_next_rounded,
                    size: 56,
                    iconSize: 32,
                    color: Colors.white70,
                    onTap: () => ref.read(playerProvider.notifier).next(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPortrait(
    BuildContext context,
    WidgetRef ref,
    PlayerState player,
    dynamic song,
    Color accent,
  ) {
    return Column(
      children: [
        // Top bar — exit button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white54,
                  size: 28,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.directions_car_rounded,
                color: Colors.white24,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'MODO CARRO',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),

        const Spacer(flex: 1),

        // Artwork — large and centered
        ArtworkImage.song(
          songId: song?.numericId ?? 0,
          size: MediaQuery.sizeOf(context).width * 0.55,
          borderRadius: BorderRadius.circular(24),
        ),

        const SizedBox(height: 32),

        // Song info — large text
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              Text(
                song?.title ?? 'Sem música',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                song?.artist ?? '',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Progress bar — thick and easy to see
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 6,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                  ),
                  activeTrackColor: accent,
                  inactiveTrackColor: Colors.white12,
                  thumbColor: accent,
                  overlayColor: accent.withValues(alpha: 0.2),
                ),
                child: Slider(
                  value: player.progress,
                  onChanged: (v) {
                    final ms = (v * player.duration.inMilliseconds).round();
                    ref
                        .read(playerProvider.notifier)
                        .seek(Duration(milliseconds: ms));
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      player.positionFormatted,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      player.durationFormatted,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const Spacer(flex: 1),

        // Controls — EXTRA LARGE buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Previous
              _CarButton(
                icon: Icons.skip_previous_rounded,
                size: 64,
                iconSize: 36,
                color: Colors.white70,
                onTap: () => ref.read(playerProvider.notifier).previous(),
              ),

              // Play/Pause — biggest
              _CarButton(
                icon: player.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                size: 88,
                iconSize: 48,
                color: Colors.white,
                bgColor: accent,
                onTap: () =>
                    ref.read(playerProvider.notifier).togglePlayPause(),
              ),

              // Next
              _CarButton(
                icon: Icons.skip_next_rounded,
                size: 64,
                iconSize: 36,
                color: Colors.white70,
                onTap: () => ref.read(playerProvider.notifier).next(),
              ),
            ],
          ),
        ),

        const Spacer(flex: 1),

        // Bottom quick actions
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _CarSmallButton(
                icon: Icons.shuffle_rounded,
                active: player.shuffleEnabled,
                accent: accent,
                onTap: () => ref.read(playerProvider.notifier).toggleShuffle(),
              ),
              _CarSmallButton(
                icon: (song?.isFavorite ?? false)
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                active: song?.isFavorite ?? false,
                accent: Colors.redAccent,
                onTap: () => ref.read(playerProvider.notifier).toggleFavorite(),
              ),
              _CarSmallButton(
                icon: player.repeatMode == RepeatMode.one
                    ? Icons.repeat_one_rounded
                    : Icons.repeat_rounded,
                active: player.repeatMode != RepeatMode.off,
                accent: accent,
                onTap: () =>
                    ref.read(playerProvider.notifier).cycleRepeatMode(),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }
}

class _CarButton extends StatelessWidget {
  const _CarButton({
    required this.icon,
    required this.size,
    required this.iconSize,
    required this.color,
    this.bgColor,
    required this.onTap,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final Color color;
  final Color? bgColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bgColor ?? Colors.white.withValues(alpha: 0.08),
        ),
        child: Icon(icon, size: iconSize, color: color),
      ),
    );
  }
}

class _CarSmallButton extends StatelessWidget {
  const _CarSmallButton({
    required this.icon,
    required this.active,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active
              ? accent.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          border: Border.all(
            color: active ? accent.withValues(alpha: 0.4) : Colors.white12,
          ),
        ),
        child: Icon(icon, size: 26, color: active ? accent : Colors.white38),
      ),
    );
  }
}
