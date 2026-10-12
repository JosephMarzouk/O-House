package com.example.o_house

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

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
}
