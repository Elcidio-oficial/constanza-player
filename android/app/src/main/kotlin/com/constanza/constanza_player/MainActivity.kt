package com.constanza.constanza_player

// MainActivity DEVE estender AudioServiceFragmentActivity.
// Isso garante que o FlutterEngine partilhado seja o mesmo que o
// audio_service usa internamente (validado em AudioServicePlugin.java:315).
// Se usar FlutterActivity ou FlutterFragmentActivity simples, o plugin
// detecta um "wrong engine" e lança PlatformException ao iniciar.
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import com.ryanheise.audioservice.AudioServiceFragmentActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

// Única `FlutterActivity` do app — agarra o FlutterEngine partilhado do
// audio_service. O alvo dos intent-filters de áudio é o trampolim nativo
// [AudioOpenActivity] (NÃO-Flutter), que empurra a música por este motor ou
// reencaminha para cá a frio. Nunca há duas FlutterActivity a disputar o motor
// (era a causa do "engine evicted" → UI congelada).
class MainActivity : AudioServiceFragmentActivity() {

    /** Rota pendente vinda de um clique em widget. Drenada pelo Dart via
     *  MethodChannel "consumePendingRoute" assim que o handler estiver pronto. */
    private var pendingRoute: String? = null

    /** Áudio(s) abertos externamente (ACTION_VIEW / SEND), aguardando o Dart.
     *  Cada item é {"uri": ..., "title": ...}. Drenado por "consumePendingOpenUris"
     *  no cold start, ou empurrado via "openUris" quando o app já está vivo. */
    private var pendingOpenUris: List<Map<String, String?>> = emptyList()

    /** `true` quando o open externo deve mostrar o leitor flutuante e mandar o
     *  app para trás (em vez de aparecer a UI). Decidido na captura do intent e
     *  consumido em [onResume]. Falso no eco do fluxo "tornar padrão". */
    private var pendingFloatingShow = false

    // Marcador da faixa de amostra: ver o companion (estático, partilhado entre
    // [MainActivity] e [AudioOpenActivity] — quem dispara o "tornar padrão" é a
    // MainActivity, mas o eco do VIEW chega à AudioOpenActivity).

    /** Consome um único [onResume] transitório (o que segue um onNewIntent que
     *  já mostrou o overlay e fez moveTaskToBack no fluxo flutuante warm). */
    private var skipNextResumeReset = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Sinaliza ao trampolim que o engine está vivo/atado (ver [AudioOpenSupport.mainAlive]).
        AudioOpenSupport.mainAlive = true
        captureDeepLink(intent)
        captureOpenIntent(intent)
        maybeShowFloatingEarly()
    }

    /**
     * Arranque a frio por áudio (reencaminhado pelo trampolim [AudioOpenActivity]
     * com [AudioOpenSupport.EXTRA_RESOLVED]): pede janela TRANSPARENTE — o
     * FlutterFragmentActivity usa um `FlutterView` em TextureView, transparente,
     * por isso o explorador por baixo fica à vista enquanto o motor arranca e até
     * o [onResume] mandar a task para trás. Casa com o `AudioColdStartTheme`
     * (windowIsTranslucent). Os restantes arranques (ícone/LaunchTheme, eco do
     * "tornar padrão") ficam OPACOS — splash normal, sem regressão.
     */
    override fun getBackgroundMode(): BackgroundMode =
        if (intent?.hasExtra(AudioOpenSupport.EXTRA_RESOLVED) == true) {
            BackgroundMode.transparent
        } else {
            BackgroundMode.opaque
        }

    override fun onDestroy() {
        // Engine deixa de estar atado a uma activity: o trampolim deve reencaminhar
        // (não empurrar para um motor detached) até a MainActivity renascer.
        AudioOpenSupport.mainAlive = false
        super.onDestroy()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureDeepLink(intent)
        captureOpenIntent(intent)
        // App já vivo (warm): mostra o overlay e manda já a app para trás AQUI,
        // antes de o frame ser apresentado em onResume — assim o explorador
        // nunca chega a ser tapado pela UI.
        if (pendingFloatingShow) {
            if (FloatingPlayerManager.show(applicationContext) && moveTaskToBack(true)) {
                pendingFloatingShow = false
                // O onResume que se segue a este onNewIntent é apenas o eco de
                // voltarmos a primeiro plano antes do moveTaskToBack — não deve
                // esconder o overlay.
                skipNextResumeReset = true
                overridePendingTransition(0, 0)
            }
        }
        // App já está vivo: despacha a rota de widget imediatamente.
        dispatchPendingRoute()
        // NÃO empurramos os áudios aqui. O push (invokeMethod fire-and-forget)
        // limpava `pendingOpenUris` mesmo quando o Dart ainda não estava pronto
        // para processá-lo — perdendo a 2ª música aberta com o app vivo. Agora
        // o Dart PUXA o pendente ao voltar ao primeiro plano (lifecycle
        // `resumed` → consumePendingOpenUris), que é o único consumidor e só
        // limpa após entregar de fato.
    }

    private fun captureDeepLink(intent: Intent?) {
        val route = intent?.getStringExtra(WidgetConstants.EXTRA_DEEPLINK_ROUTE) ?: return
        pendingRoute = route
        intent.removeExtra(WidgetConstants.EXTRA_DEEPLINK_ROUTE)
    }

    private fun dispatchPendingRoute() {
        val route = pendingRoute ?: return
        val engine = FlutterEngineCache.getInstance().get(WidgetConstants.FLUTTER_ENGINE_ID) ?: return
        try {
            MethodChannel(engine.dartExecutor.binaryMessenger, WidgetConstants.WIDGET_CHANNEL)
                .invokeMethod("navigate", route)
            pendingRoute = null
        } catch (_: Exception) {
        }
    }

    // ===== Leitor padrão: abrir áudio externo ==========================

    /** Capta os áudios de um intent reencaminhado pelo trampolim [AudioOpenActivity]:
     *   • open real a frio → itens JÁ RESOLVIDOS (uri = caminho tocável) no extra
     *     [AudioOpenSupport.EXTRA_RESOLVED] — o trampolim resolveu com o grant que
     *     esta activity não tem;
     *   • eco do "tornar padrão" → intent original (URI do MediaStore), extraído
     *     aqui para o Dart confirmar sem tocar. */
    private fun captureOpenIntent(intent: Intent?) {
        val resolved = intent?.getStringExtra(AudioOpenSupport.EXTRA_RESOLVED)
        val items = if (resolved != null) {
            AudioOpenSupport.decodeItems(resolved)
        } else {
            AudioOpenSupport.extractAudioUris(this, intent)
        }
        if (items.isEmpty()) return
        pendingOpenUris = items

        // Open real (a frio) → mostrar o leitor flutuante (se houver permissão de
        // overlay) sem trazer a UI à frente. Suprimido só para o eco do nosso
        // próprio fluxo "tornar padrão" (a faixa de amostra), que abre a UI.
        val uris = items.mapNotNull { it["uri"] }
        pendingFloatingShow =
            !AudioOpenSupport.isSetDefaultEcho(uris) && FloatingPlayerManager.canDraw(this)
    }

    /** Mostra o leitor flutuante já na chegada do intent (antes de o Flutter
     *  pintar a Home), evitando o "flash" do app. O envio para trás acontece em
     *  [onResume], quando a activity está resumida. */
    private fun maybeShowFloatingEarly() {
        if (!pendingFloatingShow) return
        FloatingPlayerManager.show(applicationContext)
    }

    /** Verifica se o Constanza é o handler padrão para abrir arquivos de áudio. */
    private fun isDefaultAudioApp(): Boolean = try {
        val probe = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(Uri.parse("content://media/external/audio/media/1"), "audio/mpeg")
            addCategory(Intent.CATEGORY_DEFAULT)
        }
        val ri = packageManager.resolveActivity(probe, PackageManager.MATCH_DEFAULT_ONLY)
        ri?.activityInfo?.packageName == packageName
    } catch (_: Exception) {
        false
    }

    /** Dispara o resolver "Abrir com" para um áudio real, SEM createChooser —
     *  assim o sistema mostra os botões "Apenas uma vez / Sempre", deixando o
     *  usuário escolher o Constanza como padrão. É o único caminho real no
     *  Android moderno (a tela de settings só gerencia links da Web). Se não
     *  houver áudio disponível, cai no settings de "Abrir por padrão". */
    private fun openAudioChooser(uriString: String?) {
        if (uriString.isNullOrEmpty()) {
            openDefaultAppSettings()
            return
        }
        // Marca a amostra para suprimir o leitor flutuante no eco (ver
        // [AudioOpenSupport.isSetDefaultEcho]) — o Dart também a suprime para não
        // tocar/navegar. Estático e partilhado: o eco do VIEW chega ao trampolim
        // [AudioOpenActivity], instância/processo-task diferente desta.
        AudioOpenSupport.setDefaultSampleUri = uriString
        AudioOpenSupport.setDefaultAtMs = System.currentTimeMillis()
        try {
            val uri = Uri.parse(uriString)
            val type = try { contentResolver.getType(uri) } catch (_: Exception) { null }
                ?: "audio/*"
            // SEM FLAG_ACTIVITY_NEW_TASK: temos contexto de Activity, então o
            // intent fica na MESMA task. Com NEW_TASK (+ taskAffinity="") o
            // sistema cria uma 2ª instância da MainActivity ao resolver "Sempre"
            // de volta para nós — dois FlutterEngine concorrendo pelo engine
            // compartilhado do AudioService → tela preta. Na mesma task o
            // singleTop reaproveita a instância existente (onNewIntent).
            val view = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, type)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(view)
        } catch (_: Exception) {
            openDefaultAppSettings()
        }
    }

    /** Abre a tela de "Abrir por padrão" do app (ou o app-info como fallback). */
    private fun openDefaultAppSettings() {
        val pkgUri = Uri.fromParts("package", packageName, null)
        val candidates = mutableListOf<Intent>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            candidates.add(Intent("android.settings.APP_OPEN_BY_DEFAULT_SETTINGS", pkgUri))
        }
        candidates.add(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, pkgUri))
        candidates.add(Intent(Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS))
        for (i in candidates) {
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            try {
                startActivity(i)
                return
            } catch (_: Exception) {
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(AudioEffectsPlugin())
        flutterEngine.plugins.add(MediaNotificationPlugin())
        flutterEngine.plugins.add(MediaTagPlugin())
        flutterEngine.plugins.add(AudioAnalysisPlugin())

        // Cacheia o engine para que BroadcastReceivers (widgets) possam
        // invocar métodos no Dart enquanto o app/processo estiver vivo.
        FlutterEngineCache.getInstance().put(WidgetConstants.FLUTTER_ENGINE_ID, flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.constanza.screen")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "keepOn" -> {
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        result.success(null)
                    }
                    "release" -> {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WidgetConstants.WIDGET_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateWidget" -> {
                        val prefs = getSharedPreferences(WidgetConstants.PREFS, Context.MODE_PRIVATE)
                        prefs.edit().apply {
                            putString(WidgetConstants.KEY_TITLE,        call.argument("title"))
                            putString(WidgetConstants.KEY_ARTIST,       call.argument("artist"))
                            putBoolean(WidgetConstants.KEY_IS_PLAYING,  call.argument("isPlaying") ?: false)
                            putBoolean(WidgetConstants.KEY_IS_FAVORITE, call.argument("isFavorite") ?: false)
                            putInt(WidgetConstants.KEY_REPEAT_MODE,     call.argument("repeatMode") ?: 0)
                            call.argument<String>("artworkPath")?.let { putString(WidgetConstants.KEY_ARTWORK_PATH, it) }
                            apply()
                        }
                        MusicWidgetProvider.updateAllWidgets(this@MainActivity)
                        WidgetLargeProvider.updateAllWidgets(this@MainActivity)
                        WidgetMediumSearchProvider.updateAllWidgets(this@MainActivity)
                        WidgetCapsuleProvider.updateAllWidgets(this@MainActivity)
                        WidgetRecommendationProvider.updateAllWidgets(this@MainActivity)
                        WidgetRecommendedProvider.updateAllWidgets(this@MainActivity)
                        // Mesma fonte de dados alimenta o leitor flutuante.
                        FloatingPlayerManager.refresh(this@MainActivity)
                        result.success(null)
                    }
                    "consumePendingRoute" -> {
                        val r = pendingRoute
                        pendingRoute = null
                        result.success(r)
                    }
                    else -> result.notImplemented()
                }
            }

        // Canal do leitor padrão: drenar áudio aberto, checar/abrir defaults.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WidgetConstants.INTENT_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "consumePendingOpenUris" -> {
                        val r = pendingOpenUris
                        pendingOpenUris = emptyList()
                        result.success(r)
                    }
                    "isDefaultAudioApp" -> result.success(isDefaultAudioApp())
                    "openAudioChooser" -> {
                        openAudioChooser(call.argument<String>("uri"))
                        result.success(null)
                    }
                    "openDefaultAppSettings" -> {
                        openDefaultAppSettings()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // Canal do leitor flutuante (system overlay sobre o explorador).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WidgetConstants.FLOATING_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasOverlayPermission" -> result.success(FloatingPlayerManager.canDraw(this))
                    "requestOverlayPermission" -> {
                        requestOverlayPermission()
                        result.success(null)
                    }
                    "showFloatingPlayer" -> {
                        val shown = FloatingPlayerManager.show(applicationContext)
                        // Mostrado: volta o usuário ao explorador (app sai de frente).
                        if (shown) moveTaskToBack(true)
                        result.success(shown)
                    }
                    "hideFloatingPlayer" -> {
                        FloatingPlayerManager.hide()
                        result.success(null)
                    }
                    "updateFloatingProgress" -> {
                        FloatingPlayerManager.updateProgress(
                            applicationContext,
                            (call.argument<Number>("positionMs")?.toLong()) ?: 0L,
                            (call.argument<Number>("durationMs")?.toLong()) ?: 0L,
                            call.argument<Boolean>("isPlaying") ?: false,
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** Abre as Configurações para o usuário conceder "sobrepor a outras apps". */
    private fun requestOverlayPermission() {
        try {
            val i = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.fromParts("package", packageName, null),
            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(i)
        } catch (_: Exception) {
        }
    }

    override fun onResume() {
        super.onResume()
        // Eco transitório após o onNewIntent warm já ter tratado tudo: não mexer.
        if (skipNextResumeReset) {
            skipNextResumeReset = false
            return
        }
        // Open externo com permissão de overlay: garante o leitor flutuante e
        // manda o app para trás (volta ao explorador) SEM mostrar a UI. O Dart
        // inicia o playback ao drenar os áudios pendentes neste mesmo ciclo.
        if (pendingFloatingShow) {
            pendingFloatingShow = false
            if (FloatingPlayerManager.show(applicationContext)) {
                moveTaskToBack(true)
                overridePendingTransition(0, 0)
                return
            }
        }
        onForegroundResume()
    }

    /** Resume "normal": a app está mesmo em primeiro plano, por isso esconde o
     *  overlay para não se sobrepor à própria UI. */
    private fun onForegroundResume() {
        FloatingPlayerManager.hide()
    }

    // Nota: NÃO removemos a chave WidgetConstants.FLUTTER_ENGINE_ID no onDestroy.
    // O engine é partilhado e persistente (gerido pelo audio_service, sobrevive à
    // activity). Removê-la no destroy partiria o overlay/widgets (que invocam o
    // Dart por esta chave) enquanto a música ainda toca.
}
