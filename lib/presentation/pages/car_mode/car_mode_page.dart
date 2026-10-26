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

// Seções da tela
part 'parts/layouts.dart';
part 'parts/lyrics.dart';
part 'parts/components.dart';
part 'parts/queue_sheet.dart';
part 'parts/buttons.dart';

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
