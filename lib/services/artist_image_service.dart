import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Serviço que busca fotos de artistas via Deezer API.
///
/// Deezer API é gratuita, sem chave, e retorna fotos em várias resoluções:
/// - picture_small: 56x56
/// - picture_medium: 250x250
/// - picture_big: 500x500
/// - picture_xl: 1000x1000
///
/// GET https://api.deezer.com/search/artist?q={name}
class ArtistImageService {
  static const _baseUrl = 'https://api.deezer.com/search/artist';
  static const _timeout = Duration(seconds: 8);

  /// Busca a URL da foto do artista pelo nome.
  ///
  /// Retorna null se não encontrar ou se houver erro de rede.
  Future<String?> fetchArtistImageUrl(
    String artistName, {
    String size = 'picture_xl',
  }) async {
    if (artistName.isEmpty) return null;

    try {
      final uri = Uri.parse(_baseUrl).replace(
        queryParameters: {'q': artistName},
      );

      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode != 200) {
        debugPrint('[ArtistImage] HTTP ${response.statusCode} for "$artistName"');
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final data = json['data'] as List<dynamic>?;

      if (data == null || data.isEmpty) {
        debugPrint('[ArtistImage] No results for "$artistName"');
        return null;
      }

      // Procurar match exato pelo nome (case-insensitive)
      final normalizedQuery = artistName.toLowerCase().trim();
      Map<String, dynamic>? bestMatch;

      for (final item in data) {
        final name = (item['name'] as String?)?.toLowerCase().trim() ?? '';
        if (name == normalizedQuery) {
          bestMatch = item as Map<String, dynamic>;
          break;
        }
      }

      // Fallback: primeiro resultado (Deezer faz fuzzy search)
      bestMatch ??= data.first as Map<String, dynamic>;

      final imageUrl = bestMatch[size] as String?;

      // Deezer retorna URL padrão "sem foto" com este padrão
      if (imageUrl == null || imageUrl.contains('/images/artist//')) {
        debugPrint('[ArtistImage] No photo available for "$artistName"');
        return null;
      }

      debugPrint('[ArtistImage] Found photo for "$artistName"');
      return imageUrl;
    } catch (e) {
      debugPrint('[ArtistImage] ERROR for "$artistName": $e');
      return null;
    }
  }
}
