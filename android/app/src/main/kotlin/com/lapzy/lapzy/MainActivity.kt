package com.lapzy.lapzy

import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

class MainActivity : FlutterActivity() {

    private val foregroundChannel = "lapzy/foreground_service"
    private lateinit var gpsChannels: LapzyGpsChannels

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        logMapsAuthDiagnostics()
    }

    private fun logMapsAuthDiagnostics() {
        try {
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                PackageManager.GET_SIGNING_CERTIFICATES
            } else {
                @Suppress("DEPRECATION")
                PackageManager.GET_SIGNATURES
            }
            val packageInfo = packageManager.getPackageInfo(packageName, flags)

            @Suppress("DEPRECATION")
            val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageInfo.signingInfo?.apkContentsSigners ?: emptyArray()
            } else {
                packageInfo.signatures ?: emptyArray()
            }

            for (sig in signatures) {
                val md = MessageDigest.getInstance("SHA1")
                md.update(sig.toByteArray())
                val sha1 = md.digest().joinToString(":") { "%02X".format(it) }
                Log.w("Lapzy/MapsDebug", "=== MAPS AUTH DIAGNOSTIC ===")
                Log.w("Lapzy/MapsDebug", "Package: $packageName")
                Log.w("Lapzy/MapsDebug", "SHA-1 (must be in GCP Console): $sha1")

                val md256 = MessageDigest.getInstance("SHA-256")
                md256.update(sig.toByteArray())
                val sha256 = md256.digest().joinToString(":") { "%02X".format(it) }
                Log.w("Lapzy/MapsDebug", "SHA-256: $sha256")
            }

            Log.w("Lapzy/MapsDebug", "============================")
        } catch (e: Exception) {
            Log.e("Lapzy/MapsDebug", "Diagnostic failed: ${e.message}")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, foregroundChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        startForegroundService(
                            Intent(this, LapzyLocationService::class.java).apply {
                                action = LapzyLocationService.ACTION_START
                            }
                        )
                        result.success(null)
                    }
                    "stop" -> {
                        startService(
                            Intent(this, LapzyLocationService::class.java).apply {
                                action = LapzyLocationService.ACTION_STOP
                            }
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        gpsChannels = LapzyGpsChannels(this)
        gpsChannels.setup(flutterEngine)
    }
}
