package com.example.o_house

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // The channel every push names (android.notification.channelId in
        // o-house-api's fcm.ts). Made here rather than through a Flutter
        // plugin: one channel needs no dependency. Re-creating it each start is
        // a no-op except that it renames it to the phone's current language.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel("rounds", getString(R.string.rounds_channel), NotificationManager.IMPORTANCE_HIGH),
            )
        }
    }

    // Force update (F-11, lib/app_release.dart): this build's version, and
    // the download link opened in the browser. Two calls, so no plugin.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "o_house/app").setMethodCallHandler { call, result ->
            when (call.method) {
                "build" -> {
                    val info = packageManager.getPackageInfo(packageName, 0)
                    val code = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        info.longVersionCode
                    } else {
                        @Suppress("DEPRECATION")
                        info.versionCode.toLong()
                    }
                    result.success(mapOf("name" to (info.versionName ?: ""), "code" to code))
                }
                "openUrl" -> {
                    try {
                        startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(call.arguments as String)))
                        result.success(null)
                    } catch (e: ActivityNotFoundException) {
                        result.error("NO_BROWSER", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
