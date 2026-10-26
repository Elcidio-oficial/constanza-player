part of '../car_mode_page.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Lyrics Layout (Car Mode — driving-friendly large text view)
// ──────────────────────────────────────────────────────────────────────────────

class _LyricsLayout extends ConsumerStatefulWidget {
  const _LyricsLayout({
    required this.player,
    required this.song,
    required this.accent,
    required this.volume,
    required this.dimmed,
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
  final AnimationController bannerCtrl;
  final CarModeView currentView;
  final VoidCallback onDim;
  final void Function(double) onVolume;
  final VoidCallback onQueue;

  @override
  ConsumerState<_LyricsLayout> createState() => _LyricsLayoutState();
}

class _LyricsLayoutState extends ConsumerState<_LyricsLayout> {
  final ScrollController _scroll = ScrollController();
  final Map<int, GlobalKey> _keys = {};
  int _lastIdx = -1;
  int _scrollAttempt = 0;
  bool _scrollScheduled = false;

  /// Busca automática de letra — espelha o comportamento da tela de Letras.
  bool _isSearching = false;
  String? _autoSearchedSongId;

  GlobalKey _keyFor(int i) => _keys.putIfAbsent(i, () => GlobalKey());

  @override
  void initState() {
    super.initState();
    final id = widget.song?.id;
    if (id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(lyricsProvider.notifier).loadForSong(id);
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // ── Scroll sincronizado ─────────────────────────────────────

  /// Agenda uma centralização para depois do frame — uma única cadeia ativa.
  void _scheduleScroll(int idx) {
    if (idx < 0 || idx == _lastIdx || _scrollScheduled) return;
    _armScroll(idx);
  }

  void _armScroll(int idx) {
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
      if (mounted) _scrollTo(idx);
    });
  }

  void _scrollTo(int idx) {
    if (idx < 0 || !mounted || idx == _lastIdx) return;

    final ctx = _keys[idx]?.currentContext;
    if (ctx != null) {
      // Linha já renderizada — centra com precisão.
      _lastIdx = idx;
      _scrollAttempt = 0;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        alignment: 0.45,
      );
      return;
    }

    // Linha-alvo fora da área renderizada — ao abrir/reabrir o Modo Carro com
    // a música já a meio. Aproxima com saltos instantâneos até a linha existir
    // e então centra suavemente.
    if (!_scroll.hasClients || _scrollAttempt >= 40) {
      _scrollAttempt = 0;
      return;
    }
    _scrollAttempt++;
    final pos = _scroll.position;
    final vp = pos.viewportDimension;
    final built = _keys.entries
        .where((e) => e.value.currentContext != null)
        .map((e) => e.key)
        .toList();
    double target;
    if (built.isNotEmpty && built.every((i) => i < idx)) {
      target = pos.pixels + vp * 0.85;
    } else if (built.isNotEmpty && built.every((i) => i > idx)) {
      target = pos.pixels - vp * 0.85;
    } else {
      target = idx * 64.0;
    }
    _scroll.jumpTo(target.clamp(pos.minScrollExtent, pos.maxScrollExtent));
    _armScroll(idx);
  }

  // ── Busca automática de letra ───────────────────────────────

  Future<void> _searchOnline() async {
    if (_isSearching) return;
    setState(() => _isSearching = true);
    final song = ref.read(playerProvider).currentSong ?? widget.song;
    if (song == null) {
      if (mounted) setState(() => _isSearching = false);
      return;
    }
    final targetId = song.id;
    try {
      // Vincula o provider a esta música antes de qualquer escrita.
      await ref.read(lyricsProvider.notifier).loadForSong(targetId);
      final lines = await LyricsFetchService.fetch(
        title: song.title,
        artist: song.artist,
        album: song.album,
        duration: song.duration,
      );
      if (!mounted) return;
      // Guard de corrida: persiste na chave de origem; o notifier só atualiza a
      // UI se a faixa atual ainda for [targetId] (skip não vaza letra p/ a nova).
      final notifier = ref.read(lyricsProvider.notifier);
      if (lines != null && lines.isNotEmpty) {
        await notifier.applyOnlineResult(targetId, lines);
      } else {
        await notifier.markOnlineMissFor(targetId);
      }
    } catch (_) {
      // Silencioso no Modo Carro — sem distrair o motorista.
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lyrics = ref.watch(lyricsProvider);
    final position = ref.watch(playerProvider.select((s) => s.position));

    // Reload on song change.
    ref.listen<String?>(playerProvider.select((s) => s.currentSong?.id), (
      prev,
      next,
    ) {
      if (next != null && next != prev) {
        _lastIdx = -1;
        _scrollAttempt = 0;
        _scrollScheduled = false;
        _autoSearchedSongId = null;
        ref.read(lyricsProvider.notifier).loadForSong(next);
      }
    });

    // Busca automática de letra também no Modo Carro — evita que o usuário
    // precise sair para a tela de Letras e voltar. Dispara quando não há
    // letra local e ainda não se confirmou que não existe online.
    final searchSong = widget.song;
    if (searchSong != null &&
        lyrics.isLoaded &&
        lyrics.isEmpty &&
        !lyrics.onlineMiss &&
        !_isSearching &&
        _autoSearchedSongId != searchSong.id) {
      _autoSearchedSongId = searchSong.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchOnline();
      });
    }

    // Auto-scroll — centraliza a linha cantada em tempo real, inclusive ao
    // abrir/reabrir a tela com a música já em andamento.
    final curIdx = lyrics.currentLineIndex(position);
    if (curIdx >= 0 && lyrics.lines.isNotEmpty) {
      _scheduleScroll(curIdx);
    }

    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    final lyricsBody = (!lyrics.isLoaded || _isSearching)
        ? Center(
            child: Text(
              l10n.carModeLyricsLoading,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 16,
              ),
            ),
          )
        : lyrics.isEmpty
        ? Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                l10n.carModeNoLyrics,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          )
        : _CarLyricsList(
            lines: lyrics.lines,
            currentIndex: curIdx,
            scroll: _scroll,
            keyFor: _keyFor,
            accent: widget.accent,
            compact: isLandscape,
          );

    if (isLandscape) {
      return Column(
        children: [
          _TopBar(
            l10n: l10n,
            dimmed: widget.dimmed,
            currentView: widget.currentView,
            onDim: widget.onDim,
            onQueue: widget.onQueue,
          ),
          _SafetyBanner(ctrl: widget.bannerCtrl, l10n: l10n),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left: lyrics
                Expanded(flex: 5, child: lyricsBody),
                // Right: controls
                Expanded(
                  flex: 5,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 6),
                        _SongInfo(song: widget.song, accent: widget.accent),
                        const SizedBox(height: 10),
                        _ProgressSection(
                          player: widget.player,
                          accent: widget.accent,
                        ),
                        const SizedBox(height: 8),
                        _MainControls(
                          player: widget.player,
                          accent: widget.accent,
                          compact: true,
                        ),
                        const SizedBox(height: 10),
                        _VolumeRow(
                          volume: widget.volume,
                          accent: widget.accent,
                          onVolume: widget.onVolume,
                          l10n: l10n,
                        ),
                        const SizedBox(height: 10),
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

    return Column(
      children: [
        _TopBar(
          l10n: l10n,
          dimmed: widget.dimmed,
          currentView: widget.currentView,
          onDim: widget.onDim,
          onQueue: widget.onQueue,
        ),
        _SafetyBanner(ctrl: widget.bannerCtrl, l10n: l10n),
        const SizedBox(height: 4),
        _SongInfo(song: widget.song, accent: widget.accent),
        const SizedBox(height: 12),
        Expanded(child: lyricsBody),
        const SizedBox(height: 6),
        _ProgressSection(player: widget.player, accent: widget.accent),
        const SizedBox(height: 6),
        _MainControls(
          player: widget.player,
          accent: widget.accent,
          compact: true,
        ),
        const SizedBox(height: 8),
        _VolumeRow(
          volume: widget.volume,
          accent: widget.accent,
          onVolume: widget.onVolume,
          l10n: l10n,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _CarLyricsList extends StatelessWidget {
  const _CarLyricsList({
    required this.lines,
    required this.currentIndex,
    required this.scroll,
    required this.keyFor,
    required this.accent,
    this.compact = false,
  });

  final List<LyricLine> lines;
  final int currentIndex;
  final ScrollController scroll;
  final GlobalKey Function(int idx) keyFor;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final centerPad = constraints.maxHeight / 2;
        return ShaderMask(
          shaderCallback: (rect) {
            return const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black,
                Colors.black,
                Colors.transparent,
              ],
              stops: [0.0, 0.18, 0.82, 1.0],
            ).createShader(rect);
          },
          blendMode: BlendMode.dstIn,
          child: ListView(
            controller: scroll,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(
              top: centerPad,
              bottom: centerPad,
              left: 28,
              right: 28,
            ),
            children: [
              for (int i = 0; i < lines.length; i++)
                Padding(
                  key: keyFor(i),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    style: TextStyle(
                      color: i == currentIndex
                          ? Colors.white
                          : Colors.white.withValues(
                              alpha:
                                  (0.55 -
                                          (currentIndex >= 0
                                                  ? (i - currentIndex).abs()
                                                  : 0) *
                                              0.08)
                                      .clamp(0.15, 0.55),
                            ),
                      fontWeight: i == currentIndex
                          ? FontWeight.w800
                          : FontWeight.w600,
                      fontSize: i == currentIndex
                          ? (compact ? 22 : 32)
                          : (compact ? 17 : 26),
                      height: 1.3,
                      shadows: i == currentIndex
                          ? [
                              Shadow(
                                color: accent.withValues(alpha: 0.5),
                                blurRadius: 12,
                              ),
                            ]
                          : null,
                    ),
                    child: Text(lines[i].text, textAlign: TextAlign.center),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
