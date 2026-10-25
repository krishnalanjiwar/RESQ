package com.darubaaz.resq

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Method channels used by Dart: the mesh foreground service and user alerts. */
object NativeChannels {
    private const val ALERT_CHANNEL_ID = "resq_alerts"

    fun register(context: Context, engine: FlutterEngine) {
        val app = context.applicationContext
        val messenger = engine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "resq/foreground").setMethodCallHandler { call, result ->
            val intent = Intent(app, MeshForegroundService::class.java)
            when (call.method) {
                "start" -> try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        app.startForegroundService(intent)
                    } else {
                        app.startService(intent)
                    }
                    result.success(true)
                } catch (e: Exception) {
                    // e.g. ForegroundServiceStartNotAllowedException or missing permission
                    result.success(false)
                }
                "stop" -> {
                    app.stopService(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, "resq/alerts").setMethodCallHandler { call, result ->
            when (call.method) {
                "notify" -> {
                    val id = call.argument<Int>("id") ?: 0
                    val title = call.argument<String>("title") ?: "RES-Q"
                    val body = call.argument<String>("body") ?: ""
                    result.success(showAlert(app, id, title, body))
                }
                else -> result.notImplemented()
            }
        }
    }

    /** High-importance alert with sound and vibration. Returns false if it couldn't be posted. */
    private fun showAlert(context: Context, id: Int, title: String, body: String): Boolean = try {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(ALERT_CHANNEL_ID, "RES-Q emergency alerts", NotificationManager.IMPORTANCE_HIGH)
            channel.enableVibration(true)
            manager.createNotificationChannel(channel)
        }
        val open = PendingIntent.getActivity(
            context, id, Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, ALERT_CHANNEL_ID)
        } else {
            Notification.Builder(context).setDefaults(Notification.DEFAULT_ALL).setPriority(Notification.PRIORITY_HIGH)
        }
        val notification = builder
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setSmallIcon(R.drawable.ic_stat_resq)
            .setColor(0xFF1A73E8.toInt())
            .setContentIntent(open)
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_ALARM)
            .build()
        manager.notify(id, notification)
        true
    } catch (e: Exception) {
        false
    }
}
