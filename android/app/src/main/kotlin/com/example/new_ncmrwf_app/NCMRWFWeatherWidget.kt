package com.example.new_ncmrwf_app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.app.PendingIntent
import android.content.ComponentName

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

// ── Time-of-day period ────────────────────────────────────────────────────────
private enum class TimePeriod { DAWN, DAY, DUSK, NIGHT }

private fun timePeriod(hour: Int): TimePeriod = when {
    hour in 5..7   -> TimePeriod.DAWN
    hour in 8..17  -> TimePeriod.DAY
    hour in 18..20 -> TimePeriod.DUSK
    else           -> TimePeriod.NIGHT
}

// ── Condition → canonical group ───────────────────────────────────────────────
private enum class ConditionGroup {
    SUNNY, PARTLY_CLOUDY, CLOUDY, RAINY, STORMY, SNOWY, WINDY, DEFAULT
}

private fun conditionGroup(condition: String): ConditionGroup {
    val c = condition.trim().lowercase()
    return when {
        c.contains("thunder") || c.contains("storm")              -> ConditionGroup.STORMY
        c.contains("snow")    || c.contains("sleet")
                || c.contains("cold")               -> ConditionGroup.SNOWY
        c.contains("rain")    || c.contains("shower")
                || c.contains("drizzle")            -> ConditionGroup.RAINY
        c.contains("wind")                                        -> ConditionGroup.WINDY
        c.contains("fog")     || c.contains("haze")
                || c.contains("mist")
                || c.contains("overcast")
                || (c.contains("cloudy") &&
                !c.contains("partly") &&
                !c.contains("mostly"))           -> ConditionGroup.CLOUDY
        c.contains("partly")  || c.contains("mostly cloudy")
                || c.contains("few clouds")         -> ConditionGroup.PARTLY_CLOUDY
        c.contains("sunny")   || c.contains("clear")
                || c.contains("hot")
                || c.contains("fair")
                || c.contains("mostly sunny")
                || c.contains("mostly clear")       -> ConditionGroup.SUNNY
        else                                                      -> ConditionGroup.DEFAULT
    }
}

// ── Layout selector ───────────────────────────────────────────────────────────
// Returns the layout resource ID for the given condition + hour.
// Each layout is identical in structure — only the background drawable differs.
// This is the correct way to theme widgets: switch the entire RemoteViews layout.
private fun widgetLayout(context: Context, condition: String, hour: Int): Int {
    val group  = conditionGroup(condition)
    val period = timePeriod(hour)

    val layoutName = "weather_widget_" + when (group) {
        ConditionGroup.SUNNY -> when (period) {
            TimePeriod.DAWN  -> "sunny_dawn"
            TimePeriod.DAY   -> "sunny_day"
            TimePeriod.DUSK  -> "sunny_dusk"
            TimePeriod.NIGHT -> "sunny_night"
        }
        ConditionGroup.PARTLY_CLOUDY -> when (period) {
            TimePeriod.DAWN  -> "partly_cloudy_dawn"
            TimePeriod.DAY   -> "partly_cloudy_day"
            TimePeriod.DUSK  -> "partly_cloudy_dusk"
            TimePeriod.NIGHT -> "partly_cloudy_night"
        }
        ConditionGroup.CLOUDY -> when (period) {
            TimePeriod.DAWN  -> "cloudy_dawn"
            TimePeriod.DAY   -> "cloudy_day"
            TimePeriod.DUSK  -> "cloudy_dusk"
            TimePeriod.NIGHT -> "cloudy_night"
        }
        ConditionGroup.RAINY -> when (period) {
            TimePeriod.DAWN  -> "rainy_dawn"
            TimePeriod.DAY   -> "rainy_day"
            TimePeriod.DUSK  -> "rainy_dusk"
            TimePeriod.NIGHT -> "rainy_night"
        }
        ConditionGroup.STORMY -> when (period) {
            TimePeriod.DAWN  -> "stormy_dawn"
            TimePeriod.DAY   -> "stormy_day"
            TimePeriod.DUSK  -> "stormy_dusk"
            TimePeriod.NIGHT -> "stormy_night"
        }
        ConditionGroup.SNOWY -> when (period) {
            TimePeriod.DAWN  -> "snowy_dawn"
            TimePeriod.DAY   -> "snowy_day"
            TimePeriod.DUSK  -> "snowy_dusk"
            TimePeriod.NIGHT -> "snowy_night"
        }
        ConditionGroup.WINDY -> when (period) {
            TimePeriod.DAWN  -> "windy_dawn"
            TimePeriod.DAY   -> "windy_day"
            TimePeriod.DUSK  -> "windy_dusk"
            TimePeriod.NIGHT -> "windy_night"
        }
        ConditionGroup.DEFAULT -> when (period) {
            TimePeriod.DAWN  -> "default_dawn"
            TimePeriod.DAY   -> "default_day"
            TimePeriod.DUSK  -> "default_dusk"
            TimePeriod.NIGHT -> "default_night"
        }
    }

    val resId = context.resources.getIdentifier(layoutName, "layout", context.packageName)
    // Fall back to original layout if something goes wrong
    return if (resId != 0) resId
    else context.resources.getIdentifier("weather_widget", "layout", context.packageName)
}

// ─────────────────────────────────────────────────────────────────────────────
fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
    try {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        fun get(key: String, def: String) =
            prefs.getString("flutter.$key", null) ?: prefs.getString(key, def) ?: def

        val location    = get("location",    "Open app")
        val temperature = get("temperature", "--")
        val condition   = get("condition",   "---")
        val feelsLike   = get("feels_like",  "--")
        val humidity    = get("humidity",    "--")
        val wind        = get("wind",        "--")
        val pressure    = get("pressure",    "--")

        // ── Hour: prefer what Flutter sent, fall back to device clock ─────────
        val hourStr = get("hour", "")
        val hour    = hourStr.toIntOrNull()
            ?: java.util.Calendar.getInstance().get(java.util.Calendar.HOUR_OF_DAY)

        // ── Pick the themed layout — this is what actually changes the background
        val layoutResId = widgetLayout(context, condition, hour)
        val views = RemoteViews(context.packageName, layoutResId)

        // ── Text content ──────────────────────────────────────────────────────
        views.setTextViewText(R.id.tv_location,       location)
        views.setTextViewText(R.id.tv_temperature,    "$temperature°")
        views.setTextViewText(R.id.tv_condition,      condition)
        views.setTextViewText(R.id.tv_feels_like,     "Feels like $feelsLike°C")
        views.setTextViewText(R.id.tv_humidity,       "$humidity%")
        views.setTextViewText(R.id.tv_wind,           "$wind km/h")
        views.setTextViewText(R.id.tv_pressure,       "$pressure mb")
        views.setTextViewText(R.id.tv_condition_icon, conditionEmoji(condition))

        // ── 4-day forecast ────────────────────────────────────────────────────
        val dayIds  = listOf(R.id.tv_fc_day_0,  R.id.tv_fc_day_1,  R.id.tv_fc_day_2,  R.id.tv_fc_day_3)
        val iconIds = listOf(R.id.tv_fc_icon_0, R.id.tv_fc_icon_1, R.id.tv_fc_icon_2, R.id.tv_fc_icon_3)
        val tempIds = listOf(R.id.tv_fc_temp_0, R.id.tv_fc_temp_1, R.id.tv_fc_temp_2, R.id.tv_fc_temp_3)

        for (i in 0..3) {
            views.setTextViewText(dayIds[i],  get("fc_day_$i",  "---"))
            views.setTextViewText(iconIds[i], conditionEmoji(get("fc_cond_$i", "")))
            views.setTextViewText(tempIds[i], "${get("fc_temp_$i", "--")}°")
        }

        // ── Tap: open app ─────────────────────────────────────────────────────
        val launchIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
            setPackage(context.packageName)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
        }
        val pending = PendingIntent.getActivity(
            context,
            appWidgetId,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_root,   pending)
        views.setOnClickPendingIntent(R.id.forecast_pill, pending)

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