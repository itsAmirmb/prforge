package com.prforge.prforge

import android.content.Context
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Vibration, beep and keep-screen-on for the workout screen (no plugin
// needed). Dart side: core/feedback/feedback_service.dart.
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "prforge/feedback")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "vibrate" -> {
                        vibrate(call.arguments as? List<*>)
                        result.success(null)
                    }
                    "beep" -> {
                        beep()
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

    /// Plays on the media volume, so it is audible with headphones too.
    private fun beep() {
        try {
            val tone = ToneGenerator(AudioManager.STREAM_MUSIC, 80)
            tone.startTone(ToneGenerator.TONE_PROP_BEEP2, 400)
            Handler(Looper.getMainLooper()).postDelayed({ tone.release() }, 700)
        } catch (_: RuntimeException) {
            // No audio output available: stay silent.
        }
    }

    private fun keepScreenOn(on: Boolean) {
        if (on) {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }
}
