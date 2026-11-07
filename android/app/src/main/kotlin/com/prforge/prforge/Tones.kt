package com.prforge.prforge

import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Handler
import android.os.Looper

// The beeps of the app, on the media volume so they are audible with
// headphones too. "tick" and "final" make the rest countdown sound like a
// race start: low short beeps, then one long high beep.
object Tones {
    fun play(kind: String?) {
        val (tone, ms) = when (kind) {
            "tick" -> Pair(ToneGenerator.TONE_DTMF_1, 130)
            "final" -> Pair(ToneGenerator.TONE_DTMF_D, 700)
            else -> Pair(ToneGenerator.TONE_PROP_BEEP2, 400)
        }
        try {
            val generator = ToneGenerator(AudioManager.STREAM_MUSIC, 90)
            generator.startTone(tone, ms)
            Handler(Looper.getMainLooper()).postDelayed({ generator.release() }, ms + 300L)
        } catch (_: RuntimeException) {
            // No audio output available: stay silent.
        }
    }
}
