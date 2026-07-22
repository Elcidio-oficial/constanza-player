import 'dart:async';
import 'dart:io' show Platform;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:constanza_player/l10n/gen/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:constanza_player/services/widget_service.dart';
import 'package:constanza_player/core/theme/app_theme.dart';
import 'package:constanza_player/core/router/app_router.dart';
import 'package:constanza_player/presentation/pages/now_playing/now_playing_page.dart'
    show showSleepTimerSheet, openQueuePage;
import 'package:constanza_player/presentation/providers/theme_provider.dart';
import 'package:constanza_player/presentation/providers/player_provider.dart';
import 'package:constanza_player/presentation/providers/library_provider.dart';
import 'package:constanza_player/presentation/widgets/background_wrapper.dart';
import 'package:constanza_player/presentation/widgets/windows_title_bar.dart';
import 'package:constanza_player/services/audio_handler.dart';
import 'package:constanza_player/services/window_mode_service.dart';
import 'package:constanza_player/services/media_library/media_library_backend.dart';
import 'package:constanza_player/services/media_library/scan_crash_guard.dart';
import 'package:constanza_player/services/windows_smtc_service.dart';
import 'package:constanza_player/services/settings_storage_service.dart';
import 'package:constanza_player/services/default_player_service.dart';
import 'package:constanza_player/services/floating_player_service.dart';
import 'package:constanza_player/services/lyrics_service.dart';
import 'package:constanza_player/services/audio_analysis_service.dart';
import 'package:constanza_player/services/bpm_key_fetch_service.dart';
import 'package:constanza_player/services/crash_reporter.dart';
import 'package:audio_session/audio_session.dart';

void main() async {
  // Captura erros globais — garante que o app nunca crashe silenciosamente.
  // Em release builds, silenciamos debugPrint para não vazar logs em logcat;
  // o CrashReporter persiste os erros em <AppDir>/crashes.jsonl para diagnóstico.
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Windows/Linux: registra o backend libmpv para o just_audio. Sem isto,
      // setFilePath() não emite áudio nem erro — apenas falha em silêncio.
      // Deve rodar ANTES de qualquer AudioPlayer ser instanciado.
      if (Platform.isWindows || Platform.isLinux) {
        JustAudioMediaKit.ensureInitialized(windows: true, linux: true);

        // Desktop: tira a title bar nativa (substituída pelo [WindowsTitleBar])
        // e define tamanho mínimo. Sem awaitar tudo: ensureInitialized é
        // obrigatório antes de qualquer outra chamada do window_manager.
        await windowManager.ensureInitialized();
        const opts = WindowOptions(
          size: Size(1100, 720),
          minimumSize: Size(900, 600),
          center: true,
          backgroundColor: Colors.transparent,
          skipTaskbar: false,
          titleBarStyle: TitleBarStyle.hidden,
          title: 'Constanza Músicas',
        );
        await windowManager.waitUntilReadyToShow(opts, () async {
          await windowManager.show();
          await windowManager.focus();
        });
      }

      if (kReleaseMode) {
        debugPrint = (String? message, {int? wrapWidth}) {};
      }

      // Inicializa reporter ANTES de instalar handlers, para não perder erros
      // precoces (p.ex. falha na inicialização do SharedPreferences).
      await CrashReporter.init();
      CrashReporter.installGlobalHandlers();

      // Inicializa SharedPreferences antes de qualquer coisa
      await SettingsStorageService.init();

      // Auto-cura de crashes nativos do `audiotags` no Windows: se o run
      // anterior morreu lendo um arquivo (segfault FFI, não capturável em
      // Dart), o path fica em scan_inprogress.txt e é blacklistado agora.
      // Em Android/iOS é inócuo (não usa audiotags).
      final crashedFile = await ScanCrashGuard.init();
      if (crashedFile != null) {
        debugPrint('[Main] previous scan crashed on: $crashedFile — skipping');
      }

      // Seleciona o backend de biblioteca de mídia para a plataforma atual.
      // Android/iOS: on_audio_query (MediaStore).
      // Windows/Linux/macOS: varredura de filesystem + audiotags.
      await MediaLibrary.init(
        windowsScanFolders:
            SettingsStorageService.loadMusicFolders() ?? const [],
      );

      // Cada serviço isolado: falha num não impede inicialização dos demais
      await Future.wait([
        LyricsService.init().catchError((Object e) {
          debugPrint('[Main] LyricsService.init failed: $e');
        }),
        AudioAnalysisService.loadCache().catchError((Object e) {
          debugPrint('[Main] AudioAnalysisService.loadCache failed: $e');
        }),
        BpmKeyFetchService.loadCache().catchError((Object e) {
          debugPrint('[Main] BpmKeyFetchService.loadCache failed: $e');
        }),
      ]);

      // AudioSession + audio_service só existem em Android/iOS.
      // Em desktop (Windows/Linux/macOS) instanciamos o handler diretamente
      // — sem notificação de mídia (será coberto por smtc_windows depois).
      late final ConstanzaAudioHandler audioHandler;
      if (Platform.isAndroid || Platform.isIOS) {
        // AudioSession configurada como um app de música padrão: requisita
        // audio focus (gain) e recebe eventos de interrupção. O handler
        // (ConstanzaAudioHandler) escuta interruptionEventStream e:
        //   • duck (SMS, notificação curta) → reduz volume temporariamente
        //   • pause (chamada, outro player) → pausa e retoma ao fim
        //   • becoming noisy (fones desconectados) → pausa
        // androidWillPauseWhenDucked:false garante que duck venha como tipo
        // 'duck' (e não 'pause'), permitindo só baixar o volume.
        try {
          final session = await AudioSession.instance;
          await session.configure(
            const AudioSessionConfiguration(
              avAudioSessionCategory: AVAudioSessionCategory.playback,
              avAudioSessionMode: AVAudioSessionMode.defaultMode,
              androidAudioAttributes: AndroidAudioAttributes(
                contentType: AndroidAudioContentType.music,
                usage: AndroidAudioUsage.media,
              ),
              androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
              androidWillPauseWhenDucked: false,
            ),
          );
        } catch (e) {
          debugPrint('[Main] AudioSession config failed: $e');
        }

        // Inicializa o AudioService (requer MainActivity extends AudioServiceFragmentActivity).
        // Se falhar (configuração errada de Activity no Manifest), o app ainda funciona
        // sem notificações — evita travar na tela inicial do Flutter.
        try {
          audioHandler = await AudioService.init<ConstanzaAudioHandler>(
            builder: () => ConstanzaAudioHandler(),
            config: const AudioServiceConfig(
              androidNotificationChannelId:
                  'com.constanza.constanza_player.audio',
              androidNotificationChannelName: 'Constanza Músicas',
              // ongoing:true impede o usuário de deslizar e matar o foreground
              // service enquanto tocando (notificação não-dispensável). Ao pausar,
              // o service sai de foreground (stopForegroundOnPause:true) — exigido
              // pelo audio_service quando ongoing:true.
              androidNotificationOngoing: true,
              androidStopForegroundOnPause: true,
              androidNotificationIcon: 'mipmap/ic_launcher',
              androidShowNotificationBadge: true,
              androidResumeOnClick: true,
            ),
          );
        } catch (e, st) {
          // Falha aqui = nenhuma notificação / controles de lockscreen (o app
          // cai num handler sem foreground service). debugPrint é mudo em
          // release, então persistimos no CrashReporter para diagnóstico —
          // visível em Configurações → logs.
          debugPrint('[Main] AudioService.init failed: $e');
          CrashReporter.recordNonFatal(
            e,
            stack: st,
            context: 'AudioService.init — notificação de mídia indisponível',
          );
          audioHandler = ConstanzaAudioHandler();
        }
      } else {
        // Desktop: handler standalone, sem foreground service.
        audioHandler = ConstanzaAudioHandler();
      }

      // Windows: liga o System Media Transport Controls (notificação de mídia
      // nativa + atalhos de teclado + Action Center). No-op em outras plats.
      if (Platform.isWindows) {
        try {
          await WindowsSmtcService.init(audioHandler);
        } catch (e) {
          debugPrint('[Main] SMTC init failed: $e');
        }
      }

      // UI imersiva — transparência total nas barras do sistema (mobile only).
      // SystemChrome.setEnabledSystemUIMode lança PlatformException em desktop.
      if (Platform.isAndroid || Platform.isIOS) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarContrastEnforced: false,
          ),
        );
      }

      runApp(
        ProviderScope(
          overrides: [audioHandlerProvider.overrideWithValue(audioHandler)],
          child: const ConstanzaApp(),
        ),
      );
    },
    (error, stack) {
      // Captura erros globais não tratados (zona raiz).
      // Persistidos em <AppDir>/crashes.jsonl via CrashReporter.readLogs().
      CrashReporter.recordZoneError(error, stack);
    },
  );
}

class ConstanzaApp extends ConsumerStatefulWidget {
  const ConstanzaApp({super.key});

  @override
  ConsumerState<ConstanzaApp> createState() => _ConstanzaAppState();
}

class _ConstanzaAppState extends ConsumerState<ConstanzaApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // ── Leitor padrão de áudio (NÃO pode depender de um frame) ─────────
    // Quando o app arranca pelo AudioOpenActivity e vai logo para trás
    // (leitor flutuante + moveTaskToBack), o Flutter é mandado para o fundo
    // ANTES de pintar o primeiro frame — e o addPostFrameCallback abaixo nunca
    // dispara. Se a drenagem/registos vivessem lá, a música não tocava e a capa
    // não carregava. Por isso correm já aqui, síncronos no initState.
    DefaultPlayerService.registerOpenHandler(_handleOpenAudio);
    // Leitor flutuante: ao fechar (X), para o push de progresso E a música.
    FloatingPlayerService.registerOnClosed(_onFloatingClosed);
    // Seek pela linha do tempo do leitor flutuante.
    FloatingPlayerService.registerOnSeek((ms) {
      ref.read(playerProvider.notifier).seek(Duration(milliseconds: ms));
    });
    // Cold start: drena o que ficou pendente do intent de abertura.
    // (Opens com o app já vivo são drenados em [didChangeAppLifecycleState].)
    _drainExternalOpens();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final router = ref.read(appRouterProvider);
      WidgetService.registerNavigationHandler((route) {
        // Deeplink especial: /sleep-timer abre o NowPlaying e mostra o sheet.
        if (route == '/sleep-timer') {
          router.go('/now-playing');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final ctx = router.routerDelegate.navigatorKey.currentContext;
            if (ctx != null && ctx.mounted) {
              showSleepTimerSheet(ctx);
            }
          });
        } else if (route == '/queue') {
          // Abre NowPlaying e empurra a Fila por cima.
          router.go('/now-playing');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final ctx = router.routerDelegate.navigatorKey.currentContext;
            if (ctx != null && ctx.mounted) {
              openQueuePage(ctx);
            }
          });
        } else {
          router.go(route);
        }
      });

      // O banner sugerindo virar leitor padrão aparece só DEPOIS do scan da
      // biblioteca — o usuário já viu o valor do app e a biblioteca está
      // populada. Dispara uma única vez, quando o status vai para `loaded`.
      ref.listenManual<LibraryState>(libraryProvider, (prev, next) {
        if (_promptHandled || _openedExternally) return;
        if (next.status == LibraryStatus.loaded) {
          _promptHandled = true;
          _maybePromptDefaultPlayer();
        }
      });
    });
  }

  @override
  void dispose() {
    _stopFloatingProgress();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App voltou ao primeiro plano: pode ter recebido um ACTION_VIEW enquanto
    // vivo (tocar OUTRA música pelo explorador). Puxamos o pendente aqui de
    // forma confiável — o nativo só o limpa após esta entrega.
    if (state == AppLifecycleState.resumed) {
      // O overlay é escondido nativamente ao voltar à frente; paramos o push.
      _stopFloatingProgress();
      _drainExternalOpens();
    }
  }

  /// Timer que empurra posição/duração para o leitor flutuante enquanto visível.
  Timer? _floatingTimer;

  /// Pede a permissão de overlay no máximo uma vez por sessão.
  bool _overlayPromptShown = false;

  void _startFloatingProgress() {
    _floatingTimer?.cancel();
    _floatingTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final st = ref.read(playerProvider);
      FloatingPlayerService.updateProgress(
        positionMs: st.position.inMilliseconds,
        durationMs: st.duration.inMilliseconds,
        isPlaying: st.isPlaying,
      );
    });
  }

  void _stopFloatingProgress() {
    _floatingTimer?.cancel();
    _floatingTimer = null;
  }

  /// X do leitor flutuante: para o push de progresso E a reprodução (fecha o
  /// leitor por completo). O overlay já foi removido nativamente; aqui paramos
  /// a música e o serviço de áudio para não continuar a tocar em background.
  void _onFloatingClosed() {
    _stopFloatingProgress();
    if (mounted) ref.read(playerProvider.notifier).stop();
  }

  /// Drena os áudios abertos externamente (cold start e retomada de foreground)
  /// e toca-os. O nativo entrega cada intent uma única vez (limpa ao consumir).
  void _drainExternalOpens() {
    DefaultPlayerService.consumePending().then((reqs) {
      if (reqs.isNotEmpty) {
        // Abrimos via "Abrir com" — não sugerir virar padrão nesta sessão.
        _openedExternally = true;
        _handleOpenAudio(reqs);
      }
    });
  }

  /// Evita sugerir virar padrão na mesma sessão em que abrimos via "Abrir com".
  bool _openedExternally = false;

  /// Garante que o banner pós-scan dispare no máximo uma vez por sessão.
  bool _promptHandled = false;

  /// Toca os áudios abertos externamente. Em vez de abrir o Now Playing
  /// inteiro, mostra um leitor flutuante sobre o explorador (se houver
  /// permissão de overlay); senão, cai no Now Playing como antes.
  Future<void> _handleOpenAudio(List<OpenAudioRequest> reqs) async {
    if (!mounted || reqs.isEmpty) return;
    // Eco do nosso próprio fluxo de "tornar padrão": o usuário escolheu
    // "Sempre" no resolver que abrimos com uma faixa de amostra. Não tocar
    // nem abrir o Now Playing — apenas confirmar que o app virou padrão.
    if (DefaultPlayerService.consumeSetDefaultEcho(reqs)) {
      _confirmBecameDefault();
      return;
    }
    final items = [for (final r in reqs) (uri: r.uri, title: r.title)];
    ref.read(playerProvider.notifier).playExternalAudio(items);

    // Leitor flutuante sobre o explorador, se a permissão estiver concedida.
    if (await FloatingPlayerService.hasPermission()) {
      final shown = await FloatingPlayerService.show();
      if (shown) {
        _startFloatingProgress();
        return;
      }
    } else if (!_overlayPromptShown) {
      // Pede a permissão uma vez; nesta 1ª abertura cai no Now Playing.
      _overlayPromptShown = true;
      FloatingPlayerService.requestPermission();
    }

    // Fallback: sem overlay, abre o Now Playing.
    if (mounted) ref.read(appRouterProvider).go('/now-playing');
  }

  /// Snackbar de confirmação após o app virar leitor padrão (sem tocar nada).
  void _confirmBecameDefault() {
    final ctx = ref
        .read(appRouterProvider)
        .routerDelegate
        .navigatorKey
        .currentContext;
    if (ctx == null || !ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(ctx).defaultPlayerSetConfirmed),
      ),
    );
  }

  /// Banner único (1º uso) sugerindo definir o Constanza como leitor padrão.
  /// Só em Android, só se ainda não somos o padrão e nunca foi exibido.
  Future<void> _maybePromptDefaultPlayer() async {
    if (!Platform.isAndroid || !mounted) return;
    if (SettingsStorageService.loadDefaultPlayerPromptShown()) return;
    if (await DefaultPlayerService.isDefault()) {
      // Já é o padrão — não precisa sugerir novamente.
      await SettingsStorageService.saveDefaultPlayerPromptShown(true);
      return;
    }
    if (!mounted) return;
    await SettingsStorageService.saveDefaultPlayerPromptShown(true);

    final ctx = ref
        .read(appRouterProvider)
        .routerDelegate
        .navigatorKey
        .currentContext;
    if (ctx == null || !ctx.mounted) return;
    final l10n = AppLocalizations.of(ctx);
    final messenger = ScaffoldMessenger.of(ctx);
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        content: Text(l10n.defaultPlayerBannerMessage),
        action: SnackBarAction(
          label: l10n.defaultPlayerBannerAction,
          onPressed: () => DefaultPlayerService.requestSetDefault(
            sampleAudioUri: _sampleAudioUri(),
          ),
        ),
      ),
    );
  }

  /// Primeira URI `content://` da biblioteca, usada para disparar o resolver
  /// "Abrir com" e o usuário escolher o Constanza como padrão.
  String? _sampleAudioUri() {
    for (final s in ref.read(libraryProvider).songs) {
      if (s.uri.startsWith('content://')) return s.uri;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final accent = themeState.accentColor;
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Constanza Músicas',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(accentColor: accent),
      darkTheme: AppTheme.dark(accentColor: accent),
      themeMode: themeState.themeMode,
      locale: themeState.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      // Desktop: empilha a title bar customizada sobre qualquer rota.
      // No modo mini-leitor a title bar some — a janela fica frameless
      // e o drag/controles ficam dentro da própria [MiniPlayerPage].
      // No mobile (Android/iOS/macOS) o builder devolve o child puro.
      builder: (context, child) {
        if (!Platform.isWindows && !Platform.isLinux) {
          return child ?? const SizedBox.shrink();
        }
        return ValueListenableBuilder<bool>(
          valueListenable: WindowModeService.isMiniNotifier,
          builder: (context, isMini, _) {
            final content = child ?? const SizedBox.shrink();
            // Fundo personalizado pintado UMA única vez, cobrindo a janela
            // inteira (inclusive atrás da title bar). Assim a imagem/gradiente
            // é contínuo: a title bar mostra a fatia de cima da MESMA imagem,
            // sem emenda. A [WindowsTitleBar] e o conteúdo (Scaffolds
            // transparentes) ficam por cima, e [BackgroundWrapper] vira
            // pass-through no desktop para não repintar um recorte diferente.
            final Widget body = isMini
                ? content
                : Column(
                    children: [
                      const WindowsTitleBar(),
                      Expanded(child: content),
                    ],
                  );
            return Stack(
              fit: StackFit.expand,
              children: [const AppBackgroundLayer(), body],
            );
          },
        );
      },
    );
  }
}
