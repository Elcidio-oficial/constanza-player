package com.constanza.constanza_player

import android.appwidget.AppWidgetManager
import android.content.Context
import android.graphics.Bitmap
import android.widget.RemoteViews

/** Widget Recomendado — artwork + transporte + grelha 2×2 de ações. */
class WidgetRecommendedProvider : BaseWidgetProvider() {
    override val layoutRes get() = R.layout.widget_recommended
    override val providerClass get() = WidgetRecommendedProvider::class.java

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
        if (artwork != null) views.setImageViewBitmap(R.id.widget_artwork, artwork)

        views.setOnClickPendingIntent(R.id.widget_prev,            pendingIntent(context, WidgetConstants.ACTION_PREV, 60))
        views.setOnClickPendingIntent(R.id.widget_play_pause,      pendingIntent(context, WidgetConstants.ACTION_PLAY_PAUSE, 61))
        views.setOnClickPendingIntent(R.id.widget_next,            pendingIntent(context, WidgetConstants.ACTION_NEXT, 62))
        views.setOnClickPendingIntent(R.id.widget_favorite,        pendingIntent(context, WidgetConstants.ACTION_TOGGLE_FAV, 63))
        views.setOnClickPendingIntent(R.id.widget_action_queue,    pendingIntent(context, WidgetConstants.ACTION_OPEN_NOW_PLAYING, 64))
        views.setOnClickPendingIntent(R.id.widget_action_playlist, pendingIntent(context, WidgetConstants.ACTION_OPEN_PLAYLISTS, 65))
        views.setOnClickPendingIntent(R.id.widget_action_sleep,    pendingIntent(context, WidgetConstants.ACTION_OPEN_SETTINGS, 66))
        launchPendingIntent(context)?.let { views.setOnClickPendingIntent(R.id.widget_root, it) }

        mgr.updateAppWidget(widgetId, views)
    }

    companion object {
        fun updateAllWidgets(context: Context) =
            BaseWidgetProvider.updateAllWidgets(context, WidgetRecommendedProvider::class.java)
    }
}
