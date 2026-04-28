// ignore_for_file: curly_braces_in_flow_control_structures, unused_element_parameter
part of '../playlists_page.dart';

class _PlaylistHeaderBackground extends StatelessWidget {
  const _PlaylistHeaderBackground({
    required this.playlist,
    required this.songs,
    required this.icon,
    required this.accent,
    required this.colors,
  });
  final Playlist playlist;
  final List<Song> songs;
  final IconData icon;
  final Color accent;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // === IMAGEM ou GRADIENTE (full-width) ===
        _buildBackground(),

        // === Gradiente inferior (legibilidade do título) ===
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 140,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors.surface.withValues(alpha: 0.0),
                  colors.surface.withValues(alpha: 0.7),
                  colors.surface,
                ],
              ),
            ),
          ),
        ),

        // === Gradiente superior (legibilidade do botão voltar) ===
        if (_hasImage)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 100,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.black.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

        // === Ícone central (só quando não tem imagem nem músicas) ===
        if (!_hasImage)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 40, bottom: 48),
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  border: Border.all(color: accent.withValues(alpha: 0.15)),
                ),
                child: Icon(
                  icon,
                  size: 64,
                  color: accent.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
      ],
    );
  }

  bool get _hasImage => playlist.hasCustomImage || songs.isNotEmpty;

  Widget _buildBackground() {
    // 1. Custom image — full-width cover
    if (playlist.hasCustomImage) {
      return Image.file(
        File(playlist.imagePath!),
        key: ValueKey(playlist.imagePath),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _gradientFallback(),
      );
    }

    // 2. Mosaico 2x2 full-width (4+ músicas)
    if (songs.length >= 4) {
      return _FullWidthMosaic(songs: songs, colors: colors);
    }

    // 3. First song artwork full-width
    if (songs.isNotEmpty) {
      return ArtworkImage.song(
        songId: songs.first.numericId,
        size: 300,
        borderRadius: BorderRadius.zero,
        placeholderIcon: icon,
        placeholderIconSize: 64,
      );
    }

    // 4. Gradient fallback
    return _gradientFallback();
  }

  Widget _gradientFallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.5, 1.0],
          colors: [
            accent.withValues(alpha: 0.08),
            accent.withValues(alpha: 0.03),
            colors.surface,
          ],
        ),
      ),
    );
  }
}

// ============================================================
// MOSAICO FULL-WIDTH 2x2 para header
// ============================================================

class _FullWidthMosaic extends StatelessWidget {
  const _FullWidthMosaic({required this.songs, required this.colors});
  final List<Song> songs;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final unique = <int, Song>{};
    for (final s in songs) {
      if (unique.length >= 4) break;
      unique.putIfAbsent(s.numericId, () => s);
    }
    final display = unique.values.toList();
    while (display.length < 4) {
      display.add(songs[display.length % songs.length]);
    }

    return GridView.count(
      crossAxisCount: 2,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      mainAxisSpacing: 1,
      crossAxisSpacing: 1,
      children: display
          .take(4)
          .map(
            (s) => ArtworkImage.song(
              songId: s.numericId,
              size: 200,
              borderRadius: BorderRadius.zero,
            ),
          )
          .toList(),
    );
  }
}

// ============================================================
// BOTÃO VOLTAR PREMIUM
// ============================================================

class _BackButton extends StatelessWidget {
  const _BackButton({required this.colors});
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: GestureDetector(
        onTap: () => context.pop(),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.8),
            shape: BoxShape.circle,
            border: Border.all(color: colors.outline.withValues(alpha: 0.1)),
          ),
          child: Icon(
            Icons.arrow_back_rounded,
            color: colors.onSurface,
            size: 20,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// BOTÃO DE AÇÃO PREMIUM
// ============================================================

class _PremiumActionButton extends StatelessWidget {
  const _PremiumActionButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.colors,
    required this.theme,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool filled;
  final ColorScheme colors;
  final ThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: filled
              ? colors.primary
              : colors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: filled
              ? null
              : Border.all(color: colors.primary.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: filled ? colors.onPrimary : colors.primary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: filled ? colors.onPrimary : colors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
