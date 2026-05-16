package com.constanza.constanza_player

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.view.KeyEvent
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

abstract class BaseWidgetProvider : AppWidgetProvider() {

    abstract val layoutRes: Int
    abstract val providerClass: Class<*>

    /** Fração do tamanho da arte usada como raio de canto. 0.5 = circular. */
    protected open val artworkRadiusFraction: Float = 0.08f

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) {
            updateWidget(context, appWidgetManager, id)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            WidgetConstants.ACTION_PREV       -> sendMediaButton(context, KeyEvent.KEYCODE_MEDIA_PREVIOUS)
            WidgetConstants.ACTION_PLAY_PAUSE -> sendMediaButton(context, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE)
            WidgetConstants.ACTION_NEXT       -> sendMediaButton(context, KeyEvent.KEYCODE_MEDIA_NEXT)
            WidgetConstants.ACTION_TOGGLE_FAV -> {
                // Só optimistic-update se o engine estiver vivo. Caso contrário,
                // o estado real não vai mudar e teríamos um "ghost state" no widget.
                if (invokeFlutter(context, "toggleFavorite")) {
                    val prefs = context.getSharedPreferences(WidgetConstants.PREFS, Context.MODE_PRIVATE)
                    val cur = prefs.getBoolean(WidgetConstants.KEY_IS_FAVORITE, false)
                    prefs.edit().putBoolean(WidgetConstants.KEY_IS_FAVORITE, !cur).apply()
                    refreshAllProviders(context)
                }
            }
            WidgetConstants.ACTION_TOGGLE_REPEAT -> {
                if (invokeFlutter(context, "cycleRepeatMode")) {
                    val prefs = context.getSharedPreferences(WidgetConstants.PREFS, Context.MODE_PRIVATE)
                    val cur = prefs.getInt(WidgetConstants.KEY_REPEAT_MODE, 0)
                    prefs.edit().putInt(WidgetConstants.KEY_REPEAT_MODE, (cur + 1) % 3).apply()
                    refreshAllProviders(context)
                }
            }
            WidgetConstants.ACTION_OPEN_SEARCH       -> openApp(context, "/search")
            WidgetConstants.ACTION_OPEN_QUEUE        -> openApp(context, "/queue")
            WidgetConstants.ACTION_OPEN_PLAYLISTS    -> openApp(context, "/playlists")
            WidgetConstants.ACTION_OPEN_SETTINGS     -> openApp(context, "/settings")
            WidgetConstants.ACTION_OPEN_NOW_PLAYING  -> openApp(context, "/now-playing")
            WidgetConstants.ACTION_OPEN_SLEEP_TIMER  -> openApp(context, "/sleep-timer")
        }
    }

    protected fun updateWidget(context: Context, mgr: AppWidgetManager, widgetId: Int) {
        val prefs = context.getSharedPreferences(WidgetConstants.PREFS, Context.MODE_PRIVATE)
        val title      = prefs.getString(WidgetConstants.KEY_TITLE, "Constanza Músicas") ?: "Constanza Músicas"
        val artist     = prefs.getString(WidgetConstants.KEY_ARTIST, "Sua música. Seu momento.") ?: ""
        val isPlaying  = prefs.getBoolean(WidgetConstants.KEY_IS_PLAYING, false)
        val artPath    = prefs.getString(WidgetConstants.KEY_ARTWORK_PATH, null)
        val isFavorite = prefs.getBoolean(WidgetConstants.KEY_IS_FAVORITE, false)
        val repeatMode = prefs.getInt(WidgetConstants.KEY_REPEAT_MODE, 0)

        val artwork = artPath?.let { loadRoundedBitmap(it, artworkRadiusFraction) }
        val playPauseRes = if (isPlaying) R.drawable.ic_widget_pause else R.drawable.ic_widget_play

        bindViews(context, mgr, widgetId, title, artist, isPlaying, artwork, playPauseRes, isFavorite, repeatMode)
    }

    /** Subclasses bind RemoteViews for their specific layout. */
    abstract fun bindViews(
        context: Context,
        mgr: AppWidgetManager,
        widgetId: Int,
        title: String,
        artist: String,
        isPlaying: Boolean,
        artwork: Bitmap?,
        playPauseRes: Int,
        isFavorite: Boolean,
        repeatMode: Int,
    )

    protected fun pendingIntent(context: Context, action: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, providerClass).apply { this.action = action }
        return PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    protected fun launchPendingIntent(context: Context): PendingIntent? {
        val i = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: return null
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return PendingIntent.getActivity(context, 0, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    /** Resolve drawable atual para o botão repeat com base no modo. */
    protected fun repeatDrawable(repeatMode: Int): Int = when (repeatMode) {
        1 -> R.drawable.ic_widget_repeat_all
        2 -> R.drawable.ic_widget_repeat_one
        else -> R.drawable.ic_widget_repeat_off
    }

    /** Drawable para favorito conforme estado. */
    protected fun favoriteDrawable(isFavorite: Boolean): Int =
        if (isFavorite) R.drawable.ic_favorite else R.drawable.ic_favorite_border

    private fun sendMediaButton(context: Context, keyCode: Int) {
        val pkg = context.packageName
        val down = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
            setPackage(pkg)
            putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
        }
        val up = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
            setPackage(pkg)
            putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_UP, keyCode))
        }
        context.sendBroadcast(down)
        context.sendBroadcast(up)
    }

    /** Invoca um método no Flutter via FlutterEngine cacheado.
     *  Retorna `true` se o engine estava vivo e a chamada foi enviada; `false` se o app
     *  está killed — nesse caso o caller não deve fazer optimistic update no prefs. */
    private fun invokeFlutter(context: Context, method: String): Boolean {
        val engine = FlutterEngineCache.getInstance().get(WidgetConstants.FLUTTER_ENGINE_ID)
            ?: return false
        return try {
            MethodChannel(engine.dartExecutor.binaryMessenger, WidgetConstants.WIDGET_CHANNEL)
                .invokeMethod(method, null)
            true
        } catch (_: Exception) {
            false
        }
    }

    /** Refresha TODOS os providers de widget — necessário porque o utilizador pode
     *  ter widgets de classes diferentes (Music + Large + Capsule…) na mesma tela,
     *  e mudar fav/repeat afeta o estado global de reprodução. */
    private fun refreshAllProviders(context: Context) {
        for (cls in ALL_PROVIDERS) {
            updateAllWidgets(context, cls)
        }
    }

    private fun openApp(context: Context, route: String? = null) {
        val i = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: return
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        if (route != null) i.putExtra(WidgetConstants.EXTRA_DEEPLINK_ROUTE, route)
        context.startActivity(i)
    }

    private fun loadRoundedBitmap(path: String, radiusFraction: Float): Bitmap? {
        return try {
            // 1) Lê só os metadados — sem alocar pixels.
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(path, bounds)
            val srcW = bounds.outWidth
            val srcH = bounds.outHeight
            if (srcW <= 0 || srcH <= 0) return null

            // 2) Subsample para alvo ~256px (suficiente para qualquer slot de widget;
            //    evita ANR/OOM em artwork 2000×2000 que poderia ocupar ~16MB).
            val target = 256
            var sample = 1
            while ((srcW / (sample * 2)) >= target && (srcH / (sample * 2)) >= target) {
                sample *= 2
            }
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
            val r = size * radiusFraction
            canvas.drawRoundRect(RectF(0f, 0f, size.toFloat(), size.toFloat()), r, r, paint)
            if (src !== sq) src.recycle()
            sq
        } catch (_: Exception) { null }
    }

    companion object {
        private val ALL_PROVIDERS: List<Class<*>> = listOf(
            MusicWidgetProvider::class.java,
            WidgetLargeProvider::class.java,
            WidgetMediumSearchProvider::class.java,
            WidgetCapsuleProvider::class.java,
            WidgetRecommendationProvider::class.java,
            WidgetRecommendedProvider::class.java,
        )

        fun updateAllWidgets(context: Context, providerClass: Class<*>) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, providerClass))
            if (ids.isNotEmpty()) {
                context.sendBroadcast(
                    Intent(context, providerClass).apply {
                        action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                    }
                )
            }
        }
    }
}
