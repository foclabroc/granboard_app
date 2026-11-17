package com.example.granboard_proto

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.videoplayer.FocVideoMode
import kotlin.math.abs

class MainActivity : FlutterActivity() {
    private val isTv: Boolean
        get() = packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)

    /** Mode d'affichage demandé au démarrage (1080p sur une TV 4K). */
    private var displayNote = ""

    override fun onCreate(savedInstanceState: Bundle?) {
        if (isTv) displayNote = prefer1080p()
        super.onCreate(savedInstanceState)
    }

    /**
     * Moteur de rendu de l'écran TV : Skia par défaut (bien plus fluide sur
     * la TCL de foclabroc), Impeller si le téléphone le demande (gardé par
     * l'écran). Lu au lancement du moteur, d'où le redémarrage de l'appli
     * quand il change.
     */
    override fun getFlutterEngineFlags(): List<String> {
        val flags = ArrayList(super.getFlutterEngineFlags() ?: emptyList())
        if (isTv && savedEngine() == "skia") flags.add("--enable-impeller=false")
        return flags
    }

    private fun savedEngine(): String =
        if (getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .getString("flutter.tv_render", null) == "impeller"
        ) "impeller" else "skia"

    /**
     * TV 4K : l'appli dessinée en 1920 × 1080 (4 fois moins de pixels), la
     * TV agrandit l'image. Rien à faire si l'écran est déjà en 1080p (cas de
     * la plupart des Android TV, dont l'interface tourne en 1080p).
     */
    private fun prefer1080p(): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return ""
        return try {
            @Suppress("DEPRECATION")
            val display = windowManager.defaultDisplay
            val cur = display.mode
            val big = maxOf(cur.physicalWidth, cur.physicalHeight)
            if (big <= 1920) return ""
            val target = display.supportedModes
                .filter { maxOf(it.physicalWidth, it.physicalHeight) == 1920 }
                .minByOrNull { abs(it.refreshRate - cur.refreshRate) }
                ?: return "4K (pas de mode 1080p)"
            window.attributes = window.attributes.apply {
                preferredDisplayModeId = target.modeId
            }
            "1080p (au lieu de ${cur.physicalWidth}×${cur.physicalHeight})"
        } catch (e: Exception) {
            ""
        }
    }

    /** Relance l'appli (nouveau processus : le moteur de rendu change). */
    private fun restart() {
        val intent = (packageManager.getLeanbackLaunchIntentForPackage(packageName)
            ?: packageManager.getLaunchIntentForPackage(packageName))
            ?: return
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        startActivity(intent)
        finishAffinity()
        Runtime.getRuntime().exit(0)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Détection Android TV : l'appli démarre alors en mode écran TV
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "granboard/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isTv" -> result.success(isTv)
                    // Écran TV : moteur, mode d'affichage, décodeur vidéo
                    "gfxInfo" -> {
                        val m = resources.displayMetrics
                        result.success(
                            mapOf(
                                "engine" to (if (isTv && savedEngine() == "skia") "skia" else "impeller"),
                                "display" to displayNote,
                                "size" to "${m.widthPixels}×${m.heightPixels}",
                            )
                        )
                    }
                    "videoSoftware" -> {
                        FocVideoMode.softwareFirst = call.arguments == true
                        result.success(null)
                    }
                    "restart" -> {
                        result.success(null)
                        window.decorView.postDelayed({ restart() }, 300)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
