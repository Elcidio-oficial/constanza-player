import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:constanza_player/core/constants/app_constants.dart';
import 'package:constanza_player/core/theme/app_spacing.dart';
import 'package:constanza_player/presentation/providers/player_provider.dart';
import 'package:constanza_player/presentation/providers/theme_provider.dart';
import 'package:constanza_player/presentation/providers/artwork_provider.dart';
import 'package:constanza_player/presentation/pages/now_playing/now_playing_page.dart';
import 'package:constanza_player/presentation/widgets/artwork_image.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  static Color _controlColor(
    MiniPlayerStyle style,
    Color? artColor,
    ColorScheme colors,
  ) {
    if (artColor != null &&
        (style == MiniPlayerStyle.artwork ||
            style == MiniPlayerStyle.dynamic)) {
      return Colors.white.withValues(alpha: 0.85);
    }
    if (artColor != null) {
      final hsl = HSLColor.fromColor(artColor);
      return hsl
          .withLightness(0.55)
          .withSaturation((hsl.saturation * 0.8).clamp(0.2, 0.7))
          .toColor();
    }
    return colors.onSurface.withValues(alpha: 0.5);
  }

  static Color _playBtnColor(
    MiniPlayerStyle style,
    Color? artColor,
    ColorScheme colors,
  ) {
    if (artColor != null) {
      final hsl = HSLColor.fromColor(artColor);
      return hsl
          .withLightness(hsl.lightness.clamp(0.40, 0.60))
          .withSaturation((hsl.saturation * 1.2).clamp(0.35, 1.0))
          .toColor();
    }
    return colors.primary;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only rebuild on song change, not position/isPlaying
    final song = ref.watch(playerProvider.select((s) => s.currentSong));
    final hasSong = ref.watch(playerProvider.select((s) => s.hasSong));
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final miniStyle = ref.watch(themeProvider.select((s) => s.miniPlayerStyle));
    final artworkColor = ref.watch(artworkColorProvider);

    // Background by style
    final Color bgColor = switch (miniStyle) {
      MiniPlayerStyle.glass => colors.surfaceContainer.withValues(alpha: 0.75),
      MiniPlayerStyle.artwork =>
        artworkColor?.withValues(alpha: 0.92) ?? colors.surfaceContainer,
      MiniPlayerStyle.dynamic => Colors.black.withValues(alpha: 0.85),
      MiniPlayerStyle.minimal => colors.surface,
      MiniPlayerStyle.card => colors.surfaceContainerHighest,
    };

    final bool isCardStyle = miniStyle == MiniPlayerStyle.card;
    final bool useBlur =
        miniStyle == MiniPlayerStyle.glass ||
        miniStyle == MiniPlayerStyle.dynamic;

    Widget content = AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      height: AppConstants.miniPlayerHeight,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: isCardStyle
            ? const BorderRadius.vertical(
                top: Radius.circular(AppSpacing.radiusLg),
              )
            : null,
        boxShadow: isCardStyle
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ]
            : null,
        border: isCardStyle || miniStyle == MiniPlayerStyle.artwork
            ? null
            : Border(
                top: BorderSide(
                  color: colors.outline.withValues(alpha: 0.08),
                  width: 0.5,
                ),
              ),
      ),
      child: Column(
        children: [
          // Progress — isolated Consumer, only rebuilds on position change
          _MiniProgress(miniStyle: miniStyle, artworkColor: artworkColor),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  Hero(
                    tag: 'artwork_${song?.numericId ?? 0}',
                    child: ArtworkImage.song(
                      songId: song?.numericId ?? 0,
                      size: 44,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song?.title ?? 'Constanza Músicas',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colors.onSurface,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          song?.artist ?? 'Sua música. Seu momento.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurface.withValues(alpha: 0.4),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _MiniControl(
                    icon: Icons.skip_previous_rounded,
                    size: 24,
                    color: _controlColor(miniStyle, artworkColor, colors),
                    onTap: () => ref.read(playerProvider.notifier).previous(),
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  // Play/pause — isolated Consumer, only rebuilds on isPlaying
                  _MiniPlayPause(
                    miniStyle: miniStyle,
                    artworkColor: artworkColor,
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  _MiniControl(
                    icon: Icons.skip_next_rounded,
                    size: 24,
                    color: _controlColor(miniStyle, artworkColor, colors),
                    onTap: () => ref.read(playerProvider.notifier).next(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    // Dynamic tint overlay
    if (miniStyle == MiniPlayerStyle.dynamic && artworkColor != null) {
      content = Stack(
        children: [
          content,
          Positioned.fill(
            child: IgnorePointer(
              child: Container(color: artworkColor.withValues(alpha: 0.55)),
            ),
          ),
        ],
      );
    }

    if (useBlur) {
      content = RepaintBoundary(
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: content,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        if (hasSong) {
          Navigator.of(context).push(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const NowPlayingPage(),
              transitionsBuilder: (_, animation, __, child) {
                return SlideTransition(
                  position:
                      Tween<Offset>(
                        begin: const Offset(0, 1),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                  child: child,
                );
              },
              transitionDuration: AppConstants.normal,
            ),
          );
        }
      },
      child: content,
    );
  }
}

/// Isolated progress bar — only rebuilds on position/duration change (~4x/sec)
class _MiniProgress extends ConsumerWidget {
  const _MiniProgress({required this.miniStyle, required this.artworkColor});
  final MiniPlayerStyle miniStyle;
  final Color? artworkColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref
        .watch(playerProvider.select((s) => s.progress))
        .clamp(0.0, 1.0);
    final colors = Theme.of(context).colorScheme;
    final progressColor =
        (miniStyle == MiniPlayerStyle.dynamic && artworkColor != null)
        ? artworkColor!
        : colors.primary;
    return _ProgressLine(progress: progress, color: progressColor);
  }
}

/// Isolated play/pause button — only rebuilds on isPlaying change
class _MiniPlayPause extends ConsumerWidget {
  const _MiniPlayPause({required this.miniStyle, required this.artworkColor});
  final MiniPlayerStyle miniStyle;
  final Color? artworkColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying = ref.watch(playerProvider.select((s) => s.isPlaying));
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => ref.read(playerProvider.notifier).togglePlayPause(),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: MiniPlayer._playBtnColor(miniStyle, artworkColor, colors),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final trackColor = Theme.of(
      context,
    ).colorScheme.outline.withValues(alpha: 0.06);
    return Container(
      height: 2.5,
      width: double.infinity,
      color: trackColor,
      alignment: Alignment.centerLeft,
      child: AnimatedFractionallySizedBox(
        duration: const Duration(milliseconds: 300),
        curve: Curves.linear,
        widthFactor: progress,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniControl extends StatelessWidget {
  const _MiniControl({
    required this.icon,
    required this.size,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final double size;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Icon(icon, size: size, color: color),
      ),
    );
  }
}
