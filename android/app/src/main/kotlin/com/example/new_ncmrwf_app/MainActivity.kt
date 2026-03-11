package com.example.new_ncmrwf_app

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.new_ncmrwf_app/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "updateWidget") {
                    try {
                        val prefs: SharedPreferences = getSharedPreferences(
                            "FlutterSharedPreferences", Context.MODE_PRIVATE
                        )
                        val editor = prefs.edit()
                        call.arguments<Map<String, String>>()?.forEach { (key, value) ->
                            editor.putString("flutter.$key", value)
                        }
                        editor.apply()

                        // Trigger widget refresh
                        val mgr = AppWidgetManager.getInstance(this)
                        val ids = mgr.getAppWidgetIds(
                            ComponentName(this, NCMRWFWeatherWidget::class.java)
                        )
                        if (ids.isNotEmpty()) {
                            val intent = Intent(this, NCMRWFWeatherWidget::class.java).apply {
                                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                            }
                            sendBroadcast(intent)
                        }
                        result.success("Widget updated")
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}