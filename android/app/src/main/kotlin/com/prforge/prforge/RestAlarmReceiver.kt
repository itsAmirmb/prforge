package com.prforge.prforge

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.app.Notification

// Fired by AlarmManager when a rest ends while the app is in the background
// (screen off / locked). A Dart timer does not run then, so the OS does the
// waiting. Plays the beep, vibrates and posts a notification (which also lights
// the screen). Scheduled from MainActivity.scheduleRestEnd.
class RestAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pending = goAsync()
        if (intent.getBooleanExtra("warning", false)) {
            countdown(context, intent, pending)
            return
        }
        val sound = intent.getBooleanExtra("sound", true)
        val vibration = intent.getBooleanExtra("vibration", true)
        if (vibration) vibrate(context, longArrayOf(0, 300, 150, 300))
        if (sound) Tones.play("final")
        notify(
            context,
            intent.getStringExtra("title") ?: "",
            intent.getStringExtra("body") ?: "",
        )
        // Keep the receiver alive until the tone has finished.
        Handler(Looper.getMainLooper()).postDelayed({ pending.finish() }, 900)
    }

    // Beeps once a second for the last seconds of the rest ("ding ding ding");
    // the long final beep comes from the end alarm. A wake lock keeps the
    // phone awake for these few seconds while the screen is off.
    private fun countdown(
        context: Context,
        intent: Intent,
        pending: PendingResult
    ) {
        val count = intent.getIntExtra("warnCount", 1).coerceIn(1, 8)
        val sound = intent.getBooleanExtra("sound", true)
        val vibration = intent.getBooleanExtra("vibration", true)
        val power = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        val lock = power?.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "prforge:countdown")
        lock?.acquire(count * 1000L + 1500L)
        val handler = Handler(Looper.getMainLooper())
        for (i in 0 until count) {
            handler.postDelayed({
                if (sound) Tones.play("tick")
                if (vibration) vibrate(context, longArrayOf(0, 40))
            }, i * 1000L)
        }
        handler.postDelayed({
            if (lock?.isHeld == true) lock.release()
            pending.finish()
        }, count * 1000L)
    }

    @Suppress("DEPRECATION")
    private fun vibrate(context: Context, pattern: LongArray) {
        val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator ?: return
        if (!vibrator.hasVibrator()) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
        } else {
            vibrator.vibrate(pattern, -1)
        }
    }

    private fun notify(context: Context, title: String, body: String) {
        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Silent channel: the receiver plays the sound itself so the
            // Settings sound/vibration toggles keep working.
            val channel = NotificationChannel(
                CHANNEL_ID, "Rest timer", NotificationManager.IMPORTANCE_HIGH
            )
            channel.setSound(null, null)
            channel.enableVibration(false)
            manager.createNotificationChannel(channel)
        }
        val open = PendingIntent.getActivity(
            context, 0,
            Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            Notification.Builder(context).setPriority(Notification.PRIORITY_HIGH)
        }
        val notification = builder
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText(body)
            .setCategory(Notification.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setContentIntent(open)
            .build()
        try {
            manager.notify(NOTIFICATION_ID, notification)
        } catch (_: SecurityException) {
            // Notification permission not granted: sound and vibration still played.
        }
    }

    companion object {
        private const val CHANNEL_ID = "rest_over"
        private const val NOTIFICATION_ID = 41
    }
}
