package com.constanza.constanza_player

import android.appwidget.AppWidgetManager
import android.content.Context
import android.graphics.Bitmap
import android.widget.RemoteViews

/** Widget Médio — artwork grande esquerda + título/artista + controlos completos. */
class MusicWidgetProvider : BaseWidgetProvider() {
    override val layoutRes get() = R.layout.music_widget
    override val providerClass get() = MusicWidgetProvider::class.java

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
        if (artwork != null) views.setImageViewBitmap(R.id.widget_artwork, artwork)

        views.setOnClickPendingIntent(R.id.widget_prev,       pendingIntent(context, WidgetConstants.ACTION_PREV, 10))
        views.setOnClickPendingIntent(R.id.widget_play_pause, pendingIntent(context, WidgetConstants.ACTION_PLAY_PAUSE, 11))
        views.setOnClickPendingIntent(R.id.widget_next,       pendingIntent(context, WidgetConstants.ACTION_NEXT, 12))
        views.setOnClickPendingIntent(R.id.widget_repeat,     pendingIntent(context, WidgetConstants.ACTION_TOGGLE_REPEAT, 13))
        views.setOnClickPendingIntent(R.id.widget_favorite,   pendingIntent(context, WidgetConstants.ACTION_TOGGLE_FAV, 14))
        launchPendingIntent(context)?.let { views.setOnClickPendingIntent(R.id.widget_root, it) }

        mgr.updateAppWidget(widgetId, views)
    }

    companion object {
        fun updateAllWidgets(context: Context) =
            BaseWidgetProvider.updateAllWidgets(context, MusicWidgetProvider::class.java)
    }
}
