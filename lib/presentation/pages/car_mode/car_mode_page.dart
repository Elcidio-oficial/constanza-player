import 'dart:ui';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:constanza_player/domain/entities/song.dart';
import 'package:constanza_player/l10n/gen/app_localizations.dart';
import 'package:constanza_player/domain/entities/lyric_line.dart';
import 'package:constanza_player/presentation/providers/artwork_provider.dart';
import 'package:constanza_player/presentation/providers/lyrics_provider.dart';
import 'package:constanza_player/presentation/providers/player_provider.dart';
import 'package:constanza_player/presentation/providers/theme_provider.dart';
import 'package:constanza_player/presentation/widgets/artwork_image.dart';
import 'package:constanza_player/presentation/widgets/media_seek_bar.dart';
import 'package:constanza_player/services/lyrics_fetch_service.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Car Mode Page
// Full-screen driving interface: extra-large targets, minimal distractions.
// Features: animated artwork, swipe nav, volume control, queue sheet, WakeLock.
// ──────────────────────────────────────────────────────────────────────────────

class CarModePage extends ConsumerStatefulWidget {
  const CarModePage({super.key});

  @override
  ConsumerState<CarModePage> createState() => _CarModePageState();
}

class _CarModePageState extends ConsumerState<CarModePage>
    with TickerProviderStateMixin {
  static const _screenChannel = MethodChannel('com.constanza.screen');

  double _volume = 1.0;
  bool _dimmed = false;
  String? _prevSongId;

  // Artwork crossfade controller
  late final AnimationController _artworkCtrl;
  late final Animation<double> _artworkFade;

  // Safety banner animation
  late final AnimationController _bannerCtrl;

  @override
  void initState() {
    super.initState();

    _artworkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      value: 1.0,
    );
    _artworkFade = CurvedAnimation(
      parent: _artworkCtrl,
      curve: Curves.easeInOut,
    );

    _bannerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _bannerCtrl.reverse();
    });

    _keepScreenOn(true);
    // Reforço: pede ao SO para não dormir; o canal nativo aplica
    // FLAG_KEEP_SCREEN_ON, que mantém a tela acesa enquanto a página existir.
    WidgetsBinding.instance.addPostFrameCallback((_) => _keepScreenOn(true));
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
      ),
    );
  }

  @override
  void dispose() {
    _keepScreenOn(false);
    _artworkCtrl.dispose();
    _bannerCtrl.dispose();
    super.dispose();
  }

  Future<void> _keepScreenOn(bool on) async {
    try {
      await _screenChannel.invokeMethod(on ? 'keepOn' : 'release');
    } catch (_) {}
  }

  void _onSongChanged(String? newId) {
    if (newId != null && newId != _prevSongId) {
      _prevSongId = newId;
      _artworkCtrl.forward(from: 0);
    }
  }

  void _adjustVolume(double delta) {
    final next = (_volume + delta).clamp(0.0, 1.0);
    setState(() => _volume = next);
    ref.read(playerProvider.notifier).setPlayerVolume(next);
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final palette = ref.watch(artworkPaletteProvider);
    final song = player.currentSong;
    final accent = palette?.dominant ?? const Color(0xFF7C6AF7);
    final softAccent = accent.withValues(alpha: 0.85);

    _onSongChanged(song?.id);

    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final view = ref.watch(themeProvider.select((s) => s.carModeView));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF080808),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ── Blurred artwork background ────────────────────────
            _ArtworkBackground(
              songId: song?.numericId ?? 0,
              fade: _artworkFade,
            ),

            // ── Dim overlay ──────────────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              color: _dimmed
                  ? Colors.black.withValues(alpha: 0.82)
                  : Colors.black.withValues(alpha: 0.55),
            ),

            // ── Content ──────────────────────────────────────────
            GestureDetector(
              onHorizontalDragEnd: (details) {
                final v = details.primaryVelocity ?? 0;
                if (v < -400) {
                  ref.read(playerProvider.notifier).next();
                } else if (v > 400) {
                  ref.read(playerProvider.notifier).previous();
                }
              },
              child: SafeArea(
                child: view == CarModeView.lyrics
                    ? _LyricsLayout(
                        player: player,
                        song: song,
                        accent: softAccent,
                        volume: _volume,
                        dimmed: _dimmed,
                        bannerCtrl: _bannerCtrl,
                        currentView: view,
                        onDim: () => setState(() => _dimmed = !_dimmed),
                        onVolume: _adjustVolume,
                        onQueue: () => _showQueue(context, player, accent),
                      )
                    : isLandscape
                    ? _LandscapeLayout(
                        player: player,
                        song: song,
                        accent: softAccent,
                        volume: _volume,
                        dimmed: _dimmed,
                        artworkFade: _artworkFade,
                        bannerCtrl: _bannerCtrl,
                        currentView: view,
                        onDim: () => setState(() => _dimmed = !_dimmed),
                        onVolume: _adjustVolume,
                        onQueue: () => _showQueue(context, player, accent),
                      )
                    : _PortraitLayout(
                        player: player,
                        song: song,
                        accent: softAccent,
                        volume: _volume,
                        dimmed: _dimmed,
                        artworkFade: _artworkFade,
                        bannerCtrl: _bannerCtrl,
                        currentView: view,
                        onDim: () => setState(() => _dimmed = !_dimmed),
                        onVolume: _adjustVolume,
                        onQueue: () => _showQueue(context, player, accent),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQueue(BuildContext context, PlayerState player, Color accent) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _QueueSheet(player: player, accent: accent, l10n: l10n),
    );
  }
}

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
    try {
      final song = ref.read(playerProvider).currentSong ?? widget.song;
      if (song == null) return;
      // Vincula o provider a esta música antes de importar.
      await ref.read(lyricsProvider.notifier).loadForSong(song.id);
      final lines = await LyricsFetchService.fetch(
        title: song.title,
        artist: song.artist,
        album: song.album,
        duration: song.duration,
      );
      if (!mounted) return;
      final notifier = ref.read(lyricsProvider.notifier);
      if (lines != null && lines.isNotEmpty) {
        final synced = lines.where((l) => l.isSynced).toList();
        if (synced.isNotEmpty) {
          final lrc = synced
              .map((l) {
                final ts = l.timestamp!;
                final m = ts.inMinutes.remainder(60).toString().padLeft(2, '0');
                final s = ts.inSeconds.remainder(60).toString().padLeft(2, '0');
                final ms = (ts.inMilliseconds.remainder(1000) ~/ 10)
                    .toString()
                    .padLeft(2, '0');
                return '[$m:$s.$ms]${l.text}';
              })
              .join('\n');
          await notifier.importLrc(lrc);
        } else {
          await notifier.importPlainText(lines.map((l) => l.text).join('\n'));
        }
      } else {
        // Nada encontrado — marca para não repetir a busca automática.
        await notifier.markOnlineMiss();
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

// ──────────────────────────────────────────────────────────────────────────────
// Queue Bottom Sheet
// ──────────────────────────────────────────────────────────────────────────────

class _QueueSheet extends ConsumerWidget {
  const _QueueSheet({
    required this.player,
    required this.accent,
    required this.l10n,
  });

  final PlayerState player;
  final Color accent;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = player.queue;
    final currentIdx = player.currentIndex;
    final upcoming = currentIdx >= 0
        ? queue.skip(currentIdx + 1).toList()
        : queue;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.65,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.75),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(Icons.queue_music_rounded, color: accent, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      l10n.carModeQueueTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${upcoming.length}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (upcoming.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    l10n.carModeQueueEmpty,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 14,
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 20),
                    itemCount: upcoming.length,
                    itemBuilder: (context, i) {
                      final s = upcoming[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 2,
                        ),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: ArtworkImage.song(
                            songId: s.numericId,
                            size: 44,
                            placeholderIcon: Icons.music_note_rounded,
                            placeholderIconSize: 20,
                          ),
                        ),
                        title: Text(
                          s.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          s.artist,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          '${i + 1}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.25),
                            fontSize: 13,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          final globalIdx = currentIdx + 1 + i;
                          if (globalIdx < queue.length) {
                            ref
                                .read(playerProvider.notifier)
                                .playIndex(globalIdx);
                          }
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Reusable button components
// ──────────────────────────────────────────────────────────────────────────────

class _CarBtn extends StatelessWidget {
  const _CarBtn({
    required this.icon,
    required this.size,
    required this.iconSize,
    required this.color,
    this.bgColor,
    this.shadow = false,
    this.onTap,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final Color color;
  final Color? bgColor;
  final bool shadow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color:
              bgColor ??
              Colors.white.withValues(alpha: onTap != null ? 0.1 : 0.04),
          boxShadow: shadow && onTap != null
              ? [
                  BoxShadow(
                    color: (bgColor ?? Colors.white).withValues(alpha: 0.3),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Icon(icon, size: iconSize, color: color),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.size,
    required this.iconSize,
    this.active = false,
    this.activeColor,
    this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final bool active;
  final Color? activeColor;
  final String? tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? (activeColor ?? Colors.white)
        : Colors.white.withValues(alpha: 0.65);

    final btn = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? (activeColor ?? Colors.white).withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.08),
              border: Border.all(
                color: active
                    ? (activeColor ?? Colors.white).withValues(alpha: 0.35)
                    : Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Icon(icon, size: iconSize, color: color),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: btn);
    }
    return btn;
  }
}
