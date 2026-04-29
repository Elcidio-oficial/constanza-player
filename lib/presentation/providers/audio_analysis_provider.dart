import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:constanza_player/services/audio_analysis_service.dart';
import 'package:constanza_player/services/bpm_key_fetch_service.dart';
import 'package:constanza_player/services/native_audio_analysis_service.dart';

export 'package:constanza_player/services/native_audio_analysis_service.dart'
    show NativeAnalysisResult;

/// Estado da análise para a música atual.
class AudioAnalysisState {
  const AudioAnalysisState({
    this.result,
    this.nativeResult,
    this.isLoading = false,
    this.songId,
    this.failed = false,
    this.errorMessage,
  });

  final AudioAnalysisResult? result;

  /// Resultado da análise DSP local (BPM + tonalidade, sempre offline).
  final NativeAnalysisResult? nativeResult;
  final bool isLoading;
  final String? songId;
  final bool failed;

  /// Mensagem de erro descritiva quando [failed] é true.
  final String? errorMessage;

  bool get hasOnlineData => result != null && result!.hasAnyData;
  bool get hasNativeData => nativeResult != null && nativeResult!.hasData;

  /// BPM: prefere online (mais preciso para músicas conhecidas), fallback nativo.
  int? get bpm => result?.bpm ?? nativeResult?.bpm;

  /// Tonalidade: prefere online, fallback nativo.
  String? get key => result?.key ?? nativeResult?.key;
  String? get scale => result?.scale ?? nativeResult?.scale;
  String? get camelotCode => result?.camelotCode;

  /// Label completo: "120 BPM · C Menor (8B)"
  String get fullLabel {
    final parts = <String>[];
    final b = bpm;
    if (b != null && b > 0) parts.add('$b BPM');
    final k = key;
    final s = scale;
    if (k != null && k.isNotEmpty && s != null) {
      final scaleLabel = s == 'Major' ? 'Maior' : 'Menor';
      final keyStr = '$k $scaleLabel';
      final camelot = camelotCode;
      parts.add(camelot != null ? '$keyStr ($camelot)' : keyStr);
    }
    return parts.join(' · ');
  }

  /// Fonte do dado (para exibição na UI).
  String get sourceLabel {
    if (hasOnlineData) return result!.sourceLabel;
    if (hasNativeData) return 'On-device';
    return '';
  }

  bool get hasAnyData => bpm != null || key != null;
}

class AudioAnalysisNotifier extends StateNotifier<AudioAnalysisState> {
  AudioAnalysisNotifier() : super(const AudioAnalysisState());

  String? _currentJobId;

  /// Analisa uma música: nativo (sempre) + online (se tiver credenciais).
  Future<void> analyzeSong(
    String songId,
    String uri, {
    String? title,
    String? artist,
  }) async {
    // Guard: já tem dados para essa música
    if (songId == state.songId && state.hasAnyData && !state.isLoading) return;

    // Guard: já está analisando essa música
    if (songId == state.songId && state.isLoading) return;

    final jobId = '${songId}_${DateTime.now().millisecondsSinceEpoch}';
    _currentJobId = jobId;

    // 1. Checar cache online
    final cached = AudioAnalysisService.getCached(songId);
    if (cached != null && cached.hasAnyData) {
      // Ainda roda análise nativa em background para ter confidence scores
      state = AudioAnalysisState(result: cached, songId: songId);
      _runNativeInBackground(songId, uri, jobId);
      return;
    }

    state = AudioAnalysisState(isLoading: true, songId: songId);

    // 2. Análise nativa (offline, sempre disponível)
    NativeAnalysisResult? nativeResult;
    try {
      debugPrint('[Analysis] Starting native DSP for "$title"');
      nativeResult = await NativeAudioAnalysisService.analyze(uri);
      if (!mounted || _isStale(jobId)) return;

      if (nativeResult != null && nativeResult.hasData) {
        debugPrint(
          '[Analysis] Native: bpm=${nativeResult.bpm} (${nativeResult.bpmConfidencePercent}) '
          'key=${nativeResult.keyLabel} (${nativeResult.keyConfidencePercent})',
        );
        // Atualiza estado com resultado nativo já disponível
        state = AudioAnalysisState(
          nativeResult: nativeResult,
          songId: songId,
          isLoading:
              BpmKeyFetchService.hasCredentials &&
              title != null &&
              artist != null,
        );
      }
    } catch (e) {
      debugPrint('[Analysis] Native error: $e');
      if (!mounted || _isStale(jobId)) return;
      state = AudioAnalysisState(
        songId: songId,
        failed: true,
        errorMessage: 'Análise local falhou: ${e.runtimeType}',
      );
      return;
    }

    if (_isStale(jobId)) return;

    // 3. Enriquece com dados online (energia, danceability, tonalidade mais precisa)
    if (BpmKeyFetchService.hasCredentials &&
        title != null &&
        title.isNotEmpty &&
        artist != null &&
        artist.isNotEmpty) {
      try {
        final onlineResult = await AudioAnalysisService.analyze(
          songId: songId,
          title: title,
          artist: artist,
        );

        if (!mounted || _isStale(jobId)) return;

        if (onlineResult != null && onlineResult.hasAnyData) {
          debugPrint(
            '[Analysis] Online: bpm=${onlineResult.bpm} key=${onlineResult.key} ${onlineResult.scale}',
          );
          state = AudioAnalysisState(
            result: onlineResult,
            nativeResult: nativeResult,
            songId: songId,
          );
          return;
        }
      } catch (e) {
        debugPrint('[Analysis] Online error: $e');
        // Não falhar aqui: ainda temos o resultado nativo disponível
      }
    }

    if (!mounted || _isStale(jobId)) return;

    final hasFailed = nativeResult == null || !nativeResult.hasData;
    // Finaliza com o que temos (nativo ou vazio)
    state = AudioAnalysisState(
      nativeResult: nativeResult,
      songId: songId,
      failed: hasFailed,
      errorMessage: hasFailed ? 'Não foi possível analisar esta faixa' : null,
    );
  }

  void _runNativeInBackground(String songId, String uri, String jobId) {
    NativeAudioAnalysisService.analyze(uri)
        .then((nativeResult) {
          if (!mounted || _isStale(jobId)) return;
          if (nativeResult != null && nativeResult.hasData) {
            state = AudioAnalysisState(
              result: state.result,
              nativeResult: nativeResult,
              songId: songId,
            );
          }
        })
        .catchError((Object e) {
          debugPrint('[Analysis] Background native error: $e');
        });
  }

  bool _isStale(String? jobId) => jobId != null && _currentJobId != jobId;

  /// Força re-análise (ignora cache).
  Future<void> retry(
    String songId,
    String uri, {
    String? title,
    String? artist,
  }) async {
    AudioAnalysisService.clearSongCache(songId);
    NativeAudioAnalysisService.removeCached(uri);
    state = const AudioAnalysisState();
    await analyzeSong(songId, uri, title: title, artist: artist);
  }

  void clear() {
    _currentJobId = null;
    state = const AudioAnalysisState();
  }
}

final audioAnalysisProvider =
    StateNotifierProvider<AudioAnalysisNotifier, AudioAnalysisState>(
      (ref) => AudioAnalysisNotifier(),
    );

/// Provider de resultados em batch (para a Home page).
class BatchAnalysisNotifier
    extends StateNotifier<Map<String, AudioAnalysisResult>> {
  BatchAnalysisNotifier() : super({});

  static const _maxConcurrent = 5;
  final Set<String> _analyzing = {};

  Future<void> analyzeList(
    List<({String id, String title, String artist})> songs,
  ) async {
    if (!BpmKeyFetchService.hasCredentials) return;

    for (final song in songs) {
      if (state.containsKey(song.id) || _analyzing.contains(song.id)) continue;

      // Respeitar limite de concorrência — não disparar mais jobs até liberar slot
      if (_analyzing.length >= _maxConcurrent) break;

      final cached = AudioAnalysisService.getCached(song.id);
      if (cached != null) {
        state = {...state, song.id: cached};
        continue;
      }

      _analyzing.add(song.id);
      AudioAnalysisService.analyze(
            songId: song.id,
            title: song.title,
            artist: song.artist,
          )
          .then((result) {
            _analyzing.remove(song.id);
            if (mounted && result != null) {
              state = {...state, song.id: result};
            }
          })
          .catchError((Object e) {
            _analyzing.remove(song.id);
            debugPrint('[BatchAnalysis] Error analyzing ${song.id}: $e');
          });
    }
  }

  AudioAnalysisResult? getResult(String songId) => state[songId];
}

final batchAnalysisProvider =
    StateNotifierProvider<
      BatchAnalysisNotifier,
      Map<String, AudioAnalysisResult>
    >((ref) => BatchAnalysisNotifier());
