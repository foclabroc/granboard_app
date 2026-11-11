package com.example.granboard_proto

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Détection Android TV : l'appli démarre alors en mode écran TV
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "granboard/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isTv" -> result.success(
                        packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)
                    )
                    else -> result.notImplemented()
                }
            }
    }
}
