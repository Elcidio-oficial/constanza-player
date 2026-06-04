package com.constanza.constanza_player

import android.app.Activity
import android.app.ActivityOptions
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

/**
 * Trampolim **nativo puro** (sem Flutter) — alvo dos intent-filters de áudio.
 *
 * ⚠️ NÃO pode ser uma `FlutterActivity`/`FlutterFragmentActivity`. O motor do
 * audio_service é ÚNICO e partilhado: se esta activity o agarrasse, "despejava"
 * (evict) a `FlutterFragment` da [MainActivity] → UI congelada (bug confirmado
 * em logcat: "connection to the engine ... evicted by another attaching activity").
 *
 * Fluxo (esta activity NUNCA toca no motor):
 *  • **Eco do "tornar padrão"**: reencaminha o intent ORIGINAL à [MainActivity],
 *    que confirma (sem tocar) — a deteção do eco compara a URI original.
 *  • **Open real**: resolve cada `content://` do explorador para um caminho de
 *    ficheiro tocável (o ExoPlayer NÃO recebe o grant do FileProvider — ver
 *    SecurityException no logcat). A resolução corre numa thread (a cópia pode
 *    demorar). Depois:
 *      – **a quente** (motor vivo): mostra o overlay e EMPURRA pelo motor
 *        existente (`openUris`). Sem flash.
 *      – **a frio** (sem motor): reencaminha os itens JÁ RESOLVIDOS à
 *        [MainActivity], que arranca o motor e toca.
 */
class AudioOpenActivity : Activity() {

    /** Garante um único `moveTaskToBack` por entrada (onCreate/onNewIntent). */
    private var movedToBack = false
    /** `true` no fluxo a quente, enquanto resolvemos em background. */
    private var lingering = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        route(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        movedToBack = false
        route(intent)
    }

    override fun onResume() {
        super.onResume()
        // A quente: devolve o foco/toques ao explorador por baixo enquanto
        // resolvemos. Uma activity translúcida sem conteúdo, à frente, "comeria"
        // os toques. A activity continua VIVA → o grant sobrevive à resolução.
        if (lingering && !movedToBack) {
            movedToBack = true
            moveTaskToBack(true)
            overridePendingTransition(0, 0)
        }
    }

    private fun route(intent: Intent?) {
        val rawItems = AudioOpenSupport.extractAudioUris(applicationContext, intent)
        if (rawItems.isEmpty()) {
            finish()
            return
        }

        // Eco do "tornar padrão": reencaminha o ORIGINAL (sem resolver) para a
        // MainActivity confirmar — a supressão no Dart compara a URI original.
        val uris = rawItems.mapNotNull { it["uri"] }
        if (AudioOpenSupport.isSetDefaultEcho(uris)) {
            forwardOriginal(intent)
            finish()
            return
        }

        // "A quente" = MainActivity VIVA (engine atado). NÃO basta o engine estar
        // em cache: pós-recentes ele fica detached e o push falha em silêncio.
        val warm = AudioOpenSupport.mainAlive
        if (warm && FloatingPlayerManager.canDraw(applicationContext)) {
            // Feedback imediato; os dados reais chegam quando o Dart toca.
            FloatingPlayerManager.show(applicationContext)
        }
        lingering = warm

        // Resolve fora da main thread (a cópia para cache pode demorar). O grant
        // está ativo enquanto esta activity vive — só fechamos no fim.
        Thread {
            val playable = AudioOpenSupport.toPlayableItems(applicationContext, rawItems)
            runOnUiThread {
                deliver(playable, warm)
                finish()
            }
        }.start()
    }

    /** Entrega os itens resolvidos: a quente empurra pelo motor; a frio
     *  reencaminha para a [MainActivity] arrancar e tocar. */
    private fun deliver(items: List<Map<String, String?>>, warm: Boolean) {
        if (items.isEmpty()) return
        if (warm) {
            val engine = FlutterEngineCache.getInstance().get(WidgetConstants.FLUTTER_ENGINE_ID)
            if (engine != null) {
                try {
                    MethodChannel(
                        engine.dartExecutor.binaryMessenger, WidgetConstants.INTENT_CHANNEL,
                    ).invokeMethod("openUris", items)
                    return
                } catch (_: Exception) {
                }
            }
            // Motor desapareceu entretanto → cai no arranque a frio.
        }
        forwardResolved(items)
    }

    /** Arranque a frio: leva os itens JÁ RESOLVIDOS à MainActivity (ela não tem
     *  o grant do content:// para os resolver). Aponta para o ALIAS
     *  `MainActivityAudioOpen` (mesma activity/engine, tema sem splash) → arranca
     *  sem o vislumbre da app antes de ir para trás. */
    private fun forwardResolved(items: List<Map<String, String?>>) {
        try {
            val fwd = Intent().apply {
                setClassName(packageName, "$packageName.MainActivityAudioOpen")
                action = Intent.ACTION_VIEW
                putExtra(AudioOpenSupport.EXTRA_RESOLVED, AudioOpenSupport.encodeItems(items))
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                // No reuso (instância já criada a frio antes), evita a animação
                // de re-entrada e reaproveita a task em vez de a reabrir à frente.
                addFlags(Intent.FLAG_ACTIVITY_NO_ANIMATION)
            }
            // Animação de abertura a zero: no arranque a frio reduz o vislumbre
            // da app a "entrar" antes de ir logo para trás (o MIUI tem animação
            // própria de cold start, mas isto anula a transição padrão).
            val opts = ActivityOptions.makeCustomAnimation(this, 0, 0).toBundle()
            startActivity(fwd, opts)
            overridePendingTransition(0, 0)
        } catch (_: Exception) {
        }
    }

    /** Eco do "tornar padrão": reencaminha o intent original (com o grant) para
     *  a MainActivity confirmar que virou padrão. */
    private fun forwardOriginal(intent: Intent?) {
        intent ?: return
        try {
            val fwd = Intent(intent).apply {
                setClass(this@AudioOpenActivity, MainActivity::class.java)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(fwd)
        } catch (_: Exception) {
        }
    }
}
