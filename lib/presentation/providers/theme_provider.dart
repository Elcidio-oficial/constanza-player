import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:constanza_player/core/theme/app_backgrounds.dart';
import 'package:constanza_player/services/settings_storage_service.dart';

enum ListDensity { compact, normal, comfortable }

enum NowPlayingStyle {
  classic, circular, large, fullBlur, vinyl,
  minimalist, aurora, elegant, wave, mosaic,
}

enum NavBarStyle { glass, artwork, solid, minimal }

enum MiniPlayerStyle { glass, artwork, minimal, card, dynamic }

enum MediaBarStyle { minimal, glow, gradient, thick, classic }

enum NowPlayingColorStyle { degrade, gradient }

class ThemeState {
  const ThemeState({
    this.themeMode = ThemeMode.dark,
    this.accentColor,
    this.backgroundType = BackgroundType.none,
    this.gradientPresetId,
    this.backgroundImagePath,
    this.backgroundOpacity = 0.15,
    this.backgroundBlur = 0.0,
    this.listDensity = ListDensity.normal,
    this.nowPlayingStyle = NowPlayingStyle.classic,
    this.showAlbumArtInList = true,
    this.navBarStyle = NavBarStyle.glass,
    this.miniPlayerStyle = MiniPlayerStyle.glass,
    this.mediaBarStyle = MediaBarStyle.minimal,
    this.nowPlayingColorStyle = NowPlayingColorStyle.gradient,

    this.useCustomNpColors = false,
    this.npCustomColor1,
    this.npCustomColor2,
    this.npCustomColor3,
  });

  final ThemeMode themeMode;
  final Color? accentColor;
  final BackgroundType backgroundType;
  final String? gradientPresetId;
  final String? backgroundImagePath;
  final double backgroundOpacity;
  final double backgroundBlur;
  final ListDensity listDensity;
  final NowPlayingStyle nowPlayingStyle;
  final bool showAlbumArtInList;
  final NavBarStyle navBarStyle;
  final MiniPlayerStyle miniPlayerStyle;
  final MediaBarStyle mediaBarStyle;
  final NowPlayingColorStyle nowPlayingColorStyle;

  final bool useCustomNpColors;
  final Color? npCustomColor1;
  final Color? npCustomColor2;
  final Color? npCustomColor3;

  bool get hasBackground => backgroundType != BackgroundType.none;

  bool get hasImageBackground =>
      backgroundType == BackgroundType.image &&
      backgroundImagePath != null &&
      backgroundImagePath!.isNotEmpty;

  GradientPreset? get currentGradient => gradientPresetId != null
      ? AppBackgrounds.findById(gradientPresetId!)
      : null;

  String get themeModeLabel => switch (themeMode) {
    ThemeMode.system => 'Sistema',
    ThemeMode.light => 'Claro',
    ThemeMode.dark => 'Escuro',
  };

  String get listDensityLabel => switch (listDensity) {
    ListDensity.compact => 'Compacto',
    ListDensity.normal => 'Normal',
    ListDensity.comfortable => 'Confortável',
  };

  String get nowPlayingStyleLabel => switch (nowPlayingStyle) {
    NowPlayingStyle.classic => 'Clássico',
    NowPlayingStyle.circular => 'Circular',
    NowPlayingStyle.large => 'Cinema',
    NowPlayingStyle.fullBlur => 'Imersivo',
    NowPlayingStyle.vinyl => 'Vinil',
    NowPlayingStyle.minimalist => 'Minimalista',
    NowPlayingStyle.aurora => 'Aurora',
    NowPlayingStyle.elegant => 'Elegante',
    NowPlayingStyle.wave => 'Ondas',
    NowPlayingStyle.mosaic => 'Mosaico',
  };

  String get navBarStyleLabel => switch (navBarStyle) {
    NavBarStyle.glass => 'Vidro',
    NavBarStyle.artwork => 'Capa',
    NavBarStyle.solid => 'Sólido',
    NavBarStyle.minimal => 'Minimal',
  };

  String get miniPlayerStyleLabel => switch (miniPlayerStyle) {
    MiniPlayerStyle.glass => 'Vidro',
    MiniPlayerStyle.artwork => 'Capa',
    MiniPlayerStyle.minimal => 'Minimal',
    MiniPlayerStyle.card => 'Card',
    MiniPlayerStyle.dynamic => 'Dinâmico',
  };

  String get mediaBarStyleLabel => switch (mediaBarStyle) {
    MediaBarStyle.minimal => 'Minimal',
    MediaBarStyle.glow => 'Brilho',
    MediaBarStyle.gradient => 'Gradiente',
    MediaBarStyle.thick => 'Espessa',
    MediaBarStyle.classic => 'Clássico',
  };

  String get nowPlayingColorStyleLabel => switch (nowPlayingColorStyle) {
    NowPlayingColorStyle.degrade => 'Degradê',
    NowPlayingColorStyle.gradient => 'Gradiente',
  };

  /// Serializa para JSON-safe map.
  Map<String, dynamic> toJson() => {
    'themeMode': themeMode.index,
    'accentColor': SettingsStorageService.colorToInt(accentColor),
    'backgroundType': backgroundType.index,
    'gradientPresetId': gradientPresetId,
    'backgroundImagePath': backgroundImagePath,
    'backgroundOpacity': backgroundOpacity,
    'backgroundBlur': backgroundBlur,
    'listDensity': listDensity.index,
    'nowPlayingStyle': nowPlayingStyle.index,
    'showAlbumArtInList': showAlbumArtInList,
    'navBarStyle': navBarStyle.index,
    'miniPlayerStyle': miniPlayerStyle.index,
    'mediaBarStyle': mediaBarStyle.index,
    'nowPlayingColorStyle': nowPlayingColorStyle.index,

    'useCustomNpColors': useCustomNpColors,
    'npCustomColor1': SettingsStorageService.colorToInt(npCustomColor1),
    'npCustomColor2': SettingsStorageService.colorToInt(npCustomColor2),
    'npCustomColor3': SettingsStorageService.colorToInt(npCustomColor3),
  };

  /// Deserializa de JSON map.
  factory ThemeState.fromJson(Map<String, dynamic> json) {
    return ThemeState(
      // Always dark mode — light mode removed
      themeMode: ThemeMode.dark,
      accentColor: SettingsStorageService.intToColor(json['accentColor'] as int?),
      backgroundType: BackgroundType.values[json['backgroundType'] as int? ?? 0],
      gradientPresetId: json['gradientPresetId'] as String?,
      backgroundImagePath: json['backgroundImagePath'] as String?,
      backgroundOpacity: (json['backgroundOpacity'] as num?)?.toDouble() ?? 0.15,
      backgroundBlur: (json['backgroundBlur'] as num?)?.toDouble() ?? 0.0,
      listDensity: ListDensity.values[json['listDensity'] as int? ?? 1],
      nowPlayingStyle: NowPlayingStyle.values[
        (json['nowPlayingStyle'] as int? ?? 0).clamp(0, NowPlayingStyle.values.length - 1)
      ],
      showAlbumArtInList: json['showAlbumArtInList'] as bool? ?? true,
      navBarStyle: NavBarStyle.values[
        (json['navBarStyle'] as int? ?? 0).clamp(0, NavBarStyle.values.length - 1)
      ],
      miniPlayerStyle: MiniPlayerStyle.values[
        (json['miniPlayerStyle'] as int? ?? 0).clamp(0, MiniPlayerStyle.values.length - 1)
      ],
      mediaBarStyle: MediaBarStyle.values[
        (json['mediaBarStyle'] as int? ?? 0).clamp(0, MediaBarStyle.values.length - 1)
      ],
      nowPlayingColorStyle: NowPlayingColorStyle.values[
        (json['nowPlayingColorStyle'] as int? ?? 1).clamp(0, NowPlayingColorStyle.values.length - 1)
      ],

      useCustomNpColors: json['useCustomNpColors'] as bool? ?? false,
      npCustomColor1: SettingsStorageService.intToColor(json['npCustomColor1'] as int?),
      npCustomColor2: SettingsStorageService.intToColor(json['npCustomColor2'] as int?),
      npCustomColor3: SettingsStorageService.intToColor(json['npCustomColor3'] as int?),
    );
  }

  ThemeState copyWith({
    ThemeMode? themeMode,
    Color? accentColor,
    bool clearAccentColor = false,
    BackgroundType? backgroundType,
    String? gradientPresetId,
    bool clearGradient = false,
    String? backgroundImagePath,
    bool clearImagePath = false,
    double? backgroundOpacity,
    double? backgroundBlur,
    ListDensity? listDensity,
    NowPlayingStyle? nowPlayingStyle,
    bool? showAlbumArtInList,
    NavBarStyle? navBarStyle,
    MiniPlayerStyle? miniPlayerStyle,
    MediaBarStyle? mediaBarStyle,
    NowPlayingColorStyle? nowPlayingColorStyle,

    bool? useCustomNpColors,
    Color? npCustomColor1,
    bool clearNpColor1 = false,
    Color? npCustomColor2,
    bool clearNpColor2 = false,
    Color? npCustomColor3,
    bool clearNpColor3 = false,
  }) {
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
      accentColor: clearAccentColor ? null : (accentColor ?? this.accentColor),
      backgroundType: backgroundType ?? this.backgroundType,
      gradientPresetId: clearGradient
          ? null
          : (gradientPresetId ?? this.gradientPresetId),
      backgroundImagePath: clearImagePath
          ? null
          : (backgroundImagePath ?? this.backgroundImagePath),
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
      backgroundBlur: backgroundBlur ?? this.backgroundBlur,
      listDensity: listDensity ?? this.listDensity,
      nowPlayingStyle: nowPlayingStyle ?? this.nowPlayingStyle,
      showAlbumArtInList: showAlbumArtInList ?? this.showAlbumArtInList,
      navBarStyle: navBarStyle ?? this.navBarStyle,
      miniPlayerStyle: miniPlayerStyle ?? this.miniPlayerStyle,
      mediaBarStyle: mediaBarStyle ?? this.mediaBarStyle,
      nowPlayingColorStyle: nowPlayingColorStyle ?? this.nowPlayingColorStyle,

      useCustomNpColors: useCustomNpColors ?? this.useCustomNpColors,
      npCustomColor1: clearNpColor1 ? null : (npCustomColor1 ?? this.npCustomColor1),
      npCustomColor2: clearNpColor2 ? null : (npCustomColor2 ?? this.npCustomColor2),
      npCustomColor3: clearNpColor3 ? null : (npCustomColor3 ?? this.npCustomColor3),
    );
  }
}

class ThemeNotifier extends StateNotifier<ThemeState> {
  ThemeNotifier() : super(const ThemeState()) {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    final json = SettingsStorageService.loadTheme();
    if (json != null) {
      state = ThemeState.fromJson(json);
    }
  }

  void _save() => SettingsStorageService.saveTheme(state.toJson());

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _save();
  }

  void setAccentColor(Color? color) {
    if (color == null) {
      state = state.copyWith(clearAccentColor: true);
    } else {
      state = state.copyWith(accentColor: color);
    }
    _save();
  }

  void setBackgroundNone() {
    state = state.copyWith(
      backgroundType: BackgroundType.none,
      clearGradient: true,
      clearImagePath: true,
    );
    _save();
  }

  void setBackgroundGradient(String presetId) {
    state = state.copyWith(
      backgroundType: BackgroundType.gradient,
      gradientPresetId: presetId,
      clearImagePath: true,
    );
    _save();
  }

  void setBackgroundImage(String path) {
    state = state.copyWith(
      backgroundType: BackgroundType.image,
      backgroundImagePath: path,
      clearGradient: true,
    );
    _save();
  }

  void setBackgroundOpacity(double opacity) {
    state = state.copyWith(backgroundOpacity: opacity.clamp(0.05, 0.5));
    _save();
  }

  void setBackgroundBlur(double blur) {
    state = state.copyWith(backgroundBlur: blur.clamp(0.0, 25.0));
    _save();
  }

  void setListDensity(ListDensity density) {
    state = state.copyWith(listDensity: density);
    _save();
  }

  void setNowPlayingStyle(NowPlayingStyle style) {
    state = state.copyWith(nowPlayingStyle: style);
    _save();
  }

  void toggleAlbumArtInList() {
    state = state.copyWith(showAlbumArtInList: !state.showAlbumArtInList);
    _save();
  }

  void setNavBarStyle(NavBarStyle style) {
    state = state.copyWith(navBarStyle: style);
    _save();
  }

  void setMiniPlayerStyle(MiniPlayerStyle style) {
    state = state.copyWith(miniPlayerStyle: style);
    _save();
  }

  void setMediaBarStyle(MediaBarStyle style) {
    state = state.copyWith(mediaBarStyle: style);
    _save();
  }

  void setNowPlayingColorStyle(NowPlayingColorStyle style) {
    state = state.copyWith(nowPlayingColorStyle: style);
    _save();
  }


  void toggleCustomNpColors() {
    state = state.copyWith(useCustomNpColors: !state.useCustomNpColors);
    _save();
  }

  void setNpCustomColor(int index, Color? color) {
    switch (index) {
      case 1:
        state = color == null
            ? state.copyWith(clearNpColor1: true)
            : state.copyWith(npCustomColor1: color);
      case 2:
        state = color == null
            ? state.copyWith(clearNpColor2: true)
            : state.copyWith(npCustomColor2: color);
      case 3:
        state = color == null
            ? state.copyWith(clearNpColor3: true)
            : state.copyWith(npCustomColor3: color);
    }
    _save();
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>(
  (ref) => ThemeNotifier(),
);
