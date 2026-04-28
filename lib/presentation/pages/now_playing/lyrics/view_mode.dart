// ignore_for_file: curly_braces_in_flow_control_structures, unused_element_parameter
part of '../now_playing_page.dart';

class _LyricsViewMode extends StatelessWidget {
  const _LyricsViewMode({
    required this.lines,
    required this.currentIndex,
    required this.scroll,
    required this.baseFontSize,
    required this.colors,
    required this.onSeek,
    required this.onUserScrollStart,
    required this.onUserScrollEnd,
    required this.keyFor,
    this.horizontalPadding = AppSpacing.lg,
    this.textAlign = TextAlign.left,
  });
  final List<LyricLine> lines;
  final int currentIndex;
  final ScrollController scroll;
  final double baseFontSize;
  final ColorScheme colors;
  final ValueChanged<Duration?> onSeek;
  final VoidCallback onUserScrollStart;
  final VoidCallback onUserScrollEnd;
  final GlobalKey Function(int idx) keyFor;
  final double horizontalPadding;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    // Padding suficiente para a primeira/última linha alcançarem o centro.
    // LayoutBuilder dá o height real do viewport (portrait ou landscape).
    return LayoutBuilder(
      builder: (context, constraints) {
        final centerPad = constraints.maxHeight / 2;

        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n is UserScrollNotification) {
              if (n.direction != ScrollDirection.idle) {
                onUserScrollStart();
              } else {
                onUserScrollEnd();
              }
            }
            return false;
          },
          // ListView com children explícitos (não-lazy) — garante que todos
          // os GlobalKeys tenham context para o Scrollable.ensureVisible.
          child: ListView(
            controller: scroll,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(
              top: centerPad,
              bottom: centerPad,
              left: horizontalPadding,
              right: horizontalPadding,
            ),
            children: [
              for (int i = 0; i < lines.length; i++)
                _LyricLineItem(
                  key: keyFor(i),
                  line: lines[i],
                  isCurrent: i == currentIndex,
                  distance: currentIndex >= 0 ? (i - currentIndex).abs() : 0,
                  isPast: currentIndex >= 0 && i < currentIndex,
                  hasActive: currentIndex >= 0,
                  baseFontSize: baseFontSize,
                  colors: colors,
                  onSeek: onSeek,
                  textAlign: textAlign,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _LyricLineItem extends StatelessWidget {
  const _LyricLineItem({
    super.key,
    required this.line,
    required this.isCurrent,
    required this.distance,
    required this.isPast,
    required this.hasActive,
    required this.baseFontSize,
    required this.colors,
    required this.onSeek,
    required this.textAlign,
  });

  final LyricLine line;
  final bool isCurrent;
  final int distance;
  final bool isPast;
  final bool hasActive;
  final double baseFontSize;
  final ColorScheme colors;
  final ValueChanged<Duration?> onSeek;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final alpha = isCurrent
        ? 1.0
        : !hasActive
        ? 0.45
        : isPast
        ? (0.35 - distance * 0.05).clamp(0.08, 0.35)
        : (0.45 - distance * 0.06).clamp(0.1, 0.45);

    final fontSize = isCurrent ? baseFontSize * 1.15 : baseFontSize;

    return GestureDetector(
      onTap: line.isSynced ? () => onSeek(line.timestamp) : null,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          style: TextStyle(
            color: colors.onSurface.withValues(alpha: alpha),
            fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
            fontSize: fontSize,
            height: 1.35,
          ),
          textAlign: textAlign,
          child: Text(line.text, textAlign: textAlign),
        ),
      ),
    );
  }
}

// ============================================================
// LYRICS LANDSCAPE BODY — artwork+controles à esquerda, letras à direita
// ============================================================
