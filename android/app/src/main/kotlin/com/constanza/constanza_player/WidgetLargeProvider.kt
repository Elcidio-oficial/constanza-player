package com.constanza.constanza_player

import android.appwidget.AppWidgetManager
import android.content.Context
import android.graphics.Bitmap
import android.widget.RemoteViews

/** Widget Grande — artwork quase full-width + título + controlos completos. */
class WidgetLargeProvider : BaseWidgetProvider() {
    override val layoutRes get() = R.layout.widget_large
    override val providerClass get() = WidgetLargeProvider::class.java
    // A capa é mostrada inteira (fitCenter) e não é recortada pela moldura,
    // por isso o arredondamento vem sempre no bitmap.
    override val artworkRadiusFraction: Float = 0.05f

    override fun bindViews(
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
    ) {
        val views = RemoteViews(context.packageName, layoutRes)

        views.setTextViewText(R.id.widget_title, title)
        views.setTextViewText(R.id.widget_artist, artist)
        views.setImageViewResource(R.id.widget_play_pause, playPauseRes)
        views.setImageViewResource(R.id.widget_favorite, favoriteDrawable(isFavorite))
        views.setImageViewResource(R.id.widget_repeat, repeatDrawable(repeatMode))
        if (artwork != null) {
            views.setImageViewBitmap(R.id.widget_artwork, artwork)
            // Tile atrás da capa na cor média da arte: preenche as sobras sem cortar a capa.
            views.setInt(R.id.widget_art_tile, "setColorFilter", backdropColor(artwork))
        }

        views.setOnClickPendingIntent(R.id.widget_prev,       pendingIntent(context, WidgetConstants.ACTION_PREV, 20))
        views.setOnClickPendingIntent(R.id.widget_play_pause, pendingIntent(context, WidgetConstants.ACTION_PLAY_PAUSE, 21))
        views.setOnClickPendingIntent(R.id.widget_next,       pendingIntent(context, WidgetConstants.ACTION_NEXT, 22))
        views.setOnClickPendingIntent(R.id.widget_repeat,     pendingIntent(context, WidgetConstants.ACTION_TOGGLE_REPEAT, 23))
        views.setOnClickPendingIntent(R.id.widget_favorite,   pendingIntent(context, WidgetConstants.ACTION_TOGGLE_FAV, 24))
        launchPendingIntent(context)?.let { views.setOnClickPendingIntent(R.id.widget_root, it) }

        mgr.updateAppWidget(widgetId, views)
    }

    /** Média real de 16×16 amostras (escalar para 1×1 apanha um só ponto da capa),
     *  escurecida para ficar um fundo discreto e não competir com a arte. */
    private fun backdropColor(art: Bitmap): Int {
        val small = Bitmap.createScaledBitmap(art, 16, 16, true)
        var r = 0L; var g = 0L; var b = 0L
        for (y in 0 until 16) for (x in 0 until 16) {
            val p = small.getPixel(x, y)
            r += (p shr 16) and 0xFF; g += (p shr 8) and 0xFF; b += p and 0xFF
        }
        if (small !== art) small.recycle()
        fun ch(sum: Long) = (sum / 256 * 0.45).toInt().coerceIn(0, 255)
        return (0xFF shl 24) or (ch(r) shl 16) or (ch(g) shl 8) or ch(b)
    }

    companion object {
        fun updateAllWidgets(context: Context) =
            BaseWidgetProvider.updateAllWidgets(context, WidgetLargeProvider::class.java)
    }
}
