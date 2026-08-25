package com.abk.abk_player

import android.content.Context
import android.media.AudioManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Direct media-volume control for the Live TV remote (LEFT/RIGHT). Uses the
    // system AudioManager and shows the native volume UI, so it never conflicts
    // with system/media key handling.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "abk/tv").setMethodCallHandler { call, result ->
            when (call.method) {
                "adjustVolume" -> {
                    val dir = call.argument<Int>("dir") ?: 0
                    val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    val action = if (dir > 0) AudioManager.ADJUST_RAISE else AudioManager.ADJUST_LOWER
                    am.adjustStreamVolume(AudioManager.STREAM_MUSIC, action, AudioManager.FLAG_SHOW_UI)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
