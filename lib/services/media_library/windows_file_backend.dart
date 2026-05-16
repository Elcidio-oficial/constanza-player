import 'dart:io';

import 'package:audiotags/audiotags.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:constanza_player/domain/entities/song.dart';
import 'package:constanza_player/domain/entities/album.dart';
import 'package:constanza_player/domain/entities/artist.dart';

import 'media_library_backend.dart';

/// Implementação Windows/Linux/macOS — varre filesystem e lê tags via audiotags.
///
/// Diferenças em relação ao Android:
/// - IDs sintéticos: hash do filePath (estável por path).
/// - artwork: lida direto das tags embedded; fallback para folder.jpg/cover.png.
/// - Sem MediaStore: precisa de pastas configuradas pelo usuário.
class WindowsFileBackend implements MediaLibraryBackend {
  static const _audioExtensions = {
    '.mp3', '.flac', '.m4a', '.aac', '.ogg', '.opus',
    '.wav', '.wma', '.alac', '.aiff',
  };

  // Cache em memória após primeiro scan — evita re-ler todas as tags
  // em cada navegação entre Songs/Albums/Artists.
  List<Song>? _songsCache;
  List<Album>? _albumsCache;
  List<Artist>? _artistsCache;

  // id (hash do filePath) → filePath, para localizar artwork por ID numérico.
  final Map<int, String> _idToPath = {};

  // id (hash do nome do álbum) → filePath de qualquer faixa do álbum,
  // para extrair artwork por ID de álbum.
  final Map<int, String> _albumIdToPath = {};

  List<String> _scanFolders = const [];

  @override
  List<String> get scanFolders => List.unmodifiable(_scanFolders);

  @override
  void indexFromSongs(List<Song> songs) {
    // Reidrata os mapas a partir das músicas que vieram do cache —
    // permite que queryArtwork resolva o caminho do arquivo sem precisar
    // re-escanear o filesystem inteiro.
    for (final s in songs) {
      if (s.filePath.isEmpty) continue;
      final id = int.tryParse(s.id);
      if (id != null && id > 0) {
        _idToPath[id] = s.filePath;
      }
      final albumIdInt = int.tryParse(s.albumId ?? '');
      if (albumIdInt != null && albumIdInt > 0) {
        _albumIdToPath.putIfAbsent(albumIdInt, () => s.filePath);
      }
    }
  }

  @override
  Future<void> setScanFolders(List<String> folders) async {
    _scanFolders = folders;
    // Invalida caches — próxima chamada re-escaneia.
    _songsCache = null;
    _albumsCache = null;
    _artistsCache = null;
    _idToPath.clear();
    _albumIdToPath.clear();
  }

  // ──────────────────────────────────────────────────────────
  // SCAN
  // ──────────────────────────────────────────────────────────

  Future<List<Song>> _scanAll() async {
    if (_songsCache != null) return _songsCache!;

    final folders = _scanFolders.isEmpty
        ? [_defaultMusicFolder()]
        : _scanFolders;

    final result = <Song>[];
    for (final folder in folders) {
      await _scanFolder(folder, result);
    }
    result.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );

    _songsCache = result;
    return result;
  }

  Future<void> _scanFolder(String folder, List<Song> sink) async {
    final dir = Directory(folder);
    if (!await dir.exists()) {
      debugPrint('[WindowsFileBackend] folder not found: $folder');
      return;
    }

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final ext = p.extension(entity.path).toLowerCase();
      if (!_audioExtensions.contains(ext)) continue;

      try {
        final song = await _readSong(entity);
        if (song != null) {
          sink.add(song);
          _idToPath[song.numericId] = entity.path;
          final albumKey = _albumKey(song.album, song.artist);
          _albumIdToPath.putIfAbsent(albumKey, () => entity.path);
        }
      } catch (e) {
        // Tag parse error — ignora arquivo individual sem abortar scan.
        debugPrint('[WindowsFileBackend] skip ${entity.path}: $e');
      }
    }
  }

  Future<Song?> _readSong(File file) async {
    Tag? tag;
    try {
      tag = await AudioTags.read(file.path);
    } catch (_) {
      tag = null;
    }

    final stat = await file.stat();
    final filename = p.basenameWithoutExtension(file.path);

    final title = (tag?.title?.trim().isNotEmpty ?? false)
        ? tag!.title!.trim()
        : _titleFromFilename(filename);
    // Fallback: TPE1 (trackArtist) → TPE2 (albumArtist) → "Desconhecido".
    // Alguns rippers só preenchem o frame de album-artist, deixando o
    // track-artist vazio — sem este fallback a busca de letra online falha.
    final rawArtist = (tag?.trackArtist?.trim().isNotEmpty ?? false)
        ? tag!.trackArtist!.trim()
        : (tag?.albumArtist?.trim().isNotEmpty ?? false)
            ? tag!.albumArtist!.trim()
            : 'Desconhecido';
    final artist = rawArtist;
    final album = (tag?.album?.trim().isNotEmpty ?? false)
        ? tag!.album!.trim()
        : 'Desconhecido';

    final durationSecs = tag?.duration ?? 0;
    final duration = Duration(seconds: durationSecs);

    // Filtra arquivos muito curtos (mesma política do Android: > 10s).
    // Se não conseguimos ler duração, deixa passar — melhor mostrar com 0
    // do que ocultar a música inteira.
    if (durationSecs > 0 && durationSecs < 10) return null;

    final id = _pathHash(file.path);
    final albumId = _albumKey(album, artist);
    final artistId = _stringHash(artist);

    return Song(
      id: id.toString(),
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      // No Windows, uri == filePath absoluto (just_audio.setFilePath).
      uri: file.path,
      filePath: file.path,
      trackNumber: tag?.trackNumber,
      albumId: albumId.toString(),
      artistId: artistId.toString(),
      dateAdded: stat.modified,
      genre: tag?.genre,
      composer: null,
    );
  }

  @override
  Future<List<Song>> scanSongs() => _scanAll();

  @override
  Future<List<Album>> scanAlbums() async {
    if (_albumsCache != null) return _albumsCache!;
    final songs = await _scanAll();

    final byKey = <int, _AlbumAgg>{};
    for (final s in songs) {
      final key = _albumKey(s.album, s.artist);
      byKey.update(
        key,
        (agg) => agg..count += 1,
        ifAbsent: () => _AlbumAgg(
          id: key.toString(),
          name: s.album,
          artist: s.artist,
          count: 1,
        ),
      );
    }

    final result = byKey.values
        .map((a) => Album(
              id: a.id,
              name: a.name,
              artist: a.artist,
              songCount: a.count,
              year: null,
            ))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    _albumsCache = result;
    return result;
  }

  @override
  Future<List<Artist>> scanArtists() async {
    if (_artistsCache != null) return _artistsCache!;
    final songs = await _scanAll();

    final byArtist = <String, _ArtistAgg>{};
    for (final s in songs) {
      final agg = byArtist.putIfAbsent(
        s.artist,
        () => _ArtistAgg(
          id: _stringHash(s.artist).toString(),
          name: s.artist,
        ),
      );
      agg.songs += 1;
      agg.albums.add(s.album);
    }

    final result = byArtist.values
        .map((a) => Artist(
              id: a.id,
              name: a.name,
              songCount: a.songs,
              albumCount: a.albums.length,
            ))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    _artistsCache = result;
    return result;
  }

  // ──────────────────────────────────────────────────────────
  // ARTWORK
  // ──────────────────────────────────────────────────────────

  @override
  Future<Uint8List?> queryArtwork(
    int id,
    ArtworkType type, {
    int size = 300,
    int quality = 80,
  }) async {
    final path = type == ArtworkType.ALBUM
        ? _albumIdToPath[id]
        : _idToPath[id];
    if (path == null) return null;

    // 1) tenta artwork embedded
    try {
      final tag = await AudioTags.read(path);
      final pictures = tag?.pictures;
      if (pictures != null && pictures.isNotEmpty) {
        return Uint8List.fromList(pictures.first.bytes);
      }
    } catch (e) {
      debugPrint('[WindowsFileBackend] tag artwork read failed: $e');
    }

    // 2) fallback: folder.jpg / cover.png / album.jpg na mesma pasta
    final folder = Directory(p.dirname(path));
    const candidates = [
      'folder.jpg', 'folder.jpeg', 'folder.png',
      'cover.jpg', 'cover.jpeg', 'cover.png',
      'album.jpg', 'album.jpeg', 'album.png',
      'front.jpg', 'front.png',
    ];
    for (final name in candidates) {
      final f = File(p.join(folder.path, name));
      if (await f.exists()) {
        try {
          return await f.readAsBytes();
        } catch (_) {}
      }
    }

    return null;
  }

  // ──────────────────────────────────────────────────────────
  // HELPERS
  // ──────────────────────────────────────────────────────────

  /// Limpa nomes de arquivo comuns ("01 - Song.mp3", "01. Song", "01_Song")
  /// para um título mais utilizável em buscas online.
  String _titleFromFilename(String name) {
    var s = name.trim();
    // Remove número de faixa no início: "01 - ", "01. ", "01_", "01 "
    s = s.replaceFirst(RegExp(r'^\d{1,3}\s*[-._)\s]\s*'), '');
    s = s.replaceAll('_', ' ').trim();
    return s.isEmpty ? name : s;
  }

  String _defaultMusicFolder() {
    final userProfile = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        '';
    return p.join(userProfile, 'Music');
  }

  int _albumKey(String album, String artist) =>
      _stringHash('$album|$artist');

  int _pathHash(String path) => _stringHash(path);

  /// Hash determinístico (FNV-1a 32-bit) → garante ID estável entre runs.
  /// Mantém valores positivos para não conflitar com IDs do MediaStore.
  int _stringHash(String s) {
    const fnvPrime = 0x01000193;
    const fnvOffset = 0x811c9dc5;
    int hash = fnvOffset;
    for (final code in s.codeUnits) {
      hash ^= code;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    // Garante > 0 (evita o sentinel 0 = "sem ID" usado no app).
    return hash == 0 ? 1 : hash;
  }
}

class _AlbumAgg {
  _AlbumAgg({
    required this.id,
    required this.name,
    required this.artist,
    required this.count,
  });
  final String id;
  final String name;
  final String artist;
  int count;
}

class _ArtistAgg {
  _ArtistAgg({required this.id, required this.name});
  final String id;
  final String name;
  int songs = 0;
  final Set<String> albums = {};
}
