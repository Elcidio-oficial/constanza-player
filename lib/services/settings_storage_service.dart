import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Serviço de persistência de configurações usando SharedPreferences.
///
/// Salva/carrega ThemeState e AudioSettingsState como JSON.
class SettingsStorageService {
  static const _keyTheme = 'constanza_theme_settings';
  static const _keyAudio = 'constanza_audio_settings';
  static const _keyLibrary = 'constanza_library_settings';
  static const _keyFavorites = 'constanza_favorite_ids';
  static const _keyRecentSearches = 'constanza_recent_searches';
  static const _keyLibraryCache = 'constanza_library_cache';
  static const _keyMusicFolders = 'constanza_music_folders';
  static const _keyUserPlaylists = 'constanza_user_playlists';

  static SharedPreferences? _prefs;

  /// Whether init() has been called and completed.
  static bool get isInitialized => _prefs != null;

  /// Acesso público (somente leitura) ao SharedPreferences. Para uso de
  /// serviços auxiliares que precisam iterar chaves (ex.: BackupService).
  static SharedPreferences get safePrefs => _safePrefs;

  /// Acesso seguro ao SharedPreferences — nunca retorna null após init().
  static SharedPreferences get _safePrefs {
    final p = _prefs;
    if (p == null) {
      throw StateError(
        'SettingsStorageService.init() must be called before use',
      );
    }
    return p;
  }

  /// Inicializa o SharedPreferences. Deve ser chamado uma vez no main().
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // ─── THEME ───

  static Map<String, dynamic>? loadTheme() {
    final json = _safePrefs.getString(_keyTheme);
    if (json == null) return null;
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveTheme(Map<String, dynamic> data) async {
    await _safePrefs.setString(_keyTheme, jsonEncode(data));
  }

  // ─── AUDIO SETTINGS ───

  static Map<String, dynamic>? loadAudioSettings() {
    final json = _safePrefs.getString(_keyAudio);
    if (json == null) return null;
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveAudioSettings(Map<String, dynamic> data) async {
    await _safePrefs.setString(_keyAudio, jsonEncode(data));
  }

  // ─── LIBRARY SETTINGS ───

  static Map<String, dynamic>? loadLibrarySettings() {
    final json = _safePrefs.getString(_keyLibrary);
    if (json == null) return null;
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveLibrarySettings(Map<String, dynamic> data) async {
    await _safePrefs.setString(_keyLibrary, jsonEncode(data));
  }

  // ─── FAVORITES ───

  static Set<String> loadFavorites() {
    final list = _safePrefs.getStringList(_keyFavorites);
    return list != null ? Set<String>.from(list) : {};
  }

  static Future<void> saveFavorites(Set<String> ids) async {
    await _safePrefs.setStringList(_keyFavorites, ids.toList());
  }

  // ─── RECENT SEARCHES ───

  static List<String> loadRecentSearches() {
    return _safePrefs.getStringList(_keyRecentSearches) ?? [];
  }

  static Future<void> saveRecentSearches(List<String> searches) async {
    await _safePrefs.setStringList(_keyRecentSearches, searches);
  }

  // ─── LIBRARY CACHE ───

  static Map<String, dynamic>? loadLibraryCache() {
    final json = _safePrefs.getString(_keyLibraryCache);
    if (json == null) return null;
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveLibraryCache(Map<String, dynamic> data) async {
    await _safePrefs.setString(_keyLibraryCache, jsonEncode(data));
  }

  static bool get hasLibraryCache => _safePrefs.containsKey(_keyLibraryCache);

  // ─── MUSIC FOLDERS ───

  /// Carrega pastas de música selecionadas. Null = nunca configurou (1ª vez).
  static List<String>? loadMusicFolders() {
    final list = _safePrefs.getStringList(_keyMusicFolders);
    return list;
  }

  /// Salva pastas de música selecionadas.
  static Future<void> saveMusicFolders(List<String> folders) async {
    await _safePrefs.setStringList(_keyMusicFolders, folders);
  }

  /// Verifica se o usuário já configurou pastas.
  static bool get hasMusicFolders => _safePrefs.containsKey(_keyMusicFolders);

  // ─── EXCLUDED SONGS (blacklist por ID dentro de pastas selecionadas) ───

  static const _keyExcludedSongs = 'constanza_excluded_songs';

  static Set<String> loadExcludedSongs() {
    final list = _safePrefs.getStringList(_keyExcludedSongs);
    return list != null ? Set<String>.from(list) : {};
  }

  static Future<void> saveExcludedSongs(Set<String> ids) async {
    await _safePrefs.setStringList(_keyExcludedSongs, ids.toList());
  }

  // ─── USER PLAYLISTS ───

  static String? loadUserPlaylists() {
    return _safePrefs.getString(_keyUserPlaylists);
  }

  static Future<void> saveUserPlaylists(String jsonString) async {
    await _safePrefs.setString(_keyUserPlaylists, jsonString);
  }

  // ─── PLAYBACK HISTORY ───

  static const _keyHistory = 'constanza_play_history';

  static Future<void> saveHistory(List<Map<String, dynamic>> history) async {
    await _safePrefs.setString(_keyHistory, jsonEncode(history));
  }

  static List<Map<String, dynamic>> loadHistory() {
    final raw = _safePrefs.getString(_keyHistory);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  // ─── PLAY COUNTS ───

  static const _keyPlayCounts = 'constanza_play_counts';

  static Future<void> savePlayCounts(Map<String, int> counts) async {
    await _safePrefs.setString(_keyPlayCounts, jsonEncode(counts));
  }

  static Map<String, int> loadPlayCounts() {
    final raw = _safePrefs.getString(_keyPlayCounts);
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, v as int));
    } catch (_) {
      return {};
    }
  }

  // ─── PLAYBACK STATE ───

  static const _keyPlaybackState = 'constanza_playback_state';

  static Future<void> savePlaybackState(Map<String, dynamic> data) async {
    await _safePrefs.setString(_keyPlaybackState, jsonEncode(data));
  }

  static Map<String, dynamic>? loadPlaybackState() {
    final json = _safePrefs.getString(_keyPlaybackState);
    if (json == null) return null;
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ─── USER PROFILE ───

  static const _keyProfileName = 'constanza_profile_name';
  static const _keyProfilePhoto = 'constanza_profile_photo';

  static String? loadProfileName() => _safePrefs.getString(_keyProfileName);

  static Future<void> saveProfileName(String? name) async {
    if (name == null || name.isEmpty) {
      await _safePrefs.remove(_keyProfileName);
    } else {
      await _safePrefs.setString(_keyProfileName, name);
    }
  }

  static String? loadProfilePhoto() => _safePrefs.getString(_keyProfilePhoto);

  static Future<void> saveProfilePhoto(String? path) async {
    if (path == null || path.isEmpty) {
      await _safePrefs.remove(_keyProfilePhoto);
    } else {
      await _safePrefs.setString(_keyProfilePhoto, path);
    }
  }

  // ─── GRID LAYOUT PREFERENCES (Albums / Artists) ───

  static const _keyAlbumShape = 'constanza_album_shape';
  static const _keyAlbumColumns = 'constanza_album_columns';
  static const _keyArtistShape = 'constanza_artist_shape';
  static const _keyArtistColumns = 'constanza_artist_columns';

  static int? loadAlbumShape() => _safePrefs.getInt(_keyAlbumShape);
  static Future<void> saveAlbumShape(int index) =>
      _safePrefs.setInt(_keyAlbumShape, index);

  static int? loadAlbumColumns() => _safePrefs.getInt(_keyAlbumColumns);
  static Future<void> saveAlbumColumns(int? columns) async {
    if (columns == null) {
      await _safePrefs.remove(_keyAlbumColumns);
    } else {
      await _safePrefs.setInt(_keyAlbumColumns, columns);
    }
  }

  static int? loadArtistShape() => _safePrefs.getInt(_keyArtistShape);
  static Future<void> saveArtistShape(int index) =>
      _safePrefs.setInt(_keyArtistShape, index);

  static int? loadArtistColumns() => _safePrefs.getInt(_keyArtistColumns);
  static Future<void> saveArtistColumns(int? columns) async {
    if (columns == null) {
      await _safePrefs.remove(_keyArtistColumns);
    } else {
      await _safePrefs.setInt(_keyArtistColumns, columns);
    }
  }

  // ─── HELPERS ───

  // ignore: deprecated_member_use
  /// Converte Color para int (para serialização).
  // ignore: deprecated_member_use
  static int? colorToInt(Color? color) => color?.value;

  /// Converte int para Color.
  // ignore: deprecated_member_use
  static Color? intToColor(int? value) => value != null ? Color(value) : null;
}
