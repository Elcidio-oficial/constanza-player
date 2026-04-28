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
                invokeFlutter(context, "toggleFavorite")
                // Optimistic UI: alterna estado local e re-renderiza imediatamente.
                val prefs = context.getSharedPreferences(WidgetConstants.PREFS, Context.MODE_PRIVATE)
                val cur = prefs.getBoolean(WidgetConstants.KEY_IS_FAVORITE, false)
                prefs.edit().putBoolean(WidgetConstants.KEY_IS_FAVORITE, !cur).apply()
                updateAllWidgets(context, providerClass)
            }
            WidgetConstants.ACTION_TOGGLE_REPEAT -> {
                invokeFlutter(context, "cycleRepeatMode")
                val prefs = context.getSharedPreferences(WidgetConstants.PREFS, Context.MODE_PRIVATE)
                val cur = prefs.getInt(WidgetConstants.KEY_REPEAT_MODE, 0)
                prefs.edit().putInt(WidgetConstants.KEY_REPEAT_MODE, (cur + 1) % 3).apply()
                updateAllWidgets(context, providerClass)
            }
            WidgetConstants.ACTION_OPEN_SEARCH       -> openApp(context, "/search")
            WidgetConstants.ACTION_OPEN_QUEUE        -> openApp(context, "/now-playing")
            WidgetConstants.ACTION_OPEN_PLAYLISTS    -> openApp(context, "/playlists")
            WidgetConstants.ACTION_OPEN_SETTINGS     -> openApp(context, "/settings")
            WidgetConstants.ACTION_OPEN_NOW_PLAYING  -> openApp(context, "/now-playing")
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

    /** Invoca um método no Flutter via FlutterEngine cacheado. No-op se app está killed. */
    private fun invokeFlutter(context: Context, method: String) {
        val engine = FlutterEngineCache.getInstance().get(WidgetConstants.FLUTTER_ENGINE_ID) ?: return
        try {
            MethodChannel(engine.dartExecutor.binaryMessenger, WidgetConstants.WIDGET_CHANNEL)
                .invokeMethod(method, null)
        } catch (_: Exception) {
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
            val src = BitmapFactory.decodeFile(path) ?: return null
            val size = minOf(src.width, src.height)
            val sq = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(sq)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = BitmapShader(src, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP)
            }
            val r = size * radiusFraction
            canvas.drawRoundRect(RectF(0f, 0f, size.toFloat(), size.toFloat()), r, r, paint)
            sq
        } catch (_: Exception) { null }
    }

    companion object {
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
