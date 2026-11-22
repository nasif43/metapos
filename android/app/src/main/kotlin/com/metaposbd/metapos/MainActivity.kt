package com.metaposbd.metapos

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun getInitialRoute(): String? {
        val customRoute = intent.getStringExtra("route")
        if (customRoute != null && customRoute.isNotEmpty()) {
            return customRoute
        }
        return super.getInitialRoute()
    }
}
