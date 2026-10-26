// ignore_for_file: deprecated_member_use, unused_local_variable, curly_braces_in_flow_control_structures, unused_element_parameter
part of '../now_playing_page.dart';

class _ArtworkCarousel extends ConsumerStatefulWidget {
  const _ArtworkCarousel({
    required this.npStyle,
    required this.colors,
    this.artColor,
  });
  final NowPlayingStyle npStyle;
  final ColorScheme colors;
  final Color? artColor;

  @override
  ConsumerState<_ArtworkCarousel> createState() => _ArtworkCarouselState();
}

class _ArtworkCarouselState extends ConsumerState<_ArtworkCarousel> {
  late PageController _pageCtrl;
  int _currentPage = 0;
  // Inicia em true para bloquear onPageChanged espúrios durante o settle inicial
  // do PageView (viewportFraction < 1.0 + initialPage faz o controller assentar
  // ao longo de alguns frames). Sem isto, ao entrar na NP o evento de settle
  // disparava playIndex(...) e reiniciava a faixa do zero — bug visível depois
  // de skips via notificação com tela bloqueada.
  bool _syncing = true;

  // Timestamp do último PointerDown sobre o PageView. Usado como guard
  // definitivo contra onPageChanged espúrios: quando o ecrã do telemóvel
  // acorda do off (ou a Activity é restaurada após skip via notificação), o
  // engine entrega frames de settle pendentes do PageView que disparam
  // onPageChanged sem intervenção do utilizador. Sem este timestamp, esse
  // evento era interpretado como swipe e chamava notifier.next()/previous()
  // ou playIndex(idx) — fazendo a faixa atual reiniciar do zero (sem shuffle)
  // ou saltar para uma aleatória (com shuffle). Só tratamos onPageChanged
  // como swipe real quando ouve PointerDown nos últimos ~800ms.
  int _lastTouchMs = 0;
  static const int _touchWindowMs = 800;

  @override
  void initState() {
    super.initState();
    final idx = ref.read(playerProvider).currentIndex;
    _currentPage = idx < 0 ? 0 : idx;
    _pageCtrl = PageController(
      viewportFraction: 0.82,
      initialPage: _currentPage,
    );
    // Libera onPageChanged depois que o layout assentou.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncing = false;
      });
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    if (_syncing) return;
    // Guard de toque: só tratar como swipe se houve PointerDown recente.
    // Eventos de settle que chegam após resume (tela ligada/notification skip)
    // ou após animateToPage programático não devem mudar a faixa.
    final touchAgeMs = DateTime.now().millisecondsSinceEpoch - _lastTouchMs;
    if (touchAgeMs > _touchWindowMs) {
      _currentPage = index;
      return;
    }
    final player = ref.read(playerProvider);
    final currentIdx = player.currentIndex;

    // Sync externo (notificação/lockscreen/widget) que terminou animateToPage
    // antes do onPageChanged final disparar — sem este guard, o evento atrasado
    // chama playIndex(currentIdx) e reinicia a música atual do zero.
    if (index == currentIdx) {
      _currentPage = index;
      return;
    }

    // Repeat one: swipe não troca de música — volta para a atual.
    if (player.repeatMode == RepeatMode.one && currentIdx >= 0) {
      _syncing = true;
      _pageCtrl
          .animateToPage(
            currentIdx,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          )
          .whenComplete(() {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _syncing = false;
            });
          });
      return;
    }

    final notifier = ref.read(playerProvider.notifier);
    // Shuffle: swipe segue mesma regra dos botões — escolhe aleatório.
    // O ref.listen abaixo sincroniza o carrossel com o índice escolhido.
    if (player.shuffleEnabled && player.queue.length > 1) {
      final forward = index > _currentPage;
      _currentPage = index;
      forward ? notifier.next() : notifier.previous();
      return;
    }

    _currentPage = index;
    notifier.playIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    // Só fila e índice: escutar o estado inteiro reconstruía o carrossel de
    // capas a cada atualização de posição (10×/s).
    final queue = ref.watch(playerProvider.select((s) => s.queue));
    final currentIdx = ref.watch(playerProvider.select((s) => s.currentIndex));

    // Sync carousel when song changes externally (notification, mini player)
    ref.listen<int>(playerProvider.select((s) => s.currentIndex), (prev, next) {
      if (next >= 0 && next != _currentPage && _pageCtrl.hasClients) {
        _syncing = true;
        _currentPage = next;
        _pageCtrl
            .animateToPage(
              next,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
            )
            .whenComplete(() {
              // Adia o reset 1 frame: o onPageChanged final do PageView pode
              // disparar APÓS o future de animateToPage resolver, e sem este
              // delay ele cairia no _onPageChanged sem o guard, chamando
              // playIndex(currentIndex) e reiniciando a música do zero.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _syncing = false;
              });
            });
      }
    });

    if (queue.isEmpty) {
      return SizedBox(
        width: MediaQuery.sizeOf(context).width * 0.74,
        height: MediaQuery.sizeOf(context).width * 0.74,
        child: const Center(
          child: Icon(
            Icons.music_note_rounded,
            size: 80,
            color: Colors.white24,
          ),
        ),
      );
    }

    final screenW = MediaQuery.sizeOf(context).width;
    // Height depends on style shape
    final isCircular =
        widget.npStyle == NowPlayingStyle.circular ||
        widget.npStyle == NowPlayingStyle.fullBlur ||
        widget.npStyle == NowPlayingStyle.vinyl ||
        widget.npStyle == NowPlayingStyle.aurora;
    final artSize = isCircular ? screenW * 0.68 : screenW * 0.74;

    return SizedBox(
      height: artSize + 16, // extra space for depth translation
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) =>
            _lastTouchMs = DateTime.now().millisecondsSinceEpoch,
        child: PageView.builder(
          controller: _pageCtrl,
          itemCount: queue.length,
          onPageChanged: _onPageChanged,
          physics: const BouncingScrollPhysics(),
          itemBuilder: (context, index) {
            return AnimatedBuilder(
              animation: _pageCtrl,
              builder: (context, child) {
                double page = _currentPage.toDouble();
                try {
                  if (_pageCtrl.hasClients &&
                      _pageCtrl.position.hasContentDimensions) {
                    page = _pageCtrl.page ?? page;
                  }
                } catch (_) {}

                final offset = index - page;
                final absOffset = offset.abs().clamp(0.0, 1.0);

                // PageTransformer: scale + vertical depth
                final scale = 1.0 - absOffset * 0.15; // 1.0 → 0.85
                final translateY = absOffset * 12.0; // depth effect

                return Transform.translate(
                  offset: Offset(0, translateY),
                  child: Transform.scale(
                    scale: scale,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: child,
                    ),
                  ),
                );
              },
              child: RepaintBoundary(
                child: GestureDetector(
                  onDoubleTap: () =>
                      ref.read(playerProvider.notifier).toggleFavorite(),
                  child: Hero(
                    tag: 'artwork_${queue[index].numericId}',
                    child: _buildStyleWidget(
                      songId: queue[index].numericId,
                      isCurrentPage: index == currentIdx,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStyleWidget({required int songId, required bool isCurrentPage}) {
    switch (widget.npStyle) {
      case NowPlayingStyle.classic:
        return _ClassicAlbumArt(
          colors: widget.colors,
          artColor: widget.artColor,
          songId: songId,
        );
      case NowPlayingStyle.circular:
        return _CircularAlbumArt(
          colors: widget.colors,
          artColor: widget.artColor,
          songId: songId,
          isCurrentPage: isCurrentPage,
        );
      case NowPlayingStyle.large:
        return _LargeAlbumArt(
          colors: widget.colors,
          artColor: widget.artColor,
          songId: songId,
        );
      case NowPlayingStyle.fullBlur:
        return _FullBlurAlbumArt(
          colors: widget.colors,
          artColor: widget.artColor,
          songId: songId,
        );
      case NowPlayingStyle.vinyl:
        return _VinylAlbumArt(
          colors: widget.colors,
          artColor: widget.artColor,
          songId: songId,
          isCurrentPage: isCurrentPage,
        );
      case NowPlayingStyle.minimalist:
        return _MinimalistAlbumArt(
          colors: widget.colors,
          artColor: widget.artColor,
          songId: songId,
        );
      case NowPlayingStyle.aurora:
        return _AuroraAlbumArt(
          colors: widget.colors,
          artColor: widget.artColor,
          songId: songId,
          isCurrentPage: isCurrentPage,
        );
      case NowPlayingStyle.elegant:
        return _ElegantAlbumArt(
          colors: widget.colors,
          artColor: widget.artColor,
          songId: songId,
        );
      case NowPlayingStyle.wave:
        return _WaveAlbumArt(
          colors: widget.colors,
          artColor: widget.artColor,
          songId: songId,
          isCurrentPage: isCurrentPage,
        );
      case NowPlayingStyle.mosaic:
        return _MosaicAlbumArt(
          colors: widget.colors,
          artColor: widget.artColor,
          songId: songId,
        );
    }
  }
}

// ============================================================
// ESTILO 1: CLASSIC — square 74% + vivid colored shadow
// ============================================================

// ============================================================
// ESTILO 2: CIRCULAR — breathing pulse + colored glow
// ============================================================

// ============================================================
// ESTILO 3: LARGE — edge-to-edge + colored glow
// ============================================================

// ============================================================
// ESTILO 4: FULL BLUR — circle + immersive colored glow
// ============================================================

// ── Sharp artwork background — full cover, no blur ──
class _SharpArtworkBg extends ConsumerWidget {
  const _SharpArtworkBg({required this.songId});
  final int songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Pede a maior resolução suportada pelo cache (clamp interno é 900px) —
    // a default de 300px ficava esticada e borrada quando preenchia a tela.
    const bgSize = 900;
    final notifier = ref.read(artworkProvider.notifier);
    ref.watch(
      artworkProvider.select((_) {
        return identityHashCode(
          notifier.getArtwork(songId, ArtworkType.AUDIO, size: bgSize),
        );
      }),
    );
    final data = notifier.getArtwork(songId, ArtworkType.AUDIO, size: bgSize);
    if (data == null || data.isEmpty) return const SizedBox.shrink();
    return RepaintBoundary(
      child: Image.memory(
        data,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

// ── Blurred artwork background ──
class _BlurredArtworkBg extends ConsumerWidget {
  const _BlurredArtworkBg({required this.songId, this.opacity = 0.4});
  final int songId;
  final double opacity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(artworkProvider.notifier);
    ref.watch(
      artworkProvider.select((_) {
        return identityHashCode(notifier.getArtwork(songId, ArtworkType.AUDIO));
      }),
    );
    final data = notifier.getArtwork(songId, ArtworkType.AUDIO);
    if (data == null || data.isEmpty) return const SizedBox.shrink();
    return RepaintBoundary(
      child: Opacity(
        opacity: opacity,
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 38, sigmaY: 38),
          child: Image.memory(
            data,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            gaplessPlayback: true,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// PROGRESS BAR — with remaining time display
// ============================================================
