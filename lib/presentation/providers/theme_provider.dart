import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:constanza_player/core/theme/app_backgrounds.dart';
import 'package:constanza_player/l10n/gen/app_localizations.dart';
import 'package:constanza_player/services/settings_storage_service.dart';

enum ListDensity { compact, normal, comfortable }

enum NowPlayingStyle {
  classic,
  circular,
  large,
  fullBlur,
  vinyl,
  minimalist,
  aurora,
  elegant,
  wave,
  mosaic,
}

enum NavBarStyle { glass, artwork, solid, minimal }

enum MiniPlayerStyle { glass, artwork, minimal, card, dynamic }

enum MediaBarStyle { minimal, glow, gradient, thick, classic }

enum NowPlayingColorStyle { degrade, gradient, artwork }

enum CarModeView { player, lyrics }

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

    this.autoCarMode = false,
    this.carModeView = CarModeView.player,
    this.languageCode,
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

  final bool autoCarMode;
  final CarModeView carModeView;

  /// Idioma escolhido pelo usuário ('en', 'pt') ou null para seguir o sistema.
  final String? languageCode;

  Locale? get locale => languageCode == null ? null : Locale(languageCode!);

  bool get hasBackground => backgroundType != BackgroundType.none;

  bool get hasImageBackground =>
      backgroundType == BackgroundType.image &&
      backgroundImagePath != null &&
      backgroundImagePath!.isNotEmpty;

  GradientPreset? get currentGradient => gradientPresetId != null
      ? AppBackgrounds.findById(gradientPresetId!)
      : null;

  String themeModeLabel(AppLocalizations l10n) => switch (themeMode) {
    ThemeMode.system => l10n.themeModeSystem,
    ThemeMode.light => l10n.themeModeLight,
    ThemeMode.dark => l10n.themeModeDark,
  };

  String listDensityLabel(AppLocalizations l10n) => switch (listDensity) {
    ListDensity.compact => l10n.libraryDensityCompact,
    ListDensity.normal => l10n.libraryDensityNormal,
    ListDensity.comfortable => l10n.libraryDensityComfortable,
  };

  String nowPlayingStyleLabel(AppLocalizations l10n) =>
      switch (nowPlayingStyle) {
        NowPlayingStyle.classic => l10n.npStyleClassic,
        NowPlayingStyle.circular => l10n.npStyleCircular,
        NowPlayingStyle.large => l10n.npStyleLarge,
        NowPlayingStyle.fullBlur => l10n.npStyleFullBlur,
        NowPlayingStyle.vinyl => l10n.npStyleVinyl,
        NowPlayingStyle.minimalist => l10n.npStyleMinimalist,
        NowPlayingStyle.aurora => l10n.npStyleAurora,
        NowPlayingStyle.elegant => l10n.npStyleElegant,
        NowPlayingStyle.wave => l10n.npStyleWave,
        NowPlayingStyle.mosaic => l10n.npStyleMosaic,
      };

  String navBarStyleLabel(AppLocalizations l10n) => switch (navBarStyle) {
    NavBarStyle.glass => l10n.navBarGlass,
    NavBarStyle.artwork => l10n.navBarArtwork,
    NavBarStyle.solid => l10n.navBarSolid,
    NavBarStyle.minimal => l10n.navBarMinimal,
  };

  String miniPlayerStyleLabel(AppLocalizations l10n) =>
      switch (miniPlayerStyle) {
        MiniPlayerStyle.glass => l10n.miniPlayerGlass,
        MiniPlayerStyle.artwork => l10n.miniPlayerArtwork,
        MiniPlayerStyle.minimal => l10n.miniPlayerMinimal,
        MiniPlayerStyle.card => l10n.miniPlayerCard,
        MiniPlayerStyle.dynamic => l10n.miniPlayerDynamic,
      };

  String mediaBarStyleLabel(AppLocalizations l10n) => switch (mediaBarStyle) {
    MediaBarStyle.minimal => l10n.mediaBarMinimal,
    MediaBarStyle.glow => l10n.mediaBarGlow,
    MediaBarStyle.gradient => l10n.mediaBarGradient,
    MediaBarStyle.thick => l10n.mediaBarThick,
    MediaBarStyle.classic => l10n.mediaBarClassic,
  };

  String nowPlayingColorStyleLabel(AppLocalizations l10n) =>
      switch (nowPlayingColorStyle) {
        NowPlayingColorStyle.degrade => l10n.npColorStyleDegrade,
        NowPlayingColorStyle.gradient => l10n.npColorStyleGradient,
        NowPlayingColorStyle.artwork => l10n.npColorStyleArtwork,
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
    'autoCarMode': autoCarMode,
    'carModeView': carModeView.index,
    if (languageCode != null) 'languageCode': languageCode,
  };

  /// Deserializa de JSON map.
  factory ThemeState.fromJson(Map<String, dynamic> json) {
    return ThemeState(
      // Always dark mode — light mode removed
      themeMode: ThemeMode.dark,
      accentColor: SettingsStorageService.intToColor(
        json['accentColor'] as int?,
      ),
      backgroundType:
          BackgroundType.values[json['backgroundType'] as int? ?? 0],
      gradientPresetId: json['gradientPresetId'] as String?,
      backgroundImagePath: json['backgroundImagePath'] as String?,
      backgroundOpacity:
          (json['backgroundOpacity'] as num?)?.toDouble() ?? 0.15,
      backgroundBlur: (json['backgroundBlur'] as num?)?.toDouble() ?? 0.0,
      listDensity: ListDensity.values[json['listDensity'] as int? ?? 1],
      nowPlayingStyle:
          NowPlayingStyle.values[(json['nowPlayingStyle'] as int? ?? 0).clamp(
            0,
            NowPlayingStyle.values.length - 1,
          )],
      showAlbumArtInList: json['showAlbumArtInList'] as bool? ?? true,
      navBarStyle:
          NavBarStyle.values[(json['navBarStyle'] as int? ?? 0).clamp(
            0,
            NavBarStyle.values.length - 1,
          )],
      miniPlayerStyle:
          MiniPlayerStyle.values[(json['miniPlayerStyle'] as int? ?? 0).clamp(
            0,
            MiniPlayerStyle.values.length - 1,
          )],
      mediaBarStyle:
          MediaBarStyle.values[(json['mediaBarStyle'] as int? ?? 0).clamp(
            0,
            MediaBarStyle.values.length - 1,
          )],
      nowPlayingColorStyle:
          NowPlayingColorStyle.values[(json['nowPlayingColorStyle'] as int? ??
                  1)
              .clamp(0, NowPlayingColorStyle.values.length - 1)],

      useCustomNpColors: json['useCustomNpColors'] as bool? ?? false,
      npCustomColor1: SettingsStorageService.intToColor(
        json['npCustomColor1'] as int?,
      ),
      npCustomColor2: SettingsStorageService.intToColor(
        json['npCustomColor2'] as int?,
      ),
      npCustomColor3: SettingsStorageService.intToColor(
        json['npCustomColor3'] as int?,
      ),
      autoCarMode: json['autoCarMode'] as bool? ?? false,
      carModeView: CarModeView.values[(json['carModeView'] as int? ?? 0).clamp(
        0,
        CarModeView.values.length - 1,
      )],
      languageCode: json['languageCode'] as String?,
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
    bool? autoCarMode,
    CarModeView? carModeView,
    String? languageCode,
    bool clearLanguageCode = false,
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
      npCustomColor1: clearNpColor1
          ? null
          : (npCustomColor1 ?? this.npCustomColor1),
      npCustomColor2: clearNpColor2
          ? null
          : (npCustomColor2 ?? this.npCustomColor2),
      npCustomColor3: clearNpColor3
          ? null
          : (npCustomColor3 ?? this.npCustomColor3),
      autoCarMode: autoCarMode ?? this.autoCarMode,
      carModeView: carModeView ?? this.carModeView,
      languageCode: clearLanguageCode
          ? null
          : (languageCode ?? this.languageCode),
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

  /// Recarrega o tema do SharedPreferences — chamado após restauração de backup.
  Future<void> reloadFromStorage() => _loadFromStorage();

  void _save() => SettingsStorageService.saveTheme(state.toJson());

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _save();
  }

  /// Define o idioma. `code` deve ser 'en' ou 'pt'; `null` segue o sistema.
  void setLanguage(String? code) {
    if (code == null) {
      state = state.copyWith(clearLanguageCode: true);
    } else {
      state = state.copyWith(languageCode: code);
    }
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

  /// Aplica um tema pré-definido completo.
  void applyThemePreset(ThemePreset preset) {
    state = state.copyWith(
      accentColor: preset.accent,
      nowPlayingStyle: preset.npStyle,
      navBarStyle: preset.navBar,
      miniPlayerStyle: preset.miniPlayer,
      nowPlayingColorStyle: preset.colorStyle,
      useCustomNpColors: preset.customColors != null,
      npCustomColor1: preset.customColors?.$1,
      npCustomColor2: preset.customColors?.$2,
      npCustomColor3: preset.customColors?.$3,
      clearNpColor1: preset.customColors == null,
      clearNpColor2: preset.customColors == null,
      clearNpColor3: preset.customColors == null,
    );
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

  void toggleAutoCarMode() {
    state = state.copyWith(autoCarMode: !state.autoCarMode);
    _save();
  }

  void setCarModeView(CarModeView view) {
    state = state.copyWith(carModeView: view);
    _save();
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>(
  (ref) => ThemeNotifier(),
);

// ============================================================
// THEME PRESETS
// ============================================================

class ThemePreset {
  const ThemePreset({
    required this.id,
    required this.name,
    required this.description,
    required this.accent,
    required this.icon,
    this.npStyle = NowPlayingStyle.classic,
    this.navBar = NavBarStyle.glass,
    this.miniPlayer = MiniPlayerStyle.glass,
    this.colorStyle = NowPlayingColorStyle.gradient,
    this.customColors,
    required this.previewColors,
  });

  final String id;
  final String name;
  final String description;
  final Color accent;
  final IconData icon;
  final NowPlayingStyle npStyle;
  final NavBarStyle navBar;
  final MiniPlayerStyle miniPlayer;
  final NowPlayingColorStyle colorStyle;
  final (Color, Color, Color)? customColors;
  final List<Color> previewColors;
}

class ThemePresets {
  static const List<ThemePreset> all = [
    // Neon
    ThemePreset(
      id: 'neon',
      name: 'Neon',
      description: 'Vibrante e elétrico',
      accent: Color(0xFF00E5FF),
      icon: Icons.flash_on_rounded,
      npStyle: NowPlayingStyle.aurora,
      navBar: NavBarStyle.glass,
      miniPlayer: MiniPlayerStyle.dynamic,
      colorStyle: NowPlayingColorStyle.gradient,
      customColors: (Color(0xFF00E5FF), Color(0xFFAA00FF), Color(0xFF1A0030)),
      previewColors: [Color(0xFF00E5FF), Color(0xFFAA00FF), Color(0xFF1A0030)],
    ),
    // Pastel
    ThemePreset(
      id: 'pastel',
      name: 'Pastel',
      description: 'Suave e acolhedor',
      accent: Color(0xFFFFB4A2),
      icon: Icons.palette_rounded,
      npStyle: NowPlayingStyle.elegant,
      navBar: NavBarStyle.minimal,
      miniPlayer: MiniPlayerStyle.card,
      colorStyle: NowPlayingColorStyle.degrade,
      customColors: (Color(0xFFFFB4A2), Color(0xFFB5838D), Color(0xFF2D1F2F)),
      previewColors: [Color(0xFFFFB4A2), Color(0xFFB5838D), Color(0xFF6D6875)],
    ),
    // Monocromo
    ThemePreset(
      id: 'mono',
      name: 'Monocromo',
      description: 'Preto e branco puro',
      accent: Color(0xFFE0E0E0),
      icon: Icons.contrast_rounded,
      npStyle: NowPlayingStyle.minimalist,
      navBar: NavBarStyle.minimal,
      miniPlayer: MiniPlayerStyle.minimal,
      colorStyle: NowPlayingColorStyle.degrade,
      customColors: (Color(0xFF808080), Color(0xFF404040), Color(0xFF1A1A1A)),
      previewColors: [Color(0xFFFFFFFF), Color(0xFF808080), Color(0xFF000000)],
    ),
    // Sunset
    ThemePreset(
      id: 'sunset',
      name: 'Pôr do Sol',
      description: 'Quente e dourado',
      accent: Color(0xFFFF6B35),
      icon: Icons.wb_twilight_rounded,
      npStyle: NowPlayingStyle.large,
      navBar: NavBarStyle.artwork,
      miniPlayer: MiniPlayerStyle.artwork,
      colorStyle: NowPlayingColorStyle.gradient,
      customColors: (Color(0xFFFF6B35), Color(0xFFC1121F), Color(0xFF1A0A00)),
      previewColors: [Color(0xFFFF6B35), Color(0xFFC1121F), Color(0xFF780000)],
    ),
    // Ocean
    ThemePreset(
      id: 'ocean',
      name: 'Oceano',
      description: 'Profundo e sereno',
      accent: Color(0xFF0077B6),
      icon: Icons.water_rounded,
      npStyle: NowPlayingStyle.wave,
      navBar: NavBarStyle.glass,
      miniPlayer: MiniPlayerStyle.dynamic,
      colorStyle: NowPlayingColorStyle.gradient,
      customColors: (Color(0xFF0077B6), Color(0xFF023E8A), Color(0xFF03045E)),
      previewColors: [Color(0xFF90E0EF), Color(0xFF0077B6), Color(0xFF03045E)],
    ),
    // Emerald
    ThemePreset(
      id: 'emerald',
      name: 'Esmeralda',
      description: 'Natural e equilibrado',
      accent: Color(0xFF2D6A4F),
      icon: Icons.eco_rounded,
      npStyle: NowPlayingStyle.vinyl,
      navBar: NavBarStyle.solid,
      miniPlayer: MiniPlayerStyle.glass,
      colorStyle: NowPlayingColorStyle.gradient,
      customColors: (Color(0xFF40916C), Color(0xFF2D6A4F), Color(0xFF081C15)),
      previewColors: [Color(0xFF95D5B2), Color(0xFF40916C), Color(0xFF081C15)],
    ),
    // Auto (sem custom colors — usa artwork)
    ThemePreset(
      id: 'auto',
      name: 'Automático',
      description: 'Cores da capa do álbum',
      accent: Color(0xFF6750A4),
      icon: Icons.auto_awesome_rounded,
      npStyle: NowPlayingStyle.classic,
      navBar: NavBarStyle.glass,
      miniPlayer: MiniPlayerStyle.glass,
      colorStyle: NowPlayingColorStyle.gradient,
      customColors: null,
      previewColors: [Color(0xFF6750A4), Color(0xFFD0BCFF), Color(0xFF1D1B20)],
    ),
  ];
}
