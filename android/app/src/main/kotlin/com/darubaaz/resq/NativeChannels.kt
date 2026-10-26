package com.darubaaz.resq

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.RingtoneManager
import android.media.ToneGenerator
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Method channels used by Dart: the mesh foreground service and user alerts. */
object NativeChannels {
    private const val ALERT_CHANNEL_ID = "resq_alerts"

    // Channel settings are frozen once created; bump the id to change the sound.
    private const val RING_CHANNEL_ID = "resq_ring_v1"

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
                "ring" -> {
                    val id = call.argument<Int>("id") ?: 0
                    val title = call.argument<String>("title") ?: "RES-Q"
                    val body = call.argument<String>("body") ?: ""
                    val tapStops = call.argument<Boolean>("tapStops") ?: true
                    result.success(ring(app, id, title, body, tapStops))
                }
                "stopRing" -> {
                    val manager = app.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    manager.cancel(call.argument<Int>("id") ?: 0)
                    result.success(true)
                }
                "tone" -> {
                    playTone(call.argument<String>("kind") ?: "tap")
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Alarm-style alert whose sound repeats (FLAG_INSISTENT) until the
     * notification is cancelled from Dart, tapped (if [tapStops]) or the
     * shade is opened. Uses the alarm sound and stream so it is hard to miss.
     */
    private fun ring(context: Context, id: Int, title: String, body: String, tapStops: Boolean): Boolean = try {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val sound = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
        val pattern = longArrayOf(0, 900, 400, 900, 400, 900)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(RING_CHANNEL_ID, "RES-Q urgent ringing", NotificationManager.IMPORTANCE_HIGH)
            channel.setSound(
                sound,
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            channel.enableVibration(true)
            channel.vibrationPattern = pattern
            channel.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            manager.createNotificationChannel(channel)
        }
        val open = PendingIntent.getActivity(
            context, id, Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, RING_CHANNEL_ID)
        } else {
            Notification.Builder(context)
                .setSound(sound, AudioManager.STREAM_ALARM)
                .setVibrate(pattern)
                .setPriority(Notification.PRIORITY_MAX)
        }
        val notification = builder
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setSmallIcon(R.drawable.ic_stat_resq)
            .setColor(0xFFEA4335.toInt())
            .setContentIntent(open)
            .setAutoCancel(tapStops)
            .setOngoing(!tapStops)
            .setCategory(Notification.CATEGORY_ALARM)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .build()
        notification.flags = notification.flags or Notification.FLAG_INSISTENT
        manager.notify(id, notification)
        true
    } catch (e: Exception) {
        false
    }

    /** Short interface sounds; quiet, on the notification stream. */
    private fun playTone(kind: String) {
        try {
            val (tone, ms) = when (kind) {
                "success" -> ToneGenerator.TONE_PROP_ACK to 180
                "send" -> ToneGenerator.TONE_PROP_PROMPT to 220
                "warn" -> ToneGenerator.TONE_PROP_NACK to 200
                else -> ToneGenerator.TONE_PROP_BEEP to 40
            }
            val generator = ToneGenerator(AudioManager.STREAM_NOTIFICATION, 60)
            generator.startTone(tone, ms)
            Handler(Looper.getMainLooper()).postDelayed({ generator.release() }, ms + 120L)
        } catch (e: Exception) {
            // No audio available: sounds are a nicety, never required.
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
