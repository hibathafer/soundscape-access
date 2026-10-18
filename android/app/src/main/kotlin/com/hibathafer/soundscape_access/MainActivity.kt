package com.hibathafer.soundscape_access

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var probe: MicProbe? = null
    private var levelSink: EventChannel.EventSink? = null

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

                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        probe?.stop()
        super.onDestroy()
    }
}
