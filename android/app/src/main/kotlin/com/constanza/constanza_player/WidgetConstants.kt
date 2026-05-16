package com.constanza.constanza_player

object WidgetConstants {
    const val PREFS = "widget_prefs"
    const val KEY_TITLE = "widget_title"
    const val KEY_ARTIST = "widget_artist"
    const val KEY_IS_PLAYING = "widget_is_playing"
    const val KEY_ARTWORK_PATH = "widget_artwork_path"
    const val KEY_IS_FAVORITE = "widget_is_favorite"
    const val KEY_REPEAT_MODE = "widget_repeat_mode" // 0=off, 1=all, 2=one

    const val ACTION_PREV          = "com.constanza.constanza_player.WIDGET_PREV"
    const val ACTION_PLAY_PAUSE    = "com.constanza.constanza_player.WIDGET_PLAY_PAUSE"
    const val ACTION_NEXT          = "com.constanza.constanza_player.WIDGET_NEXT"
    const val ACTION_OPEN_SEARCH   = "com.constanza.constanza_player.WIDGET_OPEN_SEARCH"
    const val ACTION_OPEN_QUEUE    = "com.constanza.constanza_player.WIDGET_OPEN_QUEUE"
    const val ACTION_TOGGLE_FAV    = "com.constanza.constanza_player.WIDGET_TOGGLE_FAV"
    const val ACTION_TOGGLE_REPEAT = "com.constanza.constanza_player.WIDGET_TOGGLE_REPEAT"
    const val ACTION_OPEN_PLAYLISTS    = "com.constanza.constanza_player.WIDGET_OPEN_PLAYLISTS"
    const val ACTION_OPEN_SETTINGS     = "com.constanza.constanza_player.WIDGET_OPEN_SETTINGS"
    const val ACTION_OPEN_NOW_PLAYING  = "com.constanza.constanza_player.WIDGET_OPEN_NOW_PLAYING"
    const val ACTION_OPEN_SLEEP_TIMER  = "com.constanza.constanza_player.WIDGET_OPEN_SLEEP_TIMER"

    const val EXTRA_DEEPLINK_ROUTE = "deeplink_route"

    const val FLUTTER_ENGINE_ID = "constanza_main_engine"
    const val WIDGET_CHANNEL    = "com.constanza.constanza_player/widget"
}
