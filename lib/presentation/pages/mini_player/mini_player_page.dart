import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';

import 'package:constanza_player/presentation/providers/player_provider.dart';
import 'package:constanza_player/presentation/widgets/artwork_image.dart';
import 'package:constanza_player/services/window_mode_service.dart';

/// Mini-leitor estilo Windows Media Player 10.
///
/// Layout intencionalmente minimalista:
/// - Capa em tela cheia (com blur por trás dela mesma para preencher a janela
///   sem barras pretas quando a capa não é quadrada).
/// - Controles flutuantes na base (prev / play-pause / next + favorite + pip).
/// - Qualquer área que NÃO seja um controle funciona como drag region —
///   o usuário arrasta a janela clicando em qualquer parte da capa.
class MiniPlayerPage extends ConsumerWidget {
  const MiniPlayerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final song = player.currentSong;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Fundo: capa com blur preenchendo a janela inteira ────
          if (song != null)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Transform.scale(
                  scale: 1.4,
                  child: ArtworkImage.song(songId: song.numericId, size: 600),
                ),
              ),
            ),
          // ── 2. Capa nítida no centro ─────────────────────────────────
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 88),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: song != null
                        ? ArtworkImage.song(songId: song.numericId, size: 300)
                        : Container(
                            color: Colors.white.withValues(alpha: 0.05),
                            child: const Icon(
                              Icons.music_note_rounded,
                              size: 64,
                              color: Colors.white24,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
          // ── 3. Drag region em toda a área (atrás dos controles) ─────
          //    Não bloqueia toques nos controles porque o Stack desenha
          //    os controles por cima e eles consomem o evento primeiro.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) => windowManager.startDragging(),
              onDoubleTap: () async {
                // Duplo-clique restaura modo cheio (atalho clássico WMP).
                await WindowModeService.exitMini();
                if (context.mounted) context.go('/home');
              },
            ),
          ),
          // ── 4. Controles flutuantes na base ─────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: Center(
              child: _ControlsBar(
                isPlaying: player.isPlaying,
                isFavorite: song?.isFavorite ?? false,
                hasSong: song != null,
                onPrev: () => ref.read(playerProvider.notifier).previous(),
                onPlayPause: () =>
                    ref.read(playerProvider.notifier).togglePlayPause(),
                onNext: () => ref.read(playerProvider.notifier).next(),
                onFavorite: song == null
                    ? null
                    : () => ref.read(playerProvider.notifier).toggleFavorite(),
                onExitMini: () async {
                  await WindowModeService.exitMini();
                  if (context.mounted) context.go('/home');
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlsBar extends StatelessWidget {
  const _ControlsBar({
    required this.isPlaying,
    required this.isFavorite,
    required this.hasSong,
    required this.onPrev,
    required this.onPlayPause,
    required this.onNext,
    required this.onExitMini,
    this.onFavorite,
  });

  final bool isPlaying;
  final bool isFavorite;
  final bool hasSong;
  final VoidCallback onPrev;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onExitMini;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MiniIconButton(
                icon: isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: isFavorite ? const Color(0xFFFF4D6D) : Colors.white,
                onTap: onFavorite,
              ),
              _MiniIconButton(
                icon: Icons.skip_previous_rounded,
                color: Colors.white,
                onTap: hasSong ? onPrev : null,
              ),
              _PlayButton(playing: isPlaying, onTap: onPlayPause),
              _MiniIconButton(
                icon: Icons.skip_next_rounded,
                color: Colors.white,
                onTap: hasSong ? onNext : null,
              ),
              _MiniIconButton(
                icon: Icons.picture_in_picture_alt_rounded,
                color: Colors.white,
                onTap: onExitMini,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  const _MiniIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: color, size: 20),
      splashRadius: 20,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.playing, required this.onTap});

  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.black,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
