package com.constanza.constanza_player

import android.appwidget.AppWidgetManager
import android.content.Context
import android.graphics.Bitmap
import android.widget.RemoteViews

/** Widget Médio + Pesquisa — linha compacta + barra de pesquisa que abre a app. */
class WidgetMediumSearchProvider : BaseWidgetProvider() {
    override val layoutRes get() = R.layout.widget_medium_search
    override val providerClass get() = WidgetMediumSearchProvider::class.java

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
        if (artwork != null) views.setImageViewBitmap(R.id.widget_artwork, artwork)

        views.setOnClickPendingIntent(R.id.widget_prev,       pendingIntent(context, WidgetConstants.ACTION_PREV, 30))
        views.setOnClickPendingIntent(R.id.widget_play_pause, pendingIntent(context, WidgetConstants.ACTION_PLAY_PAUSE, 31))
        views.setOnClickPendingIntent(R.id.widget_next,       pendingIntent(context, WidgetConstants.ACTION_NEXT, 32))
        views.setOnClickPendingIntent(R.id.widget_search,     pendingIntent(context, WidgetConstants.ACTION_OPEN_SEARCH, 33))
        launchPendingIntent(context)?.let { views.setOnClickPendingIntent(R.id.widget_root, it) }

        mgr.updateAppWidget(widgetId, views)
    }

    companion object {
        fun updateAllWidgets(context: Context) =
            BaseWidgetProvider.updateAllWidgets(context, WidgetMediumSearchProvider::class.java)
    }
}
