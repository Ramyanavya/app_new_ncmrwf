package com.example.new_ncmrwf_app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import android.app.PendingIntent
import android.content.ComponentName
import android.net.Uri

class NCMRWFWeatherWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, id)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        try {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, NCMRWFWeatherWidget::class.java))
            if (ids.isNotEmpty()) onUpdate(context, mgr, ids)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}

fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
    try {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        fun get(key: String, def: String) =
            prefs.getString("flutter.$key", null) ?: prefs.getString(key, def) ?: def

        val location  = get("location",    "Open app")
        val temperature = get("temperature", "--")
        val condition = get("condition",   "---")
        val feelsLike = get("feels_like",  "--")
        val humidity  = get("humidity",    "--")
        val wind      = get("wind",        "--")
        val pressure  = get("pressure",    "--")

        val views = RemoteViews(context.packageName, R.layout.weather_widget)

        views.setTextViewText(R.id.tv_location,       location)
        views.setTextViewText(R.id.tv_temperature,    "$temperature°")
        views.setTextViewText(R.id.tv_condition,      condition)
        views.setTextViewText(R.id.tv_feels_like,     "Feels like $feelsLike°C")
        views.setTextViewText(R.id.tv_humidity,       "$humidity%")
        views.setTextViewText(R.id.tv_wind,           "$wind km/h")
        views.setTextViewText(R.id.tv_pressure,       "$pressure mb")
        views.setTextViewText(R.id.tv_condition_icon, conditionEmoji(condition))

        val dayIds  = listOf(R.id.tv_fc_day_0,  R.id.tv_fc_day_1,  R.id.tv_fc_day_2,  R.id.tv_fc_day_3)
        val iconIds = listOf(R.id.tv_fc_icon_0, R.id.tv_fc_icon_1, R.id.tv_fc_icon_2, R.id.tv_fc_icon_3)
        val tempIds = listOf(R.id.tv_fc_temp_0, R.id.tv_fc_temp_1, R.id.tv_fc_temp_2, R.id.tv_fc_temp_3)

        for (i in 0..3) {
            views.setTextViewText(dayIds[i],  get("fc_day_$i",  "---"))
            views.setTextViewText(iconIds[i], conditionEmoji(get("fc_cond_$i", "")))
            views.setTextViewText(tempIds[i], "${get("fc_temp_$i", "--")}°")
        }

        // ── Tap: open app ──────────────────────────────────────────
        val launchIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
            setPackage(context.packageName)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
        }
        val pending = PendingIntent.getActivity(
            context,
            appWidgetId,          // use appWidgetId so each widget gets unique PendingIntent
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        // Set click on root AND on pill (both tappable areas)
        views.setOnClickPendingIntent(R.id.widget_root,    pending)
        views.setOnClickPendingIntent(R.id.forecast_pill,  pending)

        appWidgetManager.updateAppWidget(appWidgetId, views)

    } catch (e: Exception) {
        e.printStackTrace()
    }
}

fun conditionEmoji(condition: String): String {
    val c = condition.trim().lowercase()
    return when {
        c.contains("sunny")         -> "☀️"
        c.contains("clear")         -> "☀️"
        c.contains("hot")           -> "☀️"
        c.contains("fair")          -> "☀️"
        c.contains("mostly sunny")  -> "🌤️"
        c.contains("mostly clear")  -> "🌤️"
        c.contains("few clouds")    -> "🌤️"
        c.contains("partly")        -> "⛅"
        c.contains("mostly cloudy") -> "🌥️"
        c.contains("overcast")      -> "🌥️"
        c.contains("cloudy")        -> "☁️"
        c.contains("rain")          -> "🌧️"
        c.contains("shower")        -> "🌧️"
        c.contains("drizzle")       -> "🌧️"
        c.contains("thunder")       -> "⛈️"
        c.contains("storm")         -> "⛈️"
        c.contains("snow")          -> "🌨️"
        c.contains("sleet")         -> "🌨️"
        c.contains("fog")           -> "🌫️"
        c.contains("haze")          -> "🌫️"
        c.contains("mist")          -> "🌫️"
        c.contains("wind")          -> "💨"
        else                        -> "🌤️"
    }
}