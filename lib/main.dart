import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:constanza_player/core/theme/app_theme.dart';
import 'package:constanza_player/presentation/pages/splash/splash_page.dart';
import 'package:constanza_player/presentation/pages/app_shell.dart';
import 'package:constanza_player/presentation/providers/theme_provider.dart';
import 'package:constanza_player/presentation/providers/player_provider.dart';
import 'package:constanza_player/services/audio_handler.dart';
import 'package:constanza_player/services/settings_storage_service.dart';
import 'package:constanza_player/services/lyrics_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa SharedPreferences antes de qualquer coisa
  await SettingsStorageService.init();
  await LyricsService.init();

  // Inicializa o AudioService (requer MainActivity extends AudioServiceFragmentActivity).
  // Se falhar (configuração errada de Activity no Manifest), o app ainda funciona
  // sem notificações — evita travar na tela inicial do Flutter.
  late final ConstanzaAudioHandler audioHandler;
  try {
    audioHandler = await AudioService.init<ConstanzaAudioHandler>(
      builder: () => ConstanzaAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.constanza.constanza_player.audio',
        androidNotificationChannelName: 'Constanza Músicas',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        androidNotificationIcon: 'mipmap/ic_launcher',
        androidShowNotificationBadge: true,
        androidResumeOnClick: true,
      ),
    );
  } catch (_) {
    // Fallback — playback local funciona, notificações ficam desativadas
    audioHandler = ConstanzaAudioHandler();
  }

  // UI imersiva — transparência total nas barras do sistema
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        audioHandlerProvider.overrideWithValue(audioHandler),
      ],
      child: const ConstanzaApp(),
    ),
  );
}

class ConstanzaApp extends ConsumerWidget {
  const ConstanzaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final accent = themeState.accentColor;

    return MaterialApp(
      title: 'Constanza Músicas',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(accentColor: accent),
      darkTheme: AppTheme.dark(accentColor: accent),
      themeMode: themeState.themeMode,
      home: const _AppEntry(),
    );
  }
}

class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  bool _splashComplete = false;

  @override
  Widget build(BuildContext context) {
    if (!_splashComplete) {
      return SplashPage(
        onComplete: () => setState(() => _splashComplete = true),
      );
    }
    return const AppShell();
  }
}
