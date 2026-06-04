package com.constanza.constanza_player

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.RectF
import android.graphics.Shader
import android.os.Build
import android.provider.Settings
import android.view.Gravity
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.SeekBar
import android.widget.TextView
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import kotlin.math.abs

/**
 * Leitor flutuante (system overlay) exibido ao tocar um áudio pelo explorador.
 *
 * Desenha um card por cima de qualquer app via [WindowManager] (requer a
 * permissão SYSTEM_ALERT_WINDOW). Reutiliza o pipeline dos widgets: os dados
 * (título/artista/capa/estado) vêm do mesmo [WidgetConstants.PREFS], e os
 * botões usam o mesmo `ACTION_MEDIA_BUTTON` que chega ao audio_service.
 *
 * Progresso (posição/duração) é empurrado pelo Dart enquanto o overlay vive.
 */
object FloatingPlayerManager {

    private var view: View? = null
    private var windowManager: WindowManager? = null
    private var params: WindowManager.LayoutParams? = null

    /** Última duração conhecida (ms) — base para converter o seek em posição. */
    private var lastDurationMs: Long = 0L

    /** `true` enquanto o utilizador arrasta a SeekBar — suspende o push de
     *  progresso para o polegar não saltar de volta sob os dedos. */
    private var userSeeking: Boolean = false

    val isShowing: Boolean get() = view != null

    /** `true` se o app pode desenhar por cima de outras apps. */
    fun canDraw(ctx: Context): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) Settings.canDrawOverlays(ctx) else true

    /** Mostra o overlay (idempotente). Devolve `false` se não há permissão. */
    fun show(ctx: Context): Boolean {
        if (!canDraw(ctx)) return false
        if (isShowing) {
            refresh(ctx)
            return true
        }
        val wm = ctx.getSystemService(Context.WINDOW_SERVICE) as? WindowManager ?: return false
        val root = View.inflate(ctx, R.layout.floating_player, null)

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else
            @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE

        val lp = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            // NOT_FOCUSABLE + NOT_TOUCH_MODAL: o overlay recebe toques nos seus
            // botões mas deixa o resto passar para a app por baixo (explorador).
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            y = dp(ctx, 72)
        }

        wireControls(ctx, root, wm, lp)

        try {
            wm.addView(root, lp)
        } catch (_: Exception) {
            return false
        }
        view = root
        windowManager = wm
        params = lp
        refresh(ctx)
        return true
    }

    /** Remove o overlay. */
    fun hide() {
        val v = view
        val wm = windowManager
        if (v != null && wm != null) {
            try { wm.removeView(v) } catch (_: Exception) {}
        }
        view = null
        windowManager = null
        params = null
    }

    /** Atualiza título/artista/capa/ícone de play a partir dos prefs dos widgets. */
    fun refresh(ctx: Context) {
        val v = view ?: return
        val prefs = ctx.getSharedPreferences(WidgetConstants.PREFS, Context.MODE_PRIVATE)
        val title = prefs.getString(WidgetConstants.KEY_TITLE, "Constanza Músicas") ?: ""
        val artist = prefs.getString(WidgetConstants.KEY_ARTIST, "") ?: ""
        val isPlaying = prefs.getBoolean(WidgetConstants.KEY_IS_PLAYING, false)
        val artPath = prefs.getString(WidgetConstants.KEY_ARTWORK_PATH, null)

        v.findViewById<TextView>(R.id.floating_title)?.text = title
        v.findViewById<TextView>(R.id.floating_artist)?.apply {
            text = artist
            visibility = if (artist.isBlank()) View.GONE else View.VISIBLE
        }
        v.findViewById<ImageButton>(R.id.floating_play_pause)?.setImageResource(
            if (isPlaying) R.drawable.ic_widget_pause else R.drawable.ic_widget_play
        )
        val art = v.findViewById<ImageView>(R.id.floating_artwork)
        val bmp = artPath?.let { loadRoundedBitmap(it) }
        if (bmp != null) art?.setImageBitmap(bmp) else art?.setImageResource(R.mipmap.ic_launcher)
    }

    /** Atualiza a barra de progresso e tempos (empurrado pelo Dart). */
    fun updateProgress(ctx: Context, positionMs: Long, durationMs: Long, isPlaying: Boolean) {
        val v = view ?: return
        lastDurationMs = durationMs
        // Enquanto o utilizador arrasta, não sobrescrevemos posição/polegar.
        if (!userSeeking) {
            val sb = v.findViewById<SeekBar>(R.id.floating_progress)
            if (durationMs > 0) {
                sb?.progress = ((positionMs.toDouble() / durationMs) * 1000).toInt().coerceIn(0, 1000)
            } else {
                sb?.progress = 0
            }
            v.findViewById<TextView>(R.id.floating_position)?.text = fmt(positionMs)
        }
        v.findViewById<TextView>(R.id.floating_duration)?.text = fmt(durationMs)
        v.findViewById<ImageButton>(R.id.floating_play_pause)?.setImageResource(
            if (isPlaying) R.drawable.ic_widget_pause else R.drawable.ic_widget_play
        )
    }

    // ── Internos ────────────────────────────────────────────────────────

    private fun wireControls(
        ctx: Context,
        root: View,
        wm: WindowManager,
        lp: WindowManager.LayoutParams,
    ) {
        root.findViewById<ImageButton>(R.id.floating_play_pause)?.setOnClickListener {
            sendMediaButton(ctx, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE)
        }
        root.findViewById<ImageButton>(R.id.floating_close)?.setOnClickListener {
            hide()
            notifyClosed(ctx)
        }

        // Linha do tempo arrastável: ao largar, faz seek na música via Dart.
        // (A SeekBar consome os seus próprios toques, logo não dispara o drag
        //  do card abaixo — ver listener do card.)
        root.findViewById<SeekBar>(R.id.floating_progress)?.setOnSeekBarChangeListener(
            object : SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(sb: SeekBar, progress: Int, fromUser: Boolean) {
                    if (fromUser && lastDurationMs > 0) {
                        val pos = progress.toLong() * lastDurationMs / 1000L
                        root.findViewById<TextView>(R.id.floating_position)?.text = fmt(pos)
                    }
                }
                override fun onStartTrackingTouch(sb: SeekBar) { userSeeking = true }
                override fun onStopTrackingTouch(sb: SeekBar) {
                    userSeeking = false
                    if (lastDurationMs > 0) {
                        notifySeek(ctx, sb.progress.toLong() * lastDurationMs / 1000L)
                    }
                }
            }
        )

        // Arraste vertical do card para reposicionar. Toque simples NÃO faz nada
        // (sem abrir o app) — apenas mover. Botões/SeekBar tratam dos seus toques.
        val card = root.findViewById<View>(R.id.floating_card)
        var startY = 0f
        var startParamY = 0
        card?.setOnTouchListener { _, ev ->
            when (ev.action) {
                MotionEvent.ACTION_DOWN -> {
                    startY = ev.rawY
                    startParamY = lp.y
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dy = (ev.rawY - startY).toInt()
                    if (abs(dy) > dp(ctx, 2)) {
                        lp.y = (startParamY + dy).coerceAtLeast(0)
                        try { wm.updateViewLayout(root, lp) } catch (_: Exception) {}
                    }
                    true
                }
                MotionEvent.ACTION_UP -> true
                else -> false
            }
        }
    }

    /** Avisa o Dart para fazer seek na música até [positionMs]. */
    private fun notifySeek(ctx: Context, positionMs: Long) {
        val engine = FlutterEngineCache.getInstance().get(WidgetConstants.FLUTTER_ENGINE_ID) ?: return
        try {
            MethodChannel(engine.dartExecutor.binaryMessenger, WidgetConstants.FLOATING_CHANNEL)
                .invokeMethod("onFloatingSeek", positionMs)
        } catch (_: Exception) {}
    }

    private fun sendMediaButton(ctx: Context, keyCode: Int) {
        val pkg = ctx.packageName
        ctx.sendBroadcast(Intent(Intent.ACTION_MEDIA_BUTTON).apply {
            setPackage(pkg)
            putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
        })
        ctx.sendBroadcast(Intent(Intent.ACTION_MEDIA_BUTTON).apply {
            setPackage(pkg)
            putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_UP, keyCode))
        })
    }

    /** Avisa o Dart que o overlay foi fechado (para parar o push de progresso). */
    private fun notifyClosed(ctx: Context) {
        val engine = FlutterEngineCache.getInstance().get(WidgetConstants.FLUTTER_ENGINE_ID) ?: return
        try {
            MethodChannel(engine.dartExecutor.binaryMessenger, WidgetConstants.FLOATING_CHANNEL)
                .invokeMethod("onFloatingClosed", null)
        } catch (_: Exception) {}
    }

    private fun fmt(ms: Long): String {
        if (ms <= 0) return "0:00"
        val totalSec = ms / 1000
        val m = totalSec / 60
        val s = totalSec % 60
        return "$m:${s.toString().padStart(2, '0')}"
    }

    private fun dp(ctx: Context, value: Int): Int =
        (value * ctx.resources.displayMetrics.density).toInt()

    private fun loadRoundedBitmap(path: String): Bitmap? {
        return try {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(path, bounds)
            val srcW = bounds.outWidth
            val srcH = bounds.outHeight
            if (srcW <= 0 || srcH <= 0) return null
            val target = 256
            var sample = 1
            while ((srcW / (sample * 2)) >= target && (srcH / (sample * 2)) >= target) sample *= 2
            val opts = BitmapFactory.Options().apply {
                inSampleSize = sample
                inPreferredConfig = Bitmap.Config.ARGB_8888
            }
            val src = BitmapFactory.decodeFile(path, opts) ?: return null
            val size = minOf(src.width, src.height)
            val sq = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(sq)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = BitmapShader(src, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP)
            }
            val r = size * 0.16f
            canvas.drawRoundRect(RectF(0f, 0f, size.toFloat(), size.toFloat()), r, r, paint)
            if (src !== sq) src.recycle()
            sq
        } catch (_: Exception) { null }
    }
}
