// ignore_for_file: unnecessary_import

import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:constanza_player/services/media_library/media_library_backend.dart';

// ============================================================
// ARTWORK PALETTE — multi-color palette extracted from artwork
// ============================================================

class ArtworkPalette {
  const ArtworkPalette({
    required this.dominant,
    required this.vibrant,
    required this.muted,
    this.secondary,
    this.tertiary,
  });

  /// Versão escura rica para bg/tints (mini player, nav bar)
  final Color dominant;

  /// Versão vívida para controles/acentos
  final Color vibrant;

  /// Versão suave para elementos secundários
  final Color muted;

  /// 2ª cor do artwork (pode ser null)
  final Color? secondary;

  /// 3ª cor do artwork (pode ser null)
  final Color? tertiary;

  static const fallback = ArtworkPalette(
    dominant: Color(0xFF1A1A2E),
    vibrant: Color(0xFF6C63FF),
    muted: Color(0xFF3A3A5C),
  );
}

/// Chave para identificar uma artwork no cache.
class ArtworkKey {
  const ArtworkKey(this.id, this.type, this.size);
  final int id;
  final ArtworkType type;
  final int size;

  @override
  bool operator ==(Object other) =>
      other is ArtworkKey &&
      other.id == id &&
      other.type == type &&
      other.size == size;

  @override
  int get hashCode => Object.hash(id, type, size);
}

/// Cache LRU em memória para artworks.
///
/// Mantém até [maxEntries] imagens em memória.
/// Quando excede, remove as menos recentemente usadas.
class ArtworkCache {
  ArtworkCache({this.maxEntries = 200});

  final int maxEntries;
  final LinkedHashMap<ArtworkKey, Uint8List?> _cache = LinkedHashMap();
  final Set<ArtworkKey> _loading = {};

  /// Verifica se a artwork está em cache.
  bool has(ArtworkKey key) => _cache.containsKey(key);

  /// Obtém a artwork do cache (null = sem capa, ausência = não carregou).
  Uint8List? get(ArtworkKey key) {
    if (!_cache.containsKey(key)) return null;
    final value = _cache.remove(key);
    // Re-inserir no fim para manter LRU
    _cache[key] = value;
    return value;
  }

  /// Armazena no cache.
  void put(ArtworkKey key, Uint8List? data) {
    _cache.remove(key);
    _cache[key] = data;
    _evict();
  }

  /// Está a carregar?
  bool isLoading(ArtworkKey key) => _loading.contains(key);
  void markLoading(ArtworkKey key) => _loading.add(key);
  void markDone(ArtworkKey key) => _loading.remove(key);

  void _evict() {
    while (_cache.length > maxEntries) {
      _cache.remove(_cache.keys.first);
    }
  }

  void clear() {
    _cache.clear();
    _loading.clear();
  }
}

/// Notifier central de artworks.
///
/// Usa on_audio_query para buscar artworks e mantém cache LRU.
/// UI pede artwork via [getArtwork] e escuta [artworkStreamProvider].
///
/// IMPORTANTE: Só faz queries ao on_audio_query depois de [setReady]
/// ser chamado (quando a permissão é concedida e a biblioteca carregada).
/// Isso evita o bug "Reply already submitted" do plugin.
class ArtworkNotifier extends StateNotifier<int> {
  ArtworkNotifier() : super(0);

  final ArtworkCache _cache = ArtworkCache();
  MediaLibraryBackend get _backend => MediaLibrary.instance;

  /// Capas de faixas externas (abertas pelo explorador, fora da biblioteca,
  /// sem MediaStore id). Indexadas pelo `numericId` estável da Song externa.
  /// Têm prioridade sobre o on_audio_query e servem qualquer tamanho pedido.
  final Map<int, Uint8List> _externalArtwork = {};

  /// Indica se a permissão foi concedida e é seguro fazer queries.
  bool _ready = false;

  /// Injeta a capa embebida de uma faixa externa. [bytes] null/vazio remove.
  void setExternalArtwork(int id, Uint8List? bytes) {
    if (id == 0) return;
    if (bytes == null || bytes.isEmpty) {
      _externalArtwork.remove(id);
    } else {
      _externalArtwork[id] = bytes;
    }
    if (mounted) state++;
  }

  /// Chamado quando a permissão é concedida e a biblioteca está carregada.
  void setReady(bool ready) {
    _ready = ready;
    if (ready && mounted) state++;
  }

  /// Obtém artwork em cache, ou retorna null e inicia carregamento.
  Uint8List? getArtwork(int id, ArtworkType type, {int size = 300}) {
    // Capa de faixa externa (explorador) tem prioridade e serve qualquer tamanho.
    final ext = _externalArtwork[id];
    if (ext != null) return ext;

    // Não fazer queries antes da permissão ser concedida
    if (!_ready || id == 0) return null;

    final key = ArtworkKey(id, type, size);

    if (_cache.has(key)) {
      return _cache.get(key);
    }

    // Iniciar carregamento async se não estiver a carregar
    if (!_cache.isLoading(key)) {
      _loadArtwork(key);
    }

    return null;
  }

  Future<void> _loadArtwork(ArtworkKey key) async {
    // Dupla verificação: não carregar se perdeu permissão entre o pedido e aqui
    if (!_ready) return;

    _cache.markLoading(key);
    try {
      final data = await _backend
          .queryArtwork(key.id, key.type, size: key.size, quality: 100)
          .timeout(const Duration(seconds: 5));
      _cache.put(key, data);
    } catch (e) {
      // Inclui TimeoutException — armazena null para não tentar de novo
      debugPrint('[ArtworkNotifier] load error (id=${key.id}): $e');
      _cache.put(key, null);
    } finally {
      _cache.markDone(key);
      // Incrementar state para forçar rebuild dos widgets que escutam
      if (mounted) state++;
    }
  }

  /// Remove do cache todas as entradas de uma música específica (ex: após editar capa).
  void invalidateArtwork(int songId) {
    final keysToRemove = _cache._cache.keys
        .where((k) => k.id == songId)
        .toList();
    for (final k in keysToRemove) {
      _cache._cache.remove(k);
    }
    // Limpa palette cache para este ID
    _paletteCache.remove(songId);
    if (mounted) state++;
  }

  /// Limpa o cache.
  void clearCache() {
    _cache.clear();
    if (mounted) state++;
  }

  /// Cache de palettes extraídas com LRU real (evita re-extração ao revisitar música).
  static final LinkedHashMap<int, ArtworkPalette> _paletteCache =
      LinkedHashMap();
  static const _maxPaletteCache = 100;

  /// Consulta artwork diretamente do device para extração de cor.
  /// Bypassa o cache de artworks (que usa tamanhos variados por widget).
  static Future<Uint8List?> queryArtworkForColor(int id) async {
    try {
      final data = await MediaLibrary.instance.queryArtwork(
        id,
        ArtworkType.AUDIO,
        size: 64,
        quality: 80,
      );
      if (data == null || data.isEmpty) return null;
      return data;
    } catch (e) {
      debugPrint('[ArtworkNotifier] queryArtworkForColor error: $e');
      return null;
    }
  }

  /// Consulta artwork em alta resolução (1024px, JPEG quality 100).
  /// Usado para geração de posters / compartilhamento — onde precisamos
  /// da imagem nítida em telas grandes (1080+).
  static Future<Uint8List?> queryArtworkHighRes(
    int id, {
    ArtworkType type = ArtworkType.AUDIO,
  }) async {
    if (id == 0) return null;
    try {
      final data = await MediaLibrary.instance
          .queryArtwork(id, type, size: 1024, quality: 100)
          .timeout(const Duration(seconds: 6));
      if (data == null || data.isEmpty) return null;
      return data;
    } catch (e) {
      debugPrint('[ArtworkNotifier] queryArtworkHighRes error: $e');
      return null;
    }
  }

  /// Extrai palette completa via histograma HSL (192 buckets).
  /// A decodificação da imagem ocorre na main thread (dart:ui requer root isolate),
  /// mas o cálculo pesado do histograma é delegado a um Isolate via compute(),
  /// garantindo zero jank na UI durante trocas rápidas de faixa.
  static Future<ArtworkPalette?> extractPalette(
    Uint8List bytes, {
    int? songId,
  }) async {
    if (songId != null && _paletteCache.containsKey(songId)) {
      // Move-to-end para manter LRU: entrada mais recentemente usada fica no fim
      final cached = _paletteCache.remove(songId)!;
      _paletteCache[songId] = cached;
      return cached;
    }

    try {
      // ── STEP 1: Decode image → raw RGBA (main thread, GPU-backed) ──
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 64,
        targetHeight: 64,
      );
      final frame = await codec.getNextFrame();
      final bd = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      frame.image.dispose();
      if (bd == null) return null;

      // ── STEP 2: Offload histogram math → background Isolate ──
      final rgbaBytes = bd.buffer.asUint8List(
        bd.offsetInBytes,
        bd.lengthInBytes,
      );
      final palette = await compute(_computePaletteInIsolate, rgbaBytes);
      if (palette == null) return null;

      // ── STEP 3: Cache result (main thread) ──
      if (songId != null) {
        if (_paletteCache.length >= _maxPaletteCache) {
          _paletteCache.remove(_paletteCache.keys.first);
        }
        _paletteCache[songId] = palette;
      }

      return palette;
    } catch (_) {
      return null;
    }
  }
}

// ============================================================
// ISOLATE WORKER — executa o histograma HSL fora da main thread
// ============================================================

/// Função top-level exigida pelo compute().
/// Recebe os bytes RGBA brutos e retorna a palette calculada.
///
/// Todo o trabalho pesado de CPU (scan de pixels, conversão HSL,
/// ranking de buckets, separação de matiz) acontece aqui,
/// liberando a main thread para manter 60/120fps.
ArtworkPalette? _computePaletteInIsolate(Uint8List rgbaBytes) {
  // ── Histogram: 12 hue × 4 sat × 4 lum = 192 buckets ──
  const hBins = 12, sBins = 4, lBins = 4;
  final counts = List<int>.filled(hBins * sBins * lBins, 0);
  final rSums = List<int>.filled(hBins * sBins * lBins, 0);
  final gSums = List<int>.filled(hBins * sBins * lBins, 0);
  final bSums = List<int>.filled(hBins * sBins * lBins, 0);
  final satSums = List<double>.filled(hBins * sBins * lBins, 0);
  // Total por matiz: uma área grande da capa costuma se espalhar por vários
  // buckets de sat/lum; ranquear pela matiz inteira evita que um detalhe
  // pequeno, porém concentrado, "vença" a cor que domina a imagem.
  final hueCounts = List<int>.filled(hBins, 0);

  var total = 0;
  var chromatic = 0;
  var lumSum = 0.0;

  for (int i = 0; i < rgbaBytes.length; i += 4) {
    if (rgbaBytes[i + 3] < 128) continue; // pixels transparentes
    final r = rgbaBytes[i], g = rgbaBytes[i + 1], b = rgbaBytes[i + 2];
    final hsl = HSLColor.fromColor(Color.fromARGB(255, r, g, b));
    total++;
    lumSum += hsl.lightness;
    // Filter achromatic / near-black / near-white
    if (hsl.saturation < 0.12 || hsl.lightness < 0.06 || hsl.lightness > 0.94) {
      continue;
    }
    chromatic++;

    final hi = (hsl.hue / 30.0).floor().clamp(0, hBins - 1);
    final si = (hsl.saturation * sBins).floor().clamp(0, sBins - 1);
    final li = (hsl.lightness * lBins).floor().clamp(0, lBins - 1);
    final idx = hi * sBins * lBins + si * lBins + li;

    counts[idx]++;
    hueCounts[hi]++;
    rSums[idx] += r;
    gSums[idx] += g;
    bSums[idx] += b;
    satSums[idx] += hsl.saturation;
  }

  if (total == 0) return null;

  // ── Capa monocromática (branca, preta, cinza) ──
  // Antes retornava null e a tela mantinha a paleta da música ANTERIOR.
  if (chromatic < total * 0.06) {
    final avgL = lumSum / total;
    Color gray(double l) => HSLColor.fromAHSL(1, 0, 0, l).toColor();
    return ArtworkPalette(
      dominant: gray((avgL * 0.45).clamp(0.10, 0.30)),
      vibrant: gray(avgL > 0.5 ? 0.88 : 0.72),
      muted: gray(0.32),
      secondary: gray((avgL * 0.6).clamp(0.18, 0.45)),
      tertiary: gray(0.14),
    );
  }

  // ── Rank hues by total coverage; representante = bucket mais cheio ──
  final hueOrder = List.generate(hBins, (i) => i)
    ..sort((a, b) => hueCounts[b].compareTo(hueCounts[a]));

  final picked = <Color>[];
  final pickedHues = <double>[];
  final pickedScores = <double>[];

  for (final hi in hueOrder) {
    if (picked.length >= 3) break;
    final share = hueCounts[hi] / chromatic;
    if (share < 0.03) break;

    var best = -1;
    for (var k = hi * sBins * lBins; k < (hi + 1) * sBins * lBins; k++) {
      if (counts[k] > 0 && (best < 0 || counts[k] > counts[best])) best = k;
    }
    if (best < 0) continue;

    final avgColor = Color.fromARGB(
      255,
      rSums[best] ~/ counts[best],
      gSums[best] ~/ counts[best],
      bSums[best] ~/ counts[best],
    );
    final avgHue = HSLColor.fromColor(avgColor).hue;

    bool tooClose = false;
    for (final h in pickedHues) {
      final diff = (avgHue - h).abs();
      if (math.min(diff, 360 - diff) < 40) {
        tooClose = true;
        break;
      }
    }
    if (tooClose) continue;

    picked.add(avgColor);
    pickedHues.add(avgHue);
    // Vívida = saturada E presente na capa; destaques minúsculos não contam.
    final avgSat = satSums[best] / counts[best];
    pickedScores.add(share < 0.15 ? 0 : avgSat * math.sqrt(share));
  }

  if (picked.isEmpty) return null;
  final realCount = picked.length;

  // Fill missing with tonal variants of the main colour (não inventa matizes
  // que a capa não tem).
  while (picked.length < 3) {
    final base = HSLColor.fromColor(picked.first);
    picked.add(
      base
          .withLightness(
            (base.lightness + (picked.length == 1 ? 0.18 : -0.18)).clamp(
              0.12,
              0.80,
            ),
          )
          .toColor(),
    );
    pickedScores.add(0);
  }

  // ── Assign roles ──
  // dominant = most covered hue, darkened
  // vibrant = best saturation × coverage score
  // muted = remaining
  final primary = picked[0];
  final hslPrimary = HSLColor.fromColor(primary);

  int vibrantIdx = 0;
  for (int i = 1; i < realCount; i++) {
    if (pickedScores[i] > pickedScores[vibrantIdx]) vibrantIdx = i;
  }
  final vibrantColor = picked[vibrantIdx];

  // Muted = whichever is not dominant and not vibrant
  final mutedIdx = [0, 1, 2].firstWhere(
    (i) => i != 0 && i != vibrantIdx,
    orElse: () => vibrantIdx == 0 ? 1 : 0,
  );
  final hslMuted = HSLColor.fromColor(picked[mutedIdx]);

  return ArtworkPalette(
    dominant: hslPrimary
        .withLightness((hslPrimary.lightness * 0.45).clamp(0.12, 0.38))
        .withSaturation((hslPrimary.saturation * 1.15).clamp(0.0, 1.0))
        .toColor(),
    vibrant: vibrantColor,
    muted: hslMuted
        .withLightness(hslMuted.lightness.clamp(0.20, 0.45))
        .withSaturation(hslMuted.saturation.clamp(0.0, 0.60))
        .toColor(),
    secondary: picked[1],
    tertiary: picked[2],
  );
}

/// Provider global de artworks.
///
/// O state é um contador que incrementa a cada artwork carregada,
/// forçando rebuild dos ConsumerWidgets que usam ref.watch.
final artworkProvider = StateNotifierProvider<ArtworkNotifier, int>(
  (ref) => ArtworkNotifier(),
);

/// Palette completa da música atual (multi-cor).
final artworkPaletteProvider = StateProvider<ArtworkPalette?>((ref) => null);

/// Cor dominante da capa da música atual (backward-compatible).
/// Derivado automaticamente de artworkPaletteProvider.
final artworkColorProvider = Provider<Color?>((ref) {
  return ref.watch(artworkPaletteProvider)?.dominant;
});
