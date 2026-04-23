package com.constanza.constanza_player

import android.app.Notification
import android.app.NotificationManager
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.service.notification.StatusBarNotification
import android.util.Log
import androidx.palette.graphics.Palette
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Plugin que força cores dinâmicas na notificação de mídia.
 *
 * Estratégia dupla:
 * 1. setColorized(true) + setColor() — para skins (HiOS, MIUI, ColorOS)
 * 2. setLargeIcon() com bitmap — garante artwork visível em todos devices
 *
 * Watcher re-aplica periodicamente porque o audio_service recria a
 * notificação a cada mudança de estado (play/pause/seek/skip).
 */
class MediaNotificationPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private var appContext: Context? = null
    private val handler = Handler(Looper.getMainLooper())
    private var lastColor: Int? = null
    private var lastBitmap: Bitmap? = null
    private var watcherRunnable: Runnable? = null
    @Volatile private var processJobId = 0

    companion object {
        private const val TAG = "MediaNotifPlugin"
        private const val WATCH_INTERVAL = 500L
        // Watcher dura 10s — cobre play/pause que recria a notificação
        private const val WATCH_DURATION = 30000L
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.constanza.media_notification")
        channel.setMethodCallHandler(this)
        appContext = binding.applicationContext
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        processJobId = Int.MAX_VALUE // invalidate any pending jobs
        stopWatcher()
        handler.removeCallbacksAndMessages(null)
        synchronized(this) {
            lastBitmap?.recycle()
            lastBitmap = null
        }
        appContext = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "updateFromArtwork" -> {
                val bytes = call.argument<ByteArray>("bytes")
                if (bytes == null || bytes.isEmpty()) {
                    result.success(false)
                    return
                }
                processArtwork(bytes)
                result.success(true)
            }
            "updateColor" -> {
                val color = call.argument<Number>("color")?.toInt()
                if (color == null) {
                    result.success(false)
                    return
                }
                lastColor = color
                Log.d(TAG, "updateColor: #${Integer.toHexString(color)}")
                applyAndWatch()
                result.success(true)
            }
            "reapplyColor" -> {
                if (lastColor != null) {
                    Log.d(TAG, "reapplyColor: #${Integer.toHexString(lastColor!!)}")
                    applyAndWatch()
                }
                result.success(lastColor != null)
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Processa artwork: extrai cor via Palette API, guarda bitmap, aplica.
     *
     * Thread-safe: usa jobId para descartar resultados de chamadas antigas.
     * Operações em bitmap são sincronizadas para evitar crash por bitmap reciclado.
     */
    private fun processArtwork(bytes: ByteArray) {
        val myJobId = ++processJobId
        Thread {
            try {
                val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: return@Thread

                // Descartar resultado se já há uma chamada mais recente
                if (myJobId != processJobId) {
                    bitmap.recycle()
                    return@Thread
                }

                // Bitmap para large icon da notificação (max 256px para eficiência)
                val maxDim = 256
                val scale = if (bitmap.width > maxDim || bitmap.height > maxDim) {
                    maxDim.toFloat() / maxOf(bitmap.width, bitmap.height)
                } else 1f
                val iconBitmap = if (scale < 1f) {
                    Bitmap.createScaledBitmap(
                        bitmap,
                        (bitmap.width * scale).toInt(),
                        (bitmap.height * scale).toInt(),
                        true
                    )
                } else bitmap

                // Palette extraction — usar bitmap pequeno para performance
                val paletteBitmap = Bitmap.createScaledBitmap(bitmap, 64, 64, true)
                val palette = Palette.from(paletteBitmap).generate()

                val swatch = palette.vibrantSwatch
                    ?: palette.lightVibrantSwatch
                    ?: palette.mutedSwatch
                    ?: palette.dominantSwatch

                // Verificar novamente antes de aplicar (pular rápido pode ter avançado)
                if (myJobId != processJobId) {
                    if (paletteBitmap !== bitmap && paletteBitmap !== iconBitmap) paletteBitmap.recycle()
                    if (bitmap !== iconBitmap) bitmap.recycle()
                    if (iconBitmap !== bitmap) iconBitmap.recycle()
                    return@Thread
                }

                if (swatch != null) {
                    Log.d(TAG, "Extracted color #${Integer.toHexString(swatch.rgb)} from artwork")
                    lastColor = swatch.rgb
                }

                // Guardar bitmap de forma sincronizada para evitar race condition
                val oldBitmap: Bitmap?
                synchronized(this) {
                    oldBitmap = lastBitmap
                    lastBitmap = iconBitmap
                }
                if (paletteBitmap !== bitmap && paletteBitmap !== iconBitmap) paletteBitmap.recycle()
                if (bitmap !== iconBitmap) bitmap.recycle()
                oldBitmap?.recycle()

                handler.post { applyAndWatch() }
            } catch (e: Exception) {
                Log.e(TAG, "processArtwork error: ${e.message}")
            }
        }.start()
    }

    private fun applyAndWatch() {
        applyToNotification()
        startWatcher()
    }

    private fun startWatcher() {
        stopWatcher()
        val colorSnapshot = lastColor
        var elapsed = 0L
        val runnable = object : Runnable {
            override fun run() {
                elapsed += WATCH_INTERVAL
                if (elapsed > WATCH_DURATION || lastColor != colorSnapshot) return

                applyToNotification()
                handler.postDelayed(this, WATCH_INTERVAL)
            }
        }
        watcherRunnable = runnable
        handler.postDelayed(runnable, WATCH_INTERVAL)
    }

    private fun stopWatcher() {
        watcherRunnable?.let { handler.removeCallbacks(it) }
        watcherRunnable = null
    }

    /**
     * Encontra a notificação de mídia e aplica:
     * - setColorized(true) + setColor() para fundo colorido
     * - setLargeIcon() para garantir artwork visível
     */
    private fun applyToNotification(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        val context = appContext ?: return false
        val color = lastColor ?: return false

        try {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val active = nm.activeNotifications
            if (active.isEmpty()) {
                Log.d(TAG, "No active notifications found")
                return false
            }

            val notif = findMediaNotification(active, context)
            if (notif == null) {
                Log.d(TAG, "Media notification not found among ${active.size} active")
                return false
            }

            val existing = notif.notification

            // Verificar se já está correto (evitar re-post desnecessário)
            val alreadyColorized = existing.extras.getBoolean(Notification.EXTRA_COLORIZED, false)
            if (existing.color == color && alreadyColorized) {
                return true
            }

            val builder = Notification.Builder.recoverBuilder(context, existing)
            builder.setColorized(true)
            builder.setColor(color)

            // Aplicar bitmap como large icon se disponível (sincronizado)
            synchronized(this) { lastBitmap }?.let { bmp ->
                if (!bmp.isRecycled) builder.setLargeIcon(bmp)
            }

            val built = builder.build()
            if (notif.tag != null) {
                nm.notify(notif.tag, notif.id, built)
            } else {
                nm.notify(notif.id, built)
            }
            Log.d(TAG, "Applied color #${Integer.toHexString(color)} to notification ID ${notif.id}")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "applyToNotification error: ${e.message}")
            return false
        }
    }

    private fun findMediaNotification(
        notifications: Array<StatusBarNotification>,
        context: Context
    ): StatusBarNotification? {
        // ID exato do audio_service
        val byId = notifications.find { it.id == 1124 }
        if (byId != null) return byId

        // Fallback: qualquer notificação do nosso package
        return notifications.find { it.packageName == context.packageName }
    }
}
