// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'package:constanza_player/domain/entities/song.dart';
import 'package:constanza_player/services/audio_effects_service.dart';

/// Handler de áudio central — integra just_audio com audio_service.
///
/// Responsável por:
/// - Reproduzir / pausar / navegar entre faixas
/// - Publicar MediaItem (capa, título, artista) → notificação e tela de bloqueio
/// - Propagar estado de reprodução → notificação atualizada em tempo real
/// - Crossfade, velocidade, EQ
class ConstanzaAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  // ──────────────────────────────────────────────────────────
  // CAMPOS
  // ──────────────────────────────────────────────────────────

  final AudioPlayer _player = AudioPlayer();

  int _eqSessionId = 0;
  _EqConfig? _lastEqConfig;

  int _crossfadeSeconds = 0;
  bool _isCrossfading = false;
  Timer? _crossfadeTimer;

  double _speed = 1.0;

  // ──────────────────────────────────────────────────────────
  // CONSTRUTOR
  // ──────────────────────────────────────────────────────────

  ConstanzaAudioHandler() {
    _init();
  }

  void _init() {
    // Estado de reprodução → AudioServiceState (notificação)
    _player.playbackEventStream.listen(_broadcastState);

    // Progresso / duração
    _player.positionStream.listen((pos) {
      _maybeCrossfade();
    });

    // Música completa → avançar
    _player.processingStateStream.listen((s) {
      if (s == ProcessingState.completed) _handleCompleted();
    });

    // Session ID para EQ nativo
    _player.androidAudioSessionIdStream.listen((sid) {
      if (sid != null) _reinitEq(sid);
    });
  }

  // ──────────────────────────────────────────────────────────
  // BROADCAST STATE → notificação / tela de bloqueio
  // ──────────────────────────────────────────────────────────

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.skipToPrevious,
          MediaAction.skipToNext,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: switch (_player.processingState) {
          ProcessingState.idle     => AudioProcessingState.idle,
          ProcessingState.loading  => AudioProcessingState.loading,
          ProcessingState.buffering=> AudioProcessingState.buffering,
          ProcessingState.ready    => AudioProcessingState.ready,
          ProcessingState.completed=> AudioProcessingState.completed,
        },
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: 0,
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // CARREGAR MÚSICA
  // ──────────────────────────────────────────────────────────

  /// Carrega uma [Song] e publica o MediaItem para a notificação.
  /// [artworkUri] é a URI local do MediaStore para a capa (zero latência).
  Future<void> loadSong(
    Song song, {
    Uri? artworkUri,
  }) async {
    // Publicar MediaItem → Android usa para a notificação e tela de bloqueio
    final item = MediaItem(
      id: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album,
      duration: song.duration,
      artUri: artworkUri, // URI de arquivo local ou network
      extras: {
        'uri': song.uri,
        'numericId': song.numericId,
      },
    );
    mediaItem.add(item);

    try {
      if (song.uri.startsWith('content://') || song.uri.startsWith('http')) {
        await _player.setUrl(song.uri);
      } else {
        await _player.setFilePath(song.uri);
      }
      if (_speed != 1.0) await _player.setSpeed(_speed);
      _isCrossfading = false;
      _player.setVolume(1.0);
    } catch (e) {
      debugPrint('[AudioHandler] loadSong error: $e');
    }
  }

  // ──────────────────────────────────────────────────────────
  // CONTROLES PADRÃO (BaseAudioHandler)
  // ──────────────────────────────────────────────────────────

  @override
  Future<void> play() async => _player.play();

  @override
  Future<void> pause() async => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) async {
    _speed = speed;
    await _player.setSpeed(speed);
    playbackState.add(playbackState.value.copyWith(speed: speed));
  }

  @override
  Future<void> skipToNext() async => _onNext();

  @override
  Future<void> skipToPrevious() async => _onPrevious();

  // ──────────────────────────────────────────────────────────
  // STREAMS PÚBLICOS (para o PlayerNotifier)
  // ──────────────────────────────────────────────────────────

  Stream<bool> get playingStream => _player.playingStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<ProcessingState> get processingStateStream =>
      _player.processingStateStream;
  Stream<int?> get androidAudioSessionIdStream =>
      _player.androidAudioSessionIdStream;

  bool get playing => _player.playing;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;

  // ──────────────────────────────────────────────────────────
  // NAVEGAÇÃO INTERNA (delegada pelo PlayerNotifier)
  // ──────────────────────────────────────────────────────────

  // Callbacks definidos externamente pelo PlayerNotifier
  VoidCallback? onNext;
  VoidCallback? onPrevious;
  VoidCallback? onCompleted;

  void _onNext() => onNext?.call();
  void _onPrevious() => onPrevious?.call();
  void _handleCompleted() => onCompleted?.call();

  // ──────────────────────────────────────────────────────────
  // EQ NATIVO
  // ──────────────────────────────────────────────────────────

  Future<void> _reinitEq(int sessionId) async {
    if (sessionId == _eqSessionId) return;
    try {
      if (_eqSessionId != 0) await AudioEffectsService.release();
      await AudioEffectsService.init(sessionId);
      _eqSessionId = sessionId;
      if (_lastEqConfig != null) await _applyEqNow(_lastEqConfig!);
    } catch (e) {
      debugPrint('[AudioHandler] EQ reinit error: $e');
    }
  }

  Future<void> applyEqSettings({
    required bool enabled,
    required List<double> bands,
    required double bassBoost,
    required double virtualizer,
  }) async {
    _lastEqConfig = _EqConfig(
      enabled: enabled,
      bands: bands,
      bassBoost: bassBoost,
      virtualizer: virtualizer,
    );
    if (_eqSessionId != 0) await _applyEqNow(_lastEqConfig!);
  }

  Future<void> _applyEqNow(_EqConfig c) async {
    await AudioEffectsService.setEnabled(c.enabled);
    if (c.enabled) {
      await AudioEffectsService.setAllBands(
        c.bands.map((db) => (db * 100).round()).toList(),
      );
      await AudioEffectsService.setBassBoost(
        (c.bassBoost * 100).round().clamp(0, 1000),
      );
      await AudioEffectsService.setVirtualizer(
        (c.virtualizer * 100).round().clamp(0, 1000),
      );
    }
  }

  // ──────────────────────────────────────────────────────────
  // CROSSFADE
  // ──────────────────────────────────────────────────────────

  void setCrossfadeDuration(int seconds) {
    _crossfadeSeconds = seconds.clamp(0, 12);
  }

  void _maybeCrossfade() {
    if (_crossfadeSeconds <= 0 || _isCrossfading) return;
    final dur = _player.duration;
    if (dur == null) return;
    final remaining = dur - _player.position;
    if (remaining > Duration.zero &&
        remaining.inSeconds <= _crossfadeSeconds &&
        _player.playing) {
      _isCrossfading = true;
      _runFadeOut(remaining);
    }
  }

  void _runFadeOut(Duration over) {
    const steps = 20;
    final interval = over ~/ steps;
    var step = 0;
    _crossfadeTimer?.cancel();
    _crossfadeTimer = Timer.periodic(interval, (t) {
      step++;
      _player.setVolume((1.0 - step / steps).clamp(0.0, 1.0));
      if (step >= steps) t.cancel();
    });
  }

  void resetVolume() {
    _crossfadeTimer?.cancel();
    _isCrossfading = false;
    _player.setVolume(1.0);
  }

  // ──────────────────────────────────────────────────────────
  // DISPOSE
  // ──────────────────────────────────────────────────────────

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (name == 'dispose') {
      _crossfadeTimer?.cancel();
      await AudioEffectsService.release();
      await _player.dispose();
    }
  }
}

// ── Config interna ────────────────────────────────────────

class _EqConfig {
  const _EqConfig({
    required this.enabled,
    required this.bands,
    required this.bassBoost,
    required this.virtualizer,
  });
  final bool enabled;
  final List<double> bands;
  final double bassBoost;
  final double virtualizer;
}
