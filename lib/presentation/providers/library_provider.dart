import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:constanza_player/l10n/gen/app_localizations.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:constanza_player/domain/entities/song.dart';
import 'package:constanza_player/domain/entities/album.dart';
import 'package:constanza_player/domain/entities/artist.dart';
import 'package:constanza_player/services/audio_scanner_service.dart';
import 'package:constanza_player/services/media_library/media_library_backend.dart';
import 'package:constanza_player/services/permission_service.dart';
import 'package:constanza_player/services/settings_storage_service.dart';

/// Estado da biblioteca.
enum LibraryStatus {
  initial,
  loading,
  loaded,
  noPermission,
  empty,
  error,
  needsFolderSetup,
}

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
    this.minTrackDurationSec = 0,
    this.allFolders = const [],
    this.selectedFolders = const [],
    this.excludedSongIds = const {},
  });

  final LibraryStatus status;
  final List<Song> songs;
  final List<Album> albums;
  final List<Artist> artists;
  final String? errorMessage;
  final SortOrder sortOrder;

  /// Duração mínima (em segundos) para filtrar faixas curtas. 0 = desativado.
  final int minTrackDurationSec;

  /// Todas as pastas descobertas no scan.
  final List<String> allFolders;

  /// Pastas selecionadas pelo usuário para inclusão no scan.
  final List<String> selectedFolders;

  /// IDs de músicas explicitamente excluídas do scan (dentro de pastas selecionadas).
  final Set<String> excludedSongIds;

  // Memoized genres/composers — invalidados junto com _sortedSongsCache
  List<String>? _genresCache;
  List<String>? _composersCache;

  List<String> get genres {
    if (_genresCache != null) return _genresCache!;
    final set = <String>{};
    for (final s in songs) {
      if (s.genre != null && s.genre!.isNotEmpty) set.add(s.genre!);
    }
    _genresCache = set.toList()..sort();
    return _genresCache!;
  }

  List<String> get composers {
    if (_composersCache != null) return _composersCache!;
    final set = <String>{};
    for (final s in songs) {
      if (s.composer != null && s.composer!.isNotEmpty) set.add(s.composer!);
    }
    _composersCache = set.toList()..sort();
    return _composersCache!;
  }

  List<Song> songsByGenre(String genre) =>
      songs.where((s) => s.genre == genre).toList();
  List<Song> songsByComposer(String composer) =>
      songs.where((s) => s.composer == composer).toList();

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

    // Filtrar faixas curtas se ativado (minTrackDurationSec > 0)
    if (minTrackDurationSec > 0) {
      result = result
          .where((s) => s.duration.inSeconds >= minTrackDurationSec)
          .toList();
    }

    // Ordenar
    switch (sortOrder) {
      case SortOrder.title:
        result.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      case SortOrder.artist:
        result.sort(
          (a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()),
        );
      case SortOrder.album:
        result.sort(
          (a, b) => a.album.toLowerCase().compareTo(b.album.toLowerCase()),
        );
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

  String sortOrderLabel(AppLocalizations l10n) => switch (sortOrder) {
    SortOrder.title => l10n.librarySortTitle,
    SortOrder.artist => l10n.librarySortArtist,
    SortOrder.album => l10n.librarySortAlbum,
    SortOrder.dateAdded => l10n.librarySortDateAdded,
    SortOrder.duration => l10n.librarySortDuration,
  };

  LibraryState copyWith({
    LibraryStatus? status,
    List<Song>? songs,
    List<Album>? albums,
    List<Artist>? artists,
    String? errorMessage,
    SortOrder? sortOrder,
    int? minTrackDurationSec,
    List<String>? allFolders,
    List<String>? selectedFolders,
    Set<String>? excludedSongIds,
  }) {
    // Invalidate sorted cache when any input that affects it changes
    final invalidateCache =
        songs != null || sortOrder != null || minTrackDurationSec != null;
    final newState = LibraryState(
      status: status ?? this.status,
      songs: songs ?? this.songs,
      albums: albums ?? this.albums,
      artists: artists ?? this.artists,
      errorMessage: errorMessage ?? this.errorMessage,
      sortOrder: sortOrder ?? this.sortOrder,
      minTrackDurationSec: minTrackDurationSec ?? this.minTrackDurationSec,
      allFolders: allFolders ?? this.allFolders,
      selectedFolders: selectedFolders ?? this.selectedFolders,
      excludedSongIds: excludedSongIds ?? this.excludedSongIds,
    );
    if (!invalidateCache) {
      newState._sortedSongsCache = _sortedSongsCache;
      newState._genresCache = _genresCache;
      newState._composersCache = _composersCache;
    }
    return newState;
  }
}

class LibraryNotifier extends StateNotifier<LibraryState> {
  LibraryNotifier() : super(LibraryState()) {
    _loadSettings();
  }

  final _scanner = AudioScannerService();

  /// Músicas do último scan completo (antes de filtrar por pastas ou exclusões).
  List<Song> _allScannedSongs = [];

  // IDs de favoritos persistidos (carregados antes do scan)
  Set<String> _savedFavoriteIds = {};

  // IDs de músicas explicitamente excluídas do scan
  Set<String> _savedExcludedIds = {};

  /// Exposição somente-leitura das músicas brutas do scan (todas as pastas).
  /// Usado pela FoldersPage para mostrar músicas antes do filtro de exclusões.
  List<Song> get allScannedSongs => List.unmodifiable(_allScannedSongs);

  /// Timer para debounce do cache — evita re-serializar durante operações em lote.
  Timer? _cacheSaveTimer;

  void _loadSettings() {
    final json = SettingsStorageService.loadLibrarySettings();
    if (json != null) {
      state = state.copyWith(
        sortOrder: SortOrder.values[json['sortOrder'] as int? ?? 0],
        minTrackDurationSec:
            json['minTrackDurationSec'] as int? ??
            ((json['filterShortTracks'] as bool? ?? false) ? 30 : 0),
      );
    }
    _savedFavoriteIds = SettingsStorageService.loadFavorites();
    _savedExcludedIds = SettingsStorageService.loadExcludedSongs();
    // Carregar pastas selecionadas e exclusões no estado inicial
    final savedFolders = SettingsStorageService.loadMusicFolders();
    if (savedFolders != null) {
      state = state.copyWith(
        selectedFolders: savedFolders,
        excludedSongIds: _savedExcludedIds,
      );
    }
  }

  void _saveSettings() {
    SettingsStorageService.saveLibrarySettings({
      'sortOrder': state.sortOrder.index,
      'minTrackDurationSec': state.minTrackDurationSec,
    });
  }

  /// Inicializa — carrega do cache se existir, senão pede seleção de pastas.
  Future<void> initialize() async {
    state = state.copyWith(status: LibraryStatus.loading);

    // Tentar carregar do cache primeiro
    if (SettingsStorageService.hasLibraryCache) {
      final loaded = _loadFromCache();
      if (loaded) {
        debugPrint('Library: loaded ${state.songs.length} songs from cache');
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

  /// Aplica dados restaurados de um backup imediatamente sem reiniciar o app.
  /// Recarrega settings (favoritos, pastas, exclusões) do SharedPreferences e
  /// faz um rescan completo com os novos dados.
  Future<void> reloadFromBackup() async {
    _loadSettings(); // atualiza _savedFavoriteIds, _savedExcludedIds, selectedFolders
    await rescan();  // reconstrói a biblioteca com as novas configurações
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

  /// Define a duração mínima (segundos) para filtrar faixas curtas. 0 = desativado.
  void setMinTrackDuration(int seconds) {
    final clamped = seconds < 0 ? 0 : seconds;
    if (clamped == state.minTrackDurationSec) return;
    state = state.copyWith(minTrackDurationSec: clamped);
    _saveSettings();
  }

  /// Define as pastas selecionadas, escaneia e filtra músicas.
  Future<void> setSelectedFolders(List<String> folders) async {
    state = state.copyWith(
      selectedFolders: folders,
      status: LibraryStatus.loading,
    );
    await SettingsStorageService.saveMusicFolders(folders);

    // No Windows/Linux/macOS, as pastas selecionadas SÃO as raízes de scan
    // do filesystem (não há MediaStore para listar tudo previamente).
    // Em Android este chamada é no-op no backend.
    await MediaLibrary.instance.setScanFolders(folders);
    // Invalida cache de scan — força re-leitura com novas raízes.
    _allScannedSongs = const [];

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
      debugPrint('Folder discovery failed: $e');
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

  /// Atualiza metadados de uma música na biblioteca e persiste o cache.
  Future<void> updateSong(Song updated) async {
    final newSongs = state.songs.map((s) {
      if (s.id == updated.id) return updated.copyWith(isFavorite: s.isFavorite);
      return s;
    }).toList();
    // Reconstruir álbuns e artistas para refletir mudanças de artista/álbum
    final albums = _buildAlbumsFromSongs(newSongs);
    final artists = _buildArtistsFromSongs(newSongs);
    state = state.copyWith(songs: newSongs, albums: albums, artists: artists);
    // Aguarda persistência do cache para garantir que os dados não sejam perdidos
    await _saveToCache(newSongs, albums, artists, immediate: true);
  }

  void removeSong(String songId) {
    final newSongs = state.songs.where((s) => s.id != songId).toList();
    state = state.copyWith(songs: newSongs);
    _saveToCache(newSongs, state.albums, state.artists);
  }

  /// Remove múltiplas músicas do dispositivo (usada para duplicadas).
  /// [toDelete] lista de Songs a remover; [toRemoveIds] IDs a remover da biblioteca.
  Future<Map<String, bool>> removeSongs(List<Song> toDelete) async {
    final results = <String, bool>{};
    for (final song in toDelete) {
      if (song.filePath.isEmpty) {
        removeSong(song.id);
        results[song.id] = true;
        continue;
      }
      final deleted = await _deleteSongFromDevice(song);
      if (deleted) removeSong(song.id);
      results[song.id] = deleted;
    }
    return results;
  }

  Future<bool> _deleteSongFromDevice(Song song) async {
    try {
      const channel = MethodChannel('com.constanza.media_tag');
      final result = await channel.invokeMethod<bool>('deleteSong', {
        'filePath': song.filePath,
        'songId': song.numericId,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Detecta grupos de músicas duplicadas na biblioteca.
  ///
  /// Critério principal: título normalizado + artista normalizado são idênticos.
  /// Normalização: lowercase, trim, remove conteúdo parentético (feat., official, etc.).
  List<List<Song>> findDuplicates() {
    final groups = <String, List<Song>>{};

    for (final song in state.songs) {
      final key = _normalizeDuplicateKey(song.title, song.artist);
      groups.putIfAbsent(key, () => []).add(song);
    }

    // Apenas grupos com 2+ músicas
    final duplicates = groups.values
        .where((group) => group.length >= 2)
        .toList();

    // Ordenar cada grupo: primeiro pela duração mais longa (provável melhor qualidade)
    for (final group in duplicates) {
      group.sort((a, b) => b.duration.compareTo(a.duration));
    }

    // Ordenar grupos por título
    duplicates.sort(
      (a, b) =>
          a.first.title.toLowerCase().compareTo(b.first.title.toLowerCase()),
    );

    return duplicates;
  }

  /// Regex pré-compilada para normalização de duplicatas.
  /// Executada uma vez por música — pre-compilar evita ~N compilações por scan.
  static final _duplicateParenRegex = RegExp(
    r'\s*\((?:feat\.?|ft\.?|featuring|official|lyrics?|audio|video|remaster(?:ed)?|live)[^)]*\)',
    caseSensitive: false,
  );
  static final _duplicateSpaceRegex = RegExp(r'\s+');

  /// Normaliza título+artista para chave de deduplicação.
  static String _normalizeDuplicateKey(String title, String artist) {
    String normalize(String s) {
      var n = s.toLowerCase().trim();
      // Remove conteúdo parentético comum: (feat. X), (official video), (lyrics), (audio), etc.
      n = n.replaceAll(_duplicateParenRegex, '');
      // Remove espaços extras
      n = n.replaceAll(_duplicateSpaceRegex, ' ').trim();
      return n;
    }

    return '${normalize(title)}|||${normalize(artist)}';
  }

  /// Carrega biblioteca do cache local.
  bool _loadFromCache() {
    try {
      final cache = SettingsStorageService.loadLibraryCache();
      if (cache == null) return false;

      final songsJson =
          (cache['songs'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final albumsJson =
          (cache['albums'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final artistsJson =
          (cache['artists'] as List?)?.cast<Map<String, dynamic>>() ?? [];

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
          : songs
                .map(
                  (s) => ids.contains(s.id) ? s.copyWith(isFavorite: true) : s,
                )
                .toList();

      state = state.copyWith(
        status: LibraryStatus.loaded,
        songs: restored,
        albums: albums,
        artists: artists,
        allFolders: folders,
      );
      // Reidrata os mapas id→path do backend Windows (no-op no Android).
      // Sem isto, queryArtwork retorna null após startup-from-cache porque
      // o filesystem nunca foi varrido nesta execução.
      MediaLibrary.instance.indexFromSongs(restored);
      // Também guarda em _allScannedSongs para que setSelectedFolders e
      // discoverFolders tenham um ponto de partida sem precisar re-escanear.
      _allScannedSongs = restored;
      return true;
    } catch (e) {
      debugPrint('Library cache load failed: $e');
      return false;
    }
  }

  /// Salva biblioteca no cache local.
  /// Usa debounce de 500ms para evitar re-serialização durante operações em lote
  /// (ex: removeSongs apaga várias faixas em sequência).
  /// [immediate] força gravação imediata (usado após scan/filter completo).
  Future<void> _saveToCache(
    List<Song> songs,
    List<Album> albums,
    List<Artist> artists, {
    bool immediate = false,
  }) async {
    if (immediate) {
      _cacheSaveTimer?.cancel();
      _cacheSaveTimer = null;
      await _flushCache(songs, albums, artists);
      return;
    }
    // Debounce: agenda persistência para daqui a 500ms
    _cacheSaveTimer?.cancel();
    _cacheSaveTimer = Timer(const Duration(milliseconds: 500), () {
      _flushCache(songs, albums, artists);
    });
  }

  Future<void> _flushCache(
    List<Song> songs,
    List<Album> albums,
    List<Artist> artists,
  ) async {
    try {
      await SettingsStorageService.saveLibraryCache({
        'songs': songs.map((s) => s.toJson()).toList(),
        'albums': albums.map((a) => a.toJson()).toList(),
        'artists': artists.map((a) => a.toJson()).toList(),
      });
    } catch (e) {
      debugPrint('Library cache save failed: $e');
    }
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

  /// Persiste o conjunto de músicas excluídas e reaaplica o filtro da biblioteca.
  Future<void> setExcludedSongs(Set<String> ids) async {
    _savedExcludedIds = ids;
    await SettingsStorageService.saveExcludedSongs(ids);
    state = state.copyWith(excludedSongIds: ids);
    final folders = state.selectedFolders;
    if (folders.isNotEmpty) {
      await _applyFolderFilter(folders);
    }
  }

  /// Filtra músicas escaneadas por pastas e atualiza estado + cache.
  Future<void> _applyFolderFilter(List<String> folders) async {
    // Match exato + prefixo: no Windows (e Linux/macOS) o usuário pica uma
    // pasta-raiz esperando varredura recursiva. No Android cada subpasta com
    // música aparece como item próprio, então o match exato continua sendo
    // o caminho dominante — o prefixo só é exercido em desktop.
    bool insideAnySelected(String songFolder) {
      for (final f in folders) {
        if (songFolder == f) return true;
        // Trata tanto / quanto \\ como separador de subpastas.
        if (songFolder.startsWith('$f/') || songFolder.startsWith('$f\\')) {
          return true;
        }
      }
      return false;
    }

    final filtered = _allScannedSongs
        .where(
          (s) =>
              insideAnySelected(s.folderPath) &&
              !_savedExcludedIds.contains(s.id),
        )
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
        : filtered
              .map((s) => ids.contains(s.id) ? s.copyWith(isFavorite: true) : s)
              .toList();

    state = state.copyWith(
      status: LibraryStatus.loaded,
      songs: restored,
      albums: albums,
      artists: artists,
      allFolders: _extractFolders(_allScannedSongs),
      excludedSongIds: _savedExcludedIds,
    );

    await _saveToCache(restored, albums, artists, immediate: true);
    debugPrint(
      'Library: filtered ${restored.length} songs from ${folders.length} folders'
      ' (${_savedExcludedIds.length} songs excluded)',
    );
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
  ///
  /// Suporta músicas com múltiplos artistas ("feat.", "ft.", "&", ",", etc.):
  /// cada artista individual recebe sua própria entrada, acumulando todas as
  /// músicas em que aparece.
  List<Artist> _buildArtistsFromSongs(List<Song> songs) {
    // nome_lower → lista de músicas
    final artistSongMap = <String, List<Song>>{};
    // nome_lower → artistId (primeiro encontrado, para artwork)
    final artistIdMap = <String, String>{};
    // nome_lower → nome original preservando capitalização
    final artistNameMap = <String, String>{};

    for (final s in songs) {
      final individuals = _parseArtistNames(s.artist);
      for (final name in individuals) {
        final key = name.toLowerCase();
        artistSongMap.putIfAbsent(key, () => []).add(s);
        if (!artistNameMap.containsKey(key)) {
          artistNameMap[key] = name;
        }
        if (!artistIdMap.containsKey(key) &&
            s.artistId != null &&
            s.artistId!.isNotEmpty) {
          artistIdMap[key] = s.artistId!;
        }
      }
    }

    return artistSongMap.entries.map((e) {
        final albumIds = e.value
            .map((s) => s.albumId)
            .whereType<String>()
            .toSet();
        return Artist(
          id: artistIdMap[e.key] ?? e.key,
          name: artistNameMap[e.key] ?? e.key,
          songCount: e.value.length,
          albumCount: albumIds.length,
        );
      }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  /// Regex pré-compilada para parsing de artistas.
  static final _artistFeatParenRegex = RegExp(
    r'\(\s*(?:feat\.?|ft\.?|featuring)\s+([^)]+)\)',
    caseSensitive: false,
  );
  static final _artistSplitRegex = RegExp(
    r'\s*[,;/]\s*'
    r'|\s+(?:feat\.?|ft\.?|featuring)\s+'
    r'|\s+[&×·]\s+'
    r'|\s+x\s+',
    caseSensitive: false,
  );

  /// Separa uma string de artistas nos nomes individuais.
  ///
  /// Reconhece qualquer número de artistas com os separadores:
  ///   ",", ";", "/", "feat.", "ft.", "featuring", "&", "×", "·", " x "
  /// Também suporta feat entre parênteses: "Artist A (feat. B, C)"
  static List<String> _parseArtistNames(String artistField) {
    // Expandir feat. parentético: "A (feat. B, C)" → "A feat. B, C"
    var field = artistField.replaceAllMapped(
      _artistFeatParenRegex,
      (m) => ' feat. ${m.group(1)}',
    );

    final parts = field.split(_artistSplitRegex);
    return parts.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
  }

  @override
  void dispose() {
    _cacheSaveTimer?.cancel();
    super.dispose();
  }
}

/// Provider global da biblioteca.
final libraryProvider = StateNotifierProvider<LibraryNotifier, LibraryState>(
  (ref) => LibraryNotifier(),
);
