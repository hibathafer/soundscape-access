package com.hibathafer.soundscape_access

import android.content.Intent
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var probe: MicProbe? = null
    private var levelSink: EventChannel.EventSink? = null
    private var backgroundSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        EventChannel(messenger, "soundscape/mic_levels").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    levelSink = events
                }

                override fun onCancel(arguments: Any?) {
                    levelSink = null
                }
            }
        )

        MethodChannel(messenger, "soundscape/mic_probe").setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val p = probe ?: MicProbe(applicationContext) { levels ->
                        // onLevels already arrives on the main thread.
                        levelSink?.success(levels)
                    }.also { probe = it }
                    result.success(p.start())
                }

                "stop" -> {
                    probe?.stop()
                    result.success(null)
                }

                "start_stereo" -> {
                    val p = probe ?: MicProbe(applicationContext) { levels ->
                        levelSink?.success(levels)
                    }.also { probe = it }
                    result.success(p.startStereo())
                }

                else -> result.notImplemented()
            }
        }

        // Slice 5 — service life-cycle. The sink lets service death reach Dart
        // while the app is still alive, so the fallback note is not delayed
        // until the next time the user comes back.
        EventChannel(messenger, "soundscape/background_state").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    backgroundSink = events
                    MicForegroundService.listener = { running ->
                        backgroundSink?.success(running)
                    }
                }

                override fun onCancel(arguments: Any?) {
                    backgroundSink = null
                    MicForegroundService.listener = null
                }
            }
        )

        MethodChannel(messenger, "soundscape/background").setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> result.success(startBackgroundSession())

                "stop" -> {
                    val intent = Intent(this, MicForegroundService::class.java).apply {
                        action = MicForegroundService.ACTION_STOP
                    }
                    // startService → onStartCommand sees ACTION_STOP → stops
                    // itself. If nothing is running this is a harmless no-op.
                    startService(intent)
                    result.success(true)
                }

                "isRunning" -> result.success(MicForegroundService.isRunning)

                else -> result.notImplemented()
            }
        }
    }

    /**
     * Starts the microphone-typed foreground service. Returns false rather
     * than throwing: Android 14 refuses a microphone-typed start from the
     * background, and MIUI may refuse outright. Dart treats false as "session
     * runs in front" — the fallback the PRD already approved.
     */
    private fun startBackgroundSession(): Boolean = try {
        val intent = Intent(this, MicForegroundService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
        true
    } catch (e: Exception) {
        Log.w("MainActivity", "background session refused: ${e.message}")
        false
    }

    override fun onDestroy() {
        probe?.stop()
        MicForegroundService.listener = null
        super.onDestroy()
    }
}
