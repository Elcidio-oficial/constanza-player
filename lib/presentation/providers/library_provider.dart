import 'dart:developer' as dev;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:constanza_player/domain/entities/song.dart';
import 'package:constanza_player/domain/entities/album.dart';
import 'package:constanza_player/domain/entities/artist.dart';
import 'package:constanza_player/services/audio_scanner_service.dart';
import 'package:constanza_player/services/permission_service.dart';
import 'package:constanza_player/services/settings_storage_service.dart';

/// Estado da biblioteca.
enum LibraryStatus { initial, loading, loaded, noPermission, empty, error, needsFolderSetup }

/// Ordenação padrão da biblioteca.
enum SortOrder { title, artist, album, dateAdded, duration }

class LibraryState {
  LibraryState({
    this.status = LibraryStatus.initial,
    this.songs = const [],
    this.albums = const [],
    this.artists = const [],
    this.errorMessage,
    this.sortOrder = SortOrder.title,
    this.filterShortTracks = false,
    this.allFolders = const [],
    this.selectedFolders = const [],
  });

  final LibraryStatus status;
  final List<Song> songs;
  final List<Album> albums;
  final List<Artist> artists;
  final String? errorMessage;
  final SortOrder sortOrder;
  final bool filterShortTracks;

  /// Todas as pastas descobertas no scan.
  final List<String> allFolders;

  /// Pastas selecionadas pelo usuário.
  final List<String> selectedFolders;

  List<String> get genres {
    final set = <String>{};
    for (final s in songs) {
      if (s.genre != null && s.genre!.isNotEmpty) set.add(s.genre!);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<String> get composers {
    final set = <String>{};
    for (final s in songs) {
      if (s.composer != null && s.composer!.isNotEmpty) set.add(s.composer!);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<Song> songsByGenre(String genre) => songs.where((s) => s.genre == genre).toList();
  List<Song> songsByComposer(String composer) => songs.where((s) => s.composer == composer).toList();

  bool get isLoaded => status == LibraryStatus.loaded;
  bool get isLoading => status == LibraryStatus.loading;
  bool get hasContent => songs.isNotEmpty;

  /// Label para o tile de pastas.
  String get foldersLabel {
    if (selectedFolders.isEmpty) return 'Nenhuma pasta selecionada';
    return '${selectedFolders.length} pasta${selectedFolders.length == 1 ? '' : 's'} selecionada${selectedFolders.length == 1 ? '' : 's'}';
  }

  /// Músicas ordenadas e filtradas conforme as settings (memoizado).
  List<Song>? _sortedSongsCache;
  List<Song> get sortedSongs {
    if (_sortedSongsCache != null) return _sortedSongsCache!;
    var result = List<Song>.of(songs);

    // Filtrar faixas curtas (< 30s) se ativado
    if (filterShortTracks) {
      result = result.where((s) => s.duration.inSeconds >= 30).toList();
    }

    // Ordenar
    switch (sortOrder) {
      case SortOrder.title:
        result.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case SortOrder.artist:
        result.sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
      case SortOrder.album:
        result.sort((a, b) => a.album.toLowerCase().compareTo(b.album.toLowerCase()));
      case SortOrder.dateAdded:
        result.sort((a, b) {
          final aDate = a.dateAdded ?? DateTime(1970);
          final bDate = b.dateAdded ?? DateTime(1970);
          return bDate.compareTo(aDate); // Mais recente primeiro
        });
      case SortOrder.duration:
        result.sort((a, b) => a.duration.compareTo(b.duration));
    }

    _sortedSongsCache = result;
    return result;
  }

  String get sortOrderLabel => switch (sortOrder) {
    SortOrder.title => 'Título',
    SortOrder.artist => 'Artista',
    SortOrder.album => 'Álbum',
    SortOrder.dateAdded => 'Data adicionada',
    SortOrder.duration => 'Duração',
  };

  LibraryState copyWith({
    LibraryStatus? status,
    List<Song>? songs,
    List<Album>? albums,
    List<Artist>? artists,
    String? errorMessage,
    SortOrder? sortOrder,
    bool? filterShortTracks,
    List<String>? allFolders,
    List<String>? selectedFolders,
  }) {
    return LibraryState(
      status: status ?? this.status,
      songs: songs ?? this.songs,
      albums: albums ?? this.albums,
      artists: artists ?? this.artists,
      errorMessage: errorMessage ?? this.errorMessage,
      sortOrder: sortOrder ?? this.sortOrder,
      filterShortTracks: filterShortTracks ?? this.filterShortTracks,
      allFolders: allFolders ?? this.allFolders,
      selectedFolders: selectedFolders ?? this.selectedFolders,
    );
  }
}

class LibraryNotifier extends StateNotifier<LibraryState> {
  LibraryNotifier() : super(LibraryState()) {
    _loadSettings();
  }

  final _scanner = AudioScannerService();

  /// Músicas do último scan completo (antes de filtrar por pastas).
  List<Song> _allScannedSongs = [];

  // IDs de favoritos persistidos (carregados antes do scan)
  Set<String> _savedFavoriteIds = {};

  void _loadSettings() {
    final json = SettingsStorageService.loadLibrarySettings();
    if (json != null) {
      state = state.copyWith(
        sortOrder: SortOrder.values[json['sortOrder'] as int? ?? 0],
        filterShortTracks: json['filterShortTracks'] as bool? ?? false,
      );
    }
    _savedFavoriteIds = SettingsStorageService.loadFavorites();
    // Carregar pastas selecionadas
    final savedFolders = SettingsStorageService.loadMusicFolders();
    if (savedFolders != null) {
      state = state.copyWith(selectedFolders: savedFolders);
    }
  }

  void _saveSettings() {
    SettingsStorageService.saveLibrarySettings({
      'sortOrder': state.sortOrder.index,
      'filterShortTracks': state.filterShortTracks,
    });
  }

  /// Inicializa — carrega do cache se existir, senão pede seleção de pastas.
  Future<void> initialize() async {
    state = state.copyWith(status: LibraryStatus.loading);

    // Tentar carregar do cache primeiro
    if (SettingsStorageService.hasLibraryCache) {
      final loaded = _loadFromCache();
      if (loaded) {
        dev.log('Library: loaded ${state.songs.length} songs from cache');
        return;
      }
    }

    // Sem cache — verificar permissão
    final hasPermission = await PermissionService.hasAudioPermission();
    if (!hasPermission) {
      final granted = await PermissionService.requestAudioPermission();
      if (!granted) {
        state = state.copyWith(status: LibraryStatus.noPermission);
        return;
      }
    }

    // Verificar se pastas foram configuradas anteriormente
    final savedFolders = SettingsStorageService.loadMusicFolders();
    if (savedFolders != null && savedFolders.isNotEmpty) {
      await _scanWithFolders(savedFolders);
      return;
    }

    // Primeira vez — precisa selecionar pastas
    state = state.copyWith(status: LibraryStatus.needsFolderSetup);
  }

  /// Re-escaneia a biblioteca (usa pastas selecionadas).
  Future<void> rescan() async {
    state = state.copyWith(status: LibraryStatus.loading);
    final folders = state.selectedFolders;
    if (folders.isNotEmpty) {
      await _scanWithFolders(folders);
    } else {
      state = state.copyWith(status: LibraryStatus.needsFolderSetup);
    }
  }

  /// Solicita permissão novamente.
  Future<void> retryPermission() async {
    final isPermanent = await PermissionService.isPermanentlyDenied();
    if (isPermanent) {
      await PermissionService.openSettings();
      return;
    }

    state = state.copyWith(status: LibraryStatus.loading);
    final granted = await PermissionService.requestAudioPermission();
    if (granted) {
      final savedFolders = SettingsStorageService.loadMusicFolders();
      if (savedFolders != null && savedFolders.isNotEmpty) {
        await _scanWithFolders(savedFolders);
      } else {
        state = state.copyWith(status: LibraryStatus.needsFolderSetup);
      }
    } else {
      state = state.copyWith(status: LibraryStatus.noPermission);
    }
  }

  /// Muda a ordenação padrão.
  void setSortOrder(SortOrder order) {
    state = state.copyWith(sortOrder: order);
    _saveSettings();
  }

  /// Toggle filtro de faixas curtas.
  void toggleFilterShortTracks() {
    state = state.copyWith(filterShortTracks: !state.filterShortTracks);
    _saveSettings();
  }

  /// Define as pastas selecionadas, escaneia e filtra músicas.
  Future<void> setSelectedFolders(List<String> folders) async {
    state = state.copyWith(selectedFolders: folders, status: LibraryStatus.loading);
    await SettingsStorageService.saveMusicFolders(folders);

    if (folders.isEmpty) {
      state = state.copyWith(
        status: LibraryStatus.needsFolderSetup,
        songs: [],
        albums: [],
        artists: [],
      );
      return;
    }

    if (_allScannedSongs.isNotEmpty) {
      await _applyFolderFilter(folders);
    } else {
      await _scanWithFolders(folders);
    }
  }

  /// Escaneia o dispositivo para descobrir todas as pastas com músicas.
  /// Retorna contagem de músicas por pasta para o picker UI.
  Future<Map<String, int>> discoverFolders() async {
    final hasPermission = await PermissionService.hasAudioPermission();
    if (!hasPermission) {
      final granted = await PermissionService.requestAudioPermission();
      if (!granted) return {};
    }

    try {
      _allScannedSongs = await _scanner.scanSongs();
      final folders = _extractFolders(_allScannedSongs);
      state = state.copyWith(allFolders: folders);

      final countMap = <String, int>{};
      for (final s in _allScannedSongs) {
        final f = s.folderPath;
        if (f.isNotEmpty) countMap[f] = (countMap[f] ?? 0) + 1;
      }
      return countMap;
    } catch (e) {
      dev.log('Folder discovery failed: $e');
      return {};
    }
  }

  /// Toggle favorito de uma música (persiste automaticamente).
  void toggleFavorite(String songId) {
    state = state.copyWith(
      songs: state.songs.map((s) {
        if (s.id == songId) return s.copyWith(isFavorite: !s.isFavorite);
        return s;
      }).toList(),
    );
    // Atualiza cache e persiste
    final favoriteIds = state.songs
        .where((s) => s.isFavorite)
        .map((s) => s.id)
        .toSet();
    _savedFavoriteIds = favoriteIds;
    SettingsStorageService.saveFavorites(favoriteIds);
  }

  /// Carrega biblioteca do cache local.
  bool _loadFromCache() {
    try {
      final cache = SettingsStorageService.loadLibraryCache();
      if (cache == null) return false;

      final songsJson = (cache['songs'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final albumsJson = (cache['albums'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final artistsJson = (cache['artists'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      if (songsJson.isEmpty) return false;

      final songs = songsJson.map(Song.fromJson).toList();
      final albums = albumsJson.map(Album.fromJson).toList();
      final artists = artistsJson.map(Artist.fromJson).toList();

      // Extrair pastas únicas (do cache = apenas pastas selecionadas)
      final folders = _extractFolders(songs);

      // Restaurar favoritos persistidos
      final ids = _savedFavoriteIds;
      final restored = ids.isEmpty
          ? songs
          : songs.map((s) => ids.contains(s.id) ? s.copyWith(isFavorite: true) : s).toList();

      state = state.copyWith(
        status: LibraryStatus.loaded,
        songs: restored,
        albums: albums,
        artists: artists,
        allFolders: folders,
      );
      return true;
    } catch (e) {
      dev.log('Library cache load failed: $e');
      return false;
    }
  }

  /// Salva biblioteca no cache local.
  Future<void> _saveToCache(List<Song> songs, List<Album> albums, List<Artist> artists) async {
    await SettingsStorageService.saveLibraryCache({
      'songs': songs.map((s) => s.toJson()).toList(),
      'albums': albums.map((a) => a.toJson()).toList(),
      'artists': artists.map((a) => a.toJson()).toList(),
    });
  }

  /// Extrai pastas únicas das músicas, ordenadas por nome.
  List<String> _extractFolders(List<Song> songs) {
    final folders = <String>{};
    for (final s in songs) {
      final f = s.folderPath;
      if (f.isNotEmpty) folders.add(f);
    }
    final sorted = folders.toList()..sort();
    return sorted;
  }

  /// Escaneia e filtra por pastas selecionadas.
  Future<void> _scanWithFolders(List<String> folders) async {
    try {
      final hasPermission = await PermissionService.hasAudioPermission();
      if (!hasPermission) {
        final granted = await PermissionService.requestAudioPermission();
        if (!granted) {
          state = state.copyWith(status: LibraryStatus.noPermission);
          return;
        }
      }

      _allScannedSongs = await _scanner.scanSongs();
      await _applyFolderFilter(folders);
    } catch (e) {
      state = state.copyWith(
        status: LibraryStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Filtra músicas escaneadas por pastas e atualiza estado + cache.
  Future<void> _applyFolderFilter(List<String> folders) async {
    final folderSet = Set<String>.from(folders);
    final filtered = _allScannedSongs
        .where((s) => folderSet.contains(s.folderPath))
        .toList();

    if (filtered.isEmpty) {
      state = state.copyWith(
        status: LibraryStatus.empty,
        songs: [],
        albums: [],
        artists: [],
        allFolders: _extractFolders(_allScannedSongs),
      );
      return;
    }

    final albums = _buildAlbumsFromSongs(filtered);
    final artists = _buildArtistsFromSongs(filtered);

    // Restaurar favoritos persistidos
    final ids = _savedFavoriteIds;
    final restored = ids.isEmpty
        ? filtered
        : filtered.map((s) => ids.contains(s.id) ? s.copyWith(isFavorite: true) : s).toList();

    state = state.copyWith(
      status: LibraryStatus.loaded,
      songs: restored,
      albums: albums,
      artists: artists,
      allFolders: _extractFolders(_allScannedSongs),
    );

    await _saveToCache(restored, albums, artists);
    dev.log('Library: filtered ${restored.length} songs from ${folders.length} folders');
  }

  /// Constrói lista de álbuns a partir das músicas filtradas.
  List<Album> _buildAlbumsFromSongs(List<Song> songs) {
    final albumMap = <String, List<Song>>{};
    for (final s in songs) {
      final aid = s.albumId;
      if (aid != null && aid.isNotEmpty) {
        albumMap.putIfAbsent(aid, () => []).add(s);
      }
    }
    return albumMap.entries.map((e) {
      final first = e.value.first;
      return Album(
        id: first.albumId!,
        name: first.album,
        artist: first.artist,
        songCount: e.value.length,
      );
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  /// Constrói lista de artistas a partir das músicas filtradas.
  List<Artist> _buildArtistsFromSongs(List<Song> songs) {
    final artistMap = <String, List<Song>>{};
    for (final s in songs) {
      final aid = s.artistId;
      if (aid != null && aid.isNotEmpty) {
        artistMap.putIfAbsent(aid, () => []).add(s);
      }
    }
    return artistMap.entries.map((e) {
      final first = e.value.first;
      final albumIds = e.value
          .map((s) => s.albumId)
          .whereType<String>()
          .toSet();
      return Artist(
        id: first.artistId!,
        name: first.artist,
        songCount: e.value.length,
        albumCount: albumIds.length,
      );
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }
}

/// Provider global da biblioteca.
final libraryProvider = StateNotifierProvider<LibraryNotifier, LibraryState>(
  (ref) => LibraryNotifier(),
);
