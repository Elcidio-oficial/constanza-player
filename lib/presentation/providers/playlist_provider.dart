import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path_provider/path_provider.dart';
import 'package:constanza_player/domain/entities/playlist.dart';
import 'package:constanza_player/domain/entities/song.dart';
import 'package:constanza_player/services/settings_storage_service.dart';

// ============================================================
// PLAYLIST NOTIFIER — com persistência e imagens
// ============================================================

class PlaylistNotifier extends StateNotifier<List<Playlist>> {
  PlaylistNotifier() : super(_initialPlaylists);

  /// Contagem de reproduções por songId.
  Map<String, int> _playCounts = {};

  /// Histórico de reprodução.
  List<Map<String, dynamic>> _history = [];

  List<Map<String, dynamic>> get playHistory => List.unmodifiable(_history);

  Map<String, int> get playCounts => Map.unmodifiable(_playCounts);

  /// Mapa de songIds salvos por playlist (para restauração).
  Map<String, List<String>> _savedSongIds = {};

  static List<Playlist> get _initialPlaylists {
    final now = DateTime.now();
    return [
      Playlist(
        id: 'fav',
        name: 'Favoritas',
        isSmartPlaylist: true,
        createdAt: now,
        updatedAt: now,
      ),
      Playlist(
        id: 'recent',
        name: 'Tocadas Recentemente',
        isSmartPlaylist: true,
        createdAt: now,
        updatedAt: now,
      ),
      Playlist(
        id: 'most',
        name: 'Mais Tocadas',
        isSmartPlaylist: true,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }

  // ── PERSISTÊNCIA ──

  /// Carrega playlists do usuário do storage.
  void loadFromStorage() {
    // Always load history and play counts
    _history = SettingsStorageService.loadHistory();
    _playCounts = SettingsStorageService.loadPlayCounts();

    final json = SettingsStorageService.loadUserPlaylists();
    if (json == null) return;
    try {
      final list = jsonDecode(json) as List;
      final loaded = <Playlist>[];
      final songIdMap = <String, List<String>>{};
      for (final item in list) {
        final map = item as Map<String, dynamic>;
        final pl = Playlist.fromJson(map);
        if (!pl.isSmartPlaylist && pl.id.isNotEmpty) {
          loaded.add(pl);
          songIdMap[pl.id] = Playlist.songIdsFromJson(map);
        }
      }
      _savedSongIds = songIdMap;
      // Merge com smart playlists
      state = [...state.where((p) => p.isSmartPlaylist), ...loaded];
    } catch (e) {
      debugPrint('[PlaylistNotifier] loadFromStorage parse error: $e');
    }
  }

  /// Restaura as músicas das playlists usando a biblioteca completa.
  void restoreSongsFromLibrary(List<Song> allSongs) {
    if (_savedSongIds.isEmpty) return;
    final songMap = {for (final s in allSongs) s.id: s};
    state = state.map((p) {
      if (p.isSmartPlaylist) return p;
      final ids = _savedSongIds[p.id];
      if (ids == null || ids.isEmpty) return p;
      final resolved = ids.map((id) => songMap[id]).nonNulls.toList();
      return p.copyWith(songs: resolved);
    }).toList();
    _savedSongIds.clear();
  }

  Future<void> _persist() async {
    try {
      final userPlaylists = state.where((p) => !p.isSmartPlaylist).toList();
      final json = jsonEncode(userPlaylists.map((p) => p.toJson()).toList());
      await SettingsStorageService.saveUserPlaylists(json);
    } catch (e) {
      debugPrint('[PlaylistNotifier] persist error: $e');
    }
  }

  // ── CRUD ──

  /// Criar nova playlist.
  void createPlaylist(String name, {String? description}) {
    final now = DateTime.now();
    final newPlaylist = Playlist(
      id: 'p_${now.millisecondsSinceEpoch}_${state.length}',
      name: name,
      description: description,
      createdAt: now,
      updatedAt: now,
    );
    state = [...state, newPlaylist];
    _persist();
  }

  /// Deletar playlist (não permite deletar smart playlists).
  void deletePlaylist(String id) {
    final pl = state.where((p) => p.id == id && !p.isSmartPlaylist).firstOrNull;
    if (pl == null) return; // Playlist not found or is smart — do nothing
    if (pl.hasCustomImage) {
      try {
        File(pl.imagePath!).deleteSync();
      } catch (_) {}
    }
    state = state.where((p) => p.id != id).toList();
    _persist();
  }

  /// Renomear playlist.
  void renamePlaylist(String id, String newName) {
    state = state.map((p) {
      if (p.id == id && !p.isSmartPlaylist) {
        return p.copyWith(name: newName, updatedAt: DateTime.now());
      }
      return p;
    }).toList();
    _persist();
  }

  /// Atualizar descrição da playlist.
  void updateDescription(String id, String description) {
    state = state.map((p) {
      if (p.id == id && !p.isSmartPlaylist) {
        return p.copyWith(
          description: description,
          updatedAt: DateTime.now(),
          clearDescription: description.isEmpty,
        );
      }
      return p;
    }).toList();
    _persist();
  }

  /// Definir imagem personalizada da playlist.
  Future<void> setPlaylistImage(String id, String sourcePath) async {
    final dir = await getApplicationDocumentsDirectory();
    final ext = sourcePath.split('.').last;
    final destPath =
        '${dir.path}/playlist_images/${id}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final destDir = Directory('${dir.path}/playlist_images');
    if (!destDir.existsSync()) destDir.createSync(recursive: true);

    // Remove imagem antiga se existir e limpa cache de imagem do Flutter
    final oldPl = state.where((p) => p.id == id).firstOrNull ?? state.first;
    if (oldPl.hasCustomImage) {
      // Evict via provider + global imageCache para garantir que nenhum
      // widget com referência antiga continue exibindo a imagem excluída
      FileImage(File(oldPl.imagePath!)).evict();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      try {
        File(oldPl.imagePath!).deleteSync();
      } catch (_) {}
    }

    // Copia arquivo
    await File(sourcePath).copy(destPath);

    state = state.map((p) {
      if (p.id == id) {
        return p.copyWith(imagePath: destPath, updatedAt: DateTime.now());
      }
      return p;
    }).toList();
    _persist();
  }

  /// Remove imagem personalizada da playlist.
  void removePlaylistImage(String id) {
    final pl = state.where((p) => p.id == id).firstOrNull;
    if (pl == null) return;
    if (pl.hasCustomImage) {
      try {
        File(pl.imagePath!).deleteSync();
      } catch (_) {}
    }
    state = state.map((p) {
      if (p.id == id) {
        return p.copyWith(clearImage: true, updatedAt: DateTime.now());
      }
      return p;
    }).toList();
    _persist();
  }

  /// Adicionar música a uma playlist.
  void addSongToPlaylist(String playlistId, Song song) {
    state = state.map((p) {
      if (p.id == playlistId) {
        if (p.songs.any((s) => s.id == song.id)) return p;
        return p.copyWith(songs: [...p.songs, song], updatedAt: DateTime.now());
      }
      return p;
    }).toList();
    _persist();
  }

  /// Registrar reprodução de uma música.
  void trackPlay(Song song) {
    _playCounts[song.id] = (_playCounts[song.id] ?? 0) + 1;
    final now = DateTime.now();
    state = state.map((p) {
      if (p.id == 'recent') {
        final updated = [
          song,
          ...p.songs.where((s) => s.id != song.id),
        ].take(50).toList();
        return p.copyWith(songs: updated, updatedAt: now);
      }
      if (p.id == 'most') {
        final allSongs = <String, Song>{for (final s in p.songs) s.id: s};
        allSongs[song.id] = song;
        final sorted = allSongs.values.toList()
          ..sort(
            (a, b) =>
                (_playCounts[b.id] ?? 0).compareTo(_playCounts[a.id] ?? 0),
          );
        return p.copyWith(songs: sorted.take(50).toList(), updatedAt: now);
      }
      return p;
    }).toList();

    // Save history entry
    _history.insert(0, {
      'songId': song.id,
      'title': song.title,
      'artist': song.artist,
      'album': song.album,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    if (_history.length > 500) _history = _history.sublist(0, 500);
    // Fire-and-forget persistence — errors logged, never crash
    SettingsStorageService.saveHistory(
      _history,
    ).timeout(const Duration(seconds: 5)).catchError((e) {
      debugPrint('[PlaylistNotifier] saveHistory error: $e');
    });
    SettingsStorageService.savePlayCounts(
      _playCounts,
    ).timeout(const Duration(seconds: 5)).catchError((e) {
      debugPrint('[PlaylistNotifier] savePlayCounts error: $e');
    });
  }

  /// Limpar histórico de reprodução.
  void clearHistory() {
    _history.clear();
    SettingsStorageService.saveHistory(_history);
    state = [...state]; // trigger rebuild
  }

  /// Export playlist as M3U format string.
  String exportPlaylistM3U(String playlistId) {
    final playlist = state.where((p) => p.id == playlistId).firstOrNull;
    if (playlist == null) return '';
    final buf = StringBuffer('#EXTM3U\n#PLAYLIST:${playlist.name}\n');
    for (final song in playlist.songs) {
      final secs = song.duration.inSeconds;
      buf.writeln('#EXTINF:$secs,${song.artist} - ${song.title}');
      buf.writeln(song.filePath.isNotEmpty ? song.filePath : song.uri);
    }
    return buf.toString();
  }

  /// Sincroniza a playlist "Favoritas".
  void syncFavorites(List<Song> allSongs) {
    final favs = allSongs.where((s) => s.isFavorite).toList();
    state = state.map((p) {
      if (p.id == 'fav') {
        return p.copyWith(songs: favs, updatedAt: DateTime.now());
      }
      return p;
    }).toList();
  }

  /// Remover música de uma playlist.
  void removeSongFromPlaylist(String playlistId, String songId) {
    state = state.map((p) {
      if (p.id == playlistId && !p.isSmartPlaylist) {
        return p.copyWith(
          songs: p.songs.where((s) => s.id != songId).toList(),
          updatedAt: DateTime.now(),
        );
      }
      return p;
    }).toList();
    _persist();
  }

  /// Reordenar músicas na playlist.
  void reorderSongs(String playlistId, int oldIndex, int newIndex) {
    state = state.map((p) {
      if (p.id == playlistId && !p.isSmartPlaylist) {
        final list = [...p.songs];
        if (oldIndex < 0 || oldIndex >= list.length) return p;
        if (newIndex > oldIndex) newIndex--;
        if (newIndex < 0 || newIndex > list.length) return p;
        final item = list.removeAt(oldIndex);
        list.insert(newIndex, item);
        return p.copyWith(songs: list, updatedAt: DateTime.now());
      }
      return p;
    }).toList();
    _persist();
  }
}

/// Provider global das playlists.
final playlistProvider =
    StateNotifierProvider<PlaylistNotifier, List<Playlist>>(
      (ref) => PlaylistNotifier(),
    );

/// Smart playlists separadas.
final smartPlaylistsProvider = Provider<List<Playlist>>((ref) {
  return ref.watch(playlistProvider).where((p) => p.isSmartPlaylist).toList();
});

/// Playlists do usuário separadas.
final userPlaylistsProvider = Provider<List<Playlist>>((ref) {
  return ref.watch(playlistProvider).where((p) => !p.isSmartPlaylist).toList();
});

/// Histórico de reprodução.
final playHistoryProvider = Provider<List<Map<String, dynamic>>>((ref) {
  ref.watch(playlistProvider);
  return ref.read(playlistProvider.notifier).playHistory;
});

/// Contagem de reproduções por songId.
final playCountsProvider = Provider<Map<String, int>>((ref) {
  ref.watch(playlistProvider);
  return ref.read(playlistProvider.notifier).playCounts;
});
