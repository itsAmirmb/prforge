package com.prforge.prforge

import android.Manifest
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.pm.PackageManager
import android.content.Intent
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Vibration, beep and keep-screen-on for the workout screen (no plugin
// needed). Dart side: core/feedback/feedback_service.dart.
// Also forwards the headset button long-press (VOICE_COMMAND intent) to Dart:
// core/feedback/headset_service.dart.
class MainActivity : FlutterActivity() {
    private var headsetChannel: MethodChannel? = null

    // The app is already running (singleTop) when the intent arrives. A cold
    // start is ignored on purpose: there is no workout screen to act on yet.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.action == Intent.ACTION_VOICE_COMMAND) {
            headsetChannel?.invokeMethod("trigger", null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        headsetChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "prforge/headset")
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "prforge/feedback")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "vibrate" -> {
                        vibrate(call.arguments as? List<*>)
                        result.success(null)
                    }
                    "beep" -> {
                        Tones.play(call.arguments as? String)
                        result.success(null)
                    }
                    "scheduleRestEnd" -> {
                        scheduleRestEnd(call.arguments as? Map<*, *>)
                        result.success(null)
                    }
                    "cancelRestEnd" -> {
                        cancelRestEnd()
                        result.success(null)
                    }
                    "requestNotificationPermission" -> {
                        requestNotificationPermission()
                        result.success(null)
                    }
                    "keepScreenOn" -> {
                        keepScreenOn(call.arguments as? Boolean ?: false)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /// Pattern in ms: off, on, off, on ...
    @Suppress("DEPRECATION")
    private fun vibrate(pattern: List<*>?) {
        val timings = pattern?.mapNotNull { (it as? Number)?.toLong() } ?: return
        if (timings.isEmpty()) return
        val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator ?: return
        if (!vibrator.hasVibrator()) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(VibrationEffect.createWaveform(timings.toLongArray(), -1))
        } else {
            vibrator.vibrate(timings.toLongArray(), -1)
        }
    }

    private fun keepScreenOn(on: Boolean) {
        if (on) {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }

    // ───────── Rest-over alarm (works with the screen off) ─────────

    // Request code 1 = rest over, 2 = short warning before it.
    private fun restAlarmIntent(
        extras: Map<*, *>?,
        code: Int = 1,
        warning: Boolean = false
    ): PendingIntent {
        val intent = Intent(this, RestAlarmReceiver::class.java)
        intent.putExtra("warning", warning)
        if (extras != null) {
            intent.putExtra("sound", extras["sound"] as? Boolean ?: true)
            intent.putExtra("vibration", extras["vibration"] as? Boolean ?: true)
            intent.putExtra("title", extras["title"] as? String ?: "")
            intent.putExtra("body", extras["body"] as? String ?: "")
            intent.putExtra("warnCount", (extras["warnSeconds"] as? Number)?.toInt() ?: 1)
        }
        return PendingIntent.getBroadcast(
            this, code, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    // Scheduling again with the same PendingIntent replaces the old alarm.
    private fun scheduleRestEnd(args: Map<*, *>?) {
        val at = (args?.get("atMillis") as? Number)?.toLong() ?: return
        val alarms = getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val exactAllowed =
            Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarms.canScheduleExactAlarms()
        fun set(time: Long, pending: PendingIntent) {
            try {
                if (exactAllowed) {
                    alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time, pending)
                } else {
                    alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time, pending)
                }
            } catch (_: SecurityException) {
                alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time, pending)
            }
        }
        set(at, restAlarmIntent(args))
        val warnAt = (args["warnAtMillis"] as? Number)?.toLong()
        if (warnAt != null) {
            set(warnAt, restAlarmIntent(args, 2, true))
        } else {
            alarms.cancel(restAlarmIntent(null, 2, true))
        }
    }

    private fun cancelRestEnd() {
        val alarms = getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        alarms.cancel(restAlarmIntent(null))
        alarms.cancel(restAlarmIntent(null, 2, true))
    }

    // Only the notification needs this; sound and vibration work without it.
    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 7)
        }
    }
}
