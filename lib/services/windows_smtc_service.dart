import 'dart:async';
import 'dart:io' show Platform;

import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState;
import 'package:smtc_windows/smtc_windows.dart';

import 'package:constanza_player/services/artwork_file_service.dart';
import 'package:constanza_player/services/audio_handler.dart';

/// System Media Transport Controls bridge para Windows.
///
/// Espelha o estado do [ConstanzaAudioHandler] no SMTC nativo do Windows,
/// fornecendo:
/// - Controles de mídia da SuperBar / overlay de volume.
/// - Atalhos de teclado (Play/Pause/Next/Previous keys).
/// - Cards de "Mídia em reprodução" no Action Center.
///
/// Em outras plataformas (Android/iOS/Linux/macOS) esta classe é um no-op —
/// criada apenas para manter o código de inicialização agnóstico.
class WindowsSmtcService {
  WindowsSmtcService._(this._handler, this._smtc);

  final ConstanzaAudioHandler _handler;
  final SMTCWindows? _smtc;

  final List<StreamSubscription> _subs = [];
  String? _lastMediaItemId;

  static WindowsSmtcService? _instance;
  static WindowsSmtcService? get instance => _instance;

  /// Cria e conecta o serviço. Retorna null em plataformas não-Windows.
  static Future<WindowsSmtcService?> init(ConstanzaAudioHandler handler) async {
    if (!Platform.isWindows) return null;
    if (_instance != null) return _instance;

    SMTCWindows? smtc;
    try {
      smtc = SMTCWindows(
        config: const SMTCConfig(
          playEnabled: true,
          pauseEnabled: true,
          nextEnabled: true,
          prevEnabled: true,
          stopEnabled: false,
          fastForwardEnabled: false,
          rewindEnabled: false,
        ),
        metadata: const MusicMetadata(
          title: 'Constanza Músicas',
          artist: '',
          album: '',
        ),
        status: PlaybackStatus.Stopped,
      );
    } catch (e) {
      debugPrint('[SMTC] init failed: $e');
      return null;
    }

    final svc = WindowsSmtcService._(handler, smtc);
    svc._attach();
    _instance = svc;
    return svc;
  }

  void _attach() {
    final smtc = _smtc;
    if (smtc == null) return;

    // ── OUTGOING: handler → SMTC ─────────────────────────────────

    _subs.add(_handler.playingStream.listen((playing) {
      smtc.setPlaybackStatus(
        playing ? PlaybackStatus.Playing : PlaybackStatus.Paused,
      );
    }));

    _subs.add(_handler.processingStateStream.listen((state) {
      if (state == ProcessingState.idle ||
          state == ProcessingState.completed) {
        smtc.setPlaybackStatus(PlaybackStatus.Stopped);
      }
    }));

    _subs.add(_handler.mediaItem.listen(_onMediaItem));

    // Position update (a cada ~1s é suficiente; just_audio emite com mais
    // frequência, mas SMTC só precisa do valor para o overlay).
    _subs.add(_handler.positionStream.listen((pos) {
      final dur = _handler.duration ?? Duration.zero;
      smtc.updateTimeline(PlaybackTimeline(
        startTimeMs: 0,
        endTimeMs: dur.inMilliseconds,
        positionMs: pos.inMilliseconds,
      ));
    }));

    // ── INCOMING: SMTC buttons → handler ─────────────────────────

    _subs.add(smtc.buttonPressStream.listen((btn) {
      switch (btn) {
        case PressedButton.play:
          _handler.play();
          break;
        case PressedButton.pause:
          _handler.pause();
          break;
        case PressedButton.next:
          _handler.skipToNext();
          break;
        case PressedButton.previous:
          _handler.skipToPrevious();
          break;
        case PressedButton.stop:
          _handler.stop();
          break;
        default:
          break;
      }
    }));
  }

  Future<void> _onMediaItem(MediaItem? item) async {
    final smtc = _smtc;
    if (smtc == null || item == null) return;
    if (item.id == _lastMediaItemId) {
      // Mesma faixa — só atualiza thumbnail se vier nova artUri
      if (item.artUri != null) {
        await _setThumbnailFromUri(item.artUri!);
      }
      return;
    }
    _lastMediaItemId = item.id;

    await smtc.updateMetadata(MusicMetadata(
      title: item.title,
      artist: item.artist ?? '',
      album: item.album ?? '',
    ));

    // Tenta gerar thumbnail a partir do artwork file URI (mesma rota do Android).
    // O numericId vem nos extras do MediaItem (definido em audio_handler.loadSong).
    final numericId = item.extras?['numericId'] as int? ?? 0;
    if (numericId > 0) {
      final uri = await ArtworkFileService.getArtworkFileUri(numericId);
      if (uri != null) {
        await _setThumbnailFromUri(uri);
      }
    }
  }

  Future<void> _setThumbnailFromUri(Uri uri) async {
    final smtc = _smtc;
    if (smtc == null) return;
    try {
      // SMTC aceita caminho de arquivo absoluto. Uri.file().toFilePath()
      // converte para o formato esperado no Windows (C:\...).
      final path = uri.isScheme('file') ? uri.toFilePath() : uri.toString();
      await smtc.setThumbnail(path);
    } catch (e) {
      debugPrint('[SMTC] setThumbnail failed: $e');
    }
  }

  Future<void> dispose() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    try {
      await _smtc?.dispose();
    } catch (_) {}
  }
}
