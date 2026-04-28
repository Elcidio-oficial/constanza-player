import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:constanza_player/core/theme/app_spacing.dart';
import 'package:constanza_player/presentation/providers/player_provider.dart';
import 'package:constanza_player/presentation/providers/artwork_provider.dart';
import 'package:constanza_player/presentation/pages/now_playing/now_playing_page.dart';
import 'package:constanza_player/presentation/widgets/artwork_image.dart';

/// Card moderno de reprodução atual — usa palette da artwork para gradiente.
/// Pode ser incorporado em qualquer página com [NowPlayingCard()].
class NowPlayingCard extends ConsumerWidget {
  const NowPlayingCard({super.key, this.margin});

  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSong = ref.watch(playerProvider.select((s) => s.hasSong));
    if (!hasSong) return const SizedBox.shrink();

    final song = ref.watch(playerProvider.select((s) => s.currentSong));
    final palette = ref.watch(artworkPaletteProvider);
    final colors = Theme.of(context).colorScheme;

    final c1 = palette?.dominant ?? colors.primary;
    final c2 = palette?.secondary ?? palette?.muted ?? c1.withValues(alpha: 0.6);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const NowPlayingPage(),
            transitionsBuilder: (_, anim, __, child) => SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
              child: child,
            ),
            transitionDuration: const Duration(milliseconds: 340),
          ),
        );
      },
      child: Container(
        margin: margin ?? const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              c1.withValues(alpha: 0.88),
              c2.withValues(alpha: 0.72),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: c1.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  // Artwork com Hero para transição suave
                  Hero(
                    tag: 'nowplaying_card_art',
                    child: ArtworkImage.song(
                      songId: song?.numericId ?? 0,
                      size: 58,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // Info
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song?.title ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          song?.artist ?? '',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        // Barra de progresso inline
                        _CardProgressBar(accentColor: Colors.white),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  // Controles
                  _CardControl(
                    icon: Icons.skip_previous_rounded,
                    onTap: () => ref.read(playerProvider.notifier).previous(),
                  ),
                  const SizedBox(width: 2),
                  _CardPlayPause(),
                  const SizedBox(width: 2),
                  _CardControl(
                    icon: Icons.skip_next_rounded,
                    onTap: () => ref.read(playerProvider.notifier).next(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 350.ms, curve: Curves.easeOut)
        .slideY(begin: 0.08, end: 0, duration: 350.ms, curve: Curves.easeOut);
  }
}

class _CardProgressBar extends ConsumerWidget {
  const _CardProgressBar({required this.accentColor});
  final Color accentColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref
        .watch(playerProvider.select((s) => s.progress))
        .clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 2.5,
        child: LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.white.withValues(alpha: 0.2),
          valueColor: AlwaysStoppedAnimation<Color>(
            accentColor.withValues(alpha: 0.9),
          ),
        ),
      ),
    );
  }
}

class _CardPlayPause extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying = ref.watch(playerProvider.select((s) => s.isPlaying));
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(playerProvider.notifier).togglePlayPause();
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}

class _CardControl extends StatelessWidget {
  const _CardControl({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 22),
      ),
    );
  }
}
