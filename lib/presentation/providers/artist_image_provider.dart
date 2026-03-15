import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:constanza_player/services/artist_image_service.dart';

/// Cache LRU em memória para URLs de fotos de artistas.
///
/// Mapeia nome do artista (lowercase) → URL da foto.
/// null value = artista sem foto. Ausência no map = não consultou ainda.
class _ArtistImageCache {
  _ArtistImageCache();

  final int maxEntries = 100;
  final LinkedHashMap<String, String?> _cache = LinkedHashMap();
  final Set<String> _loading = {};

  bool has(String key) => _cache.containsKey(key);

  String? get(String key) {
    final value = _cache.remove(key);
    if (value != null || _cache.containsKey(key)) {
      _cache[key] = value; // Re-inserir para LRU
    }
    return value;
  }

  void put(String key, String? url) {
    _cache.remove(key);
    _cache[key] = url;
    _evict();
  }

  bool isLoading(String key) => _loading.contains(key);
  void markLoading(String key) => _loading.add(key);
  void markDone(String key) => _loading.remove(key);

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

/// Notifier para fotos de artistas online (Deezer API).
///
/// Funciona como o ArtworkNotifier: state é um contador que incrementa
/// a cada foto resolvida, forçando rebuild dos widgets.
class ArtistImageNotifier extends StateNotifier<int> {
  ArtistImageNotifier() : super(0);

  final _cache = _ArtistImageCache();
  final _service = ArtistImageService();

  /// Obtém URL da foto do artista.
  /// Retorna null se não disponível ou ainda a carregar.
  /// Inicia fetch assíncrono se não estiver em cache.
  String? getImageUrl(String artistName) {
    final key = artistName.toLowerCase().trim();
    if (key.isEmpty) return null;

    if (_cache.has(key)) {
      return _cache.get(key);
    }

    if (!_cache.isLoading(key)) {
      _fetchImage(key, artistName);
    }

    return null;
  }

  Future<void> _fetchImage(String key, String originalName) async {
    _cache.markLoading(key);
    try {
      final url = await _service.fetchArtistImageUrl(originalName);
      _cache.put(key, url);
    } catch (e) {
      debugPrint('[ArtistImageProvider] ERROR: $e');
      _cache.put(key, null);
    } finally {
      _cache.markDone(key);
      if (mounted) state++;
    }
  }

  /// Pre-fetch múltiplos artistas de uma vez (ex: ao carregar home page).
  void prefetch(List<String> artistNames) {
    for (final name in artistNames) {
      getImageUrl(name);
    }
  }

  void clearCache() {
    _cache.clear();
    if (mounted) state++;
  }
}

/// Provider global de fotos de artistas.
final artistImageProvider = StateNotifierProvider<ArtistImageNotifier, int>(
  (ref) => ArtistImageNotifier(),
);
