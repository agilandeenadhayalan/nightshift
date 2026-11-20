package com.nightshift.app

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle
import android.view.WindowManager

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Keep capture protection in release/profile and ordinary debug builds.
        // Device QA can explicitly opt a debug APK into Vysor mirroring.
        if (BuildConfig.BUILD_TYPE != "debug" || !BuildConfig.ALLOW_DEBUG_SCREEN_CAPTURE) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }
}
