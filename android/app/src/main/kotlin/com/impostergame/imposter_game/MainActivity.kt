package com.impostergame.imposter_game

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Explicit registration as safety net — prevents MissingPluginException
        // race condition on some physical Android devices.
        GeneratedPluginRegistrant.registerWith(flutterEngine)
    }
}
