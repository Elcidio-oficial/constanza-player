// ignore_for_file: unnecessary_import

import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart';

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
    final value = _cache.remove(key);
    if (value != null || _cache.containsKey(key)) {
      // Re-inserir no fim para manter LRU
      _cache[key] = value;
    }
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
  final OnAudioQuery _audioQuery = OnAudioQuery();

  /// Indica se a permissão foi concedida e é seguro fazer queries.
  bool _ready = false;

  /// Chamado quando a permissão é concedida e a biblioteca está carregada.
  void setReady(bool ready) {
    _ready = ready;
    if (ready && mounted) state++;
  }

  /// Obtém artwork em cache, ou retorna null e inicia carregamento.
  Uint8List? getArtwork(int id, ArtworkType type, {int size = 300}) {
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
      final data = await _audioQuery.queryArtwork(
        key.id,
        key.type,
        size: key.size,
        quality: 100,
      );
      _cache.put(key, data);
    } catch (_) {
      _cache.put(key, null);
    } finally {
      _cache.markDone(key);
      // Incrementar state para forçar rebuild dos widgets que escutam
      if (mounted) state++;
    }
  }

  /// Limpa o cache.
  void clearCache() {
    _cache.clear();
    if (mounted) state++;
  }

  /// Cache de palettes extraídas (evita re-extração ao revisitar música).
  static final Map<int, ArtworkPalette> _paletteCache = {};
  static const _maxPaletteCache = 100;

  /// Consulta artwork diretamente do device para extração de cor.
  /// Bypassa o cache de artworks (que usa tamanhos variados por widget).
  static Future<Uint8List?> queryArtworkForColor(int id) async {
    try {
      final data = await OnAudioQuery().queryArtwork(
        id, ArtworkType.AUDIO, size: 64, quality: 80,
      );
      if (data == null || data.isEmpty) return null;
      return data;
    } catch (_) {
      return null;
    }
  }

  /// Extrai palette completa via histograma HSL (192 buckets).
  /// Retorna ArtworkPalette com dominant/vibrant/muted/secondary/tertiary.
  static Future<ArtworkPalette?> extractPalette(Uint8List bytes, {int? songId}) async {
    if (songId != null && _paletteCache.containsKey(songId)) {
      return _paletteCache[songId];
    }

    try {
      final codec = await ui.instantiateImageCodec(
        bytes, targetWidth: 64, targetHeight: 64,
      );
      final frame = await codec.getNextFrame();
      final bd = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
      frame.image.dispose();
      if (bd == null) return null;

      // ── Histogram: 12 hue × 4 sat × 4 lum = 192 buckets ──
      const hBins = 12, sBins = 4, lBins = 4;
      final counts = List<int>.filled(hBins * sBins * lBins, 0);
      final rSums = List<int>.filled(hBins * sBins * lBins, 0);
      final gSums = List<int>.filled(hBins * sBins * lBins, 0);
      final bSums = List<int>.filled(hBins * sBins * lBins, 0);
      final satSums = List<double>.filled(hBins * sBins * lBins, 0);

      for (int i = 0; i < bd.lengthInBytes; i += 4) {
        final r = bd.getUint8(i), g = bd.getUint8(i + 1), b = bd.getUint8(i + 2);
        final c = Color.fromARGB(255, r, g, b);
        final hsl = HSLColor.fromColor(c);
        // Filter achromatic / near-black / near-white
        if (hsl.saturation < 0.10 || hsl.lightness < 0.05 || hsl.lightness > 0.95) continue;

        final hi = (hsl.hue / 30.0).floor().clamp(0, hBins - 1);
        final si = (hsl.saturation * sBins).floor().clamp(0, sBins - 1);
        final li = (hsl.lightness * lBins).floor().clamp(0, lBins - 1);
        final idx = hi * sBins * lBins + si * lBins + li;

        counts[idx]++;
        rSums[idx] += r;
        gSums[idx] += g;
        bSums[idx] += b;
        satSums[idx] += hsl.saturation;
      }

      // ── Rank buckets by pixel count ──
      final indices = List.generate(counts.length, (i) => i);
      indices.sort((a, b) => counts[b].compareTo(counts[a]));

      // ── Pick top 3 buckets with hue separation ≥ 40° ──
      final picked = <Color>[];
      final pickedHues = <double>[];
      final pickedSats = <double>[];

      for (final idx in indices) {
        if (picked.length >= 3) break;
        if (counts[idx] == 0) break;

        final avgR = rSums[idx] ~/ counts[idx];
        final avgG = gSums[idx] ~/ counts[idx];
        final avgB = bSums[idx] ~/ counts[idx];
        final avgSat = satSums[idx] / counts[idx];
        final avgColor = Color.fromARGB(255, avgR, avgG, avgB);
        final avgHue = HSLColor.fromColor(avgColor).hue;

        bool tooClose = false;
        for (final h in pickedHues) {
          final diff = (avgHue - h).abs();
          if (math.min(diff, 360 - diff) < 40) { tooClose = true; break; }
        }
        if (tooClose) continue;

        picked.add(avgColor);
        pickedHues.add(avgHue);
        pickedSats.add(avgSat);
      }

      if (picked.isEmpty) return null;

      // Fill missing with hue-shifted variants
      while (picked.length < 3) {
        final base = HSLColor.fromColor(picked.first);
        final shift = picked.length == 1 ? 120.0 : 240.0;
        picked.add(base
            .withHue((base.hue + shift) % 360)
            .withSaturation((base.saturation * 0.85).clamp(0.3, 1.0))
            .toColor());
        pickedSats.add(base.saturation * 0.85);
      }

      // ── Assign roles ──
      // dominant = largest bucket (already picked[0]), darkened
      // vibrant = bucket with highest average saturation
      // muted = remaining
      final primary = picked[0];
      final hslPrimary = HSLColor.fromColor(primary);

      // Find most vibrant among the 3
      int vibrantIdx = 0;
      for (int i = 1; i < picked.length; i++) {
        if (pickedSats[i] > pickedSats[vibrantIdx]) vibrantIdx = i;
      }
      final vibrantColor = picked[vibrantIdx];

      // Muted = whichever is not dominant and not vibrant
      final mutedIdx = [0, 1, 2].firstWhere(
        (i) => i != 0 && i != vibrantIdx,
        orElse: () => 0,
      );

      final palette = ArtworkPalette(
        dominant: hslPrimary
            .withLightness((hslPrimary.lightness * 0.45).clamp(0.12, 0.38))
            .withSaturation((hslPrimary.saturation * 1.3).clamp(0.30, 1.0))
            .toColor(),
        vibrant: vibrantColor,
        muted: HSLColor.fromColor(picked[mutedIdx])
            .withLightness(HSLColor.fromColor(picked[mutedIdx]).lightness.clamp(0.20, 0.45))
            .withSaturation(HSLColor.fromColor(picked[mutedIdx]).saturation.clamp(0.15, 0.60))
            .toColor(),
        secondary: picked.length > 1 ? picked[1] : null,
        tertiary: picked.length > 2 ? picked[2] : null,
      );

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
