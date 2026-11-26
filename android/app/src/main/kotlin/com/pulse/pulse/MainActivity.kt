package com.pulse.pulse

import android.content.Context
import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.pulse.pulse/multicast_lock"
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "acquire" -> {
                    try {
                        if (multicastLock == null) {
                            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                            multicastLock = wifiManager.createMulticastLock("pulse_mDNS_lock")
                            multicastLock?.setReferenceCounted(true)
                        }
                        multicastLock?.acquire()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("LOCK_ERROR", e.message, null)
                    }
                }
                "release" -> {
                    try {
                        if (multicastLock?.isHeld == true) {
                            multicastLock?.release()
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("LOCK_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
