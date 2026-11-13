package com.erfan.ennvoapp

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * The native shell of the Ennvo Android app.
 *
 * It owns two things the Dart side cannot do on its own:
 *
 *  1. **Device tier detection.** The web app decides whether to run in
 *     "lite mode" from `navigator.deviceMemory` and
 *     `navigator.hardwareConcurrency`. Android does not expose either to
 *     Dart, so the memory class and the core count are read here and handed
 *     over through the `ennvo/device` channel.
 *
 *  2. **Edge to edge drawing.** The content draws behind the system bars
 *     and the notch insets are published to Flutter through
 *     `MediaQuery.padding`, which mirrors the Capacitor shell's
 *     `--safe-area-inset-*` variables.
 */
class MainActivity : FlutterActivity() {

    private var channel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Draw behind the status and navigation bars.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.setDecorFitsSystemWindows(false)
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility =
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                    View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
        }

        // The reels feed is a video surface: keeping the screen on stops
        // the display from dimming mid-video.
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ennvo/device"
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "deviceInfo" -> result.success(deviceInfo())
                    "requestSustainedPerformance" -> {
                        requestSustainedPerformance()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        channel?.setMethodCallHandler(null)
        channel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    /**
     * The RAM and core count of this device.
     *
     * [totalMem] is the real physical memory, and [lowMemory] mirrors the
     * `ActivityManager.isLowRamDevice` flag that Android sets for devices in
     * the low-RAM configuration.
     */
    private fun deviceInfo(): Map<String, Any> {
        val activityManager =
            getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val memoryInfo = ActivityManager.MemoryInfo()
        activityManager.getMemoryInfo(memoryInfo)

        val cores = Runtime.getRuntime().availableProcessors()

        return mapOf(
            "ramBytes" to memoryInfo.totalMem,
            "availableBytes" to memoryInfo.availMem,
            "lowMemory" to memoryInfo.lowMemory,
            "isLowRam" to activityManager.isLowRamDevice,
            "cores" to cores,
            "sdkInt" to Build.VERSION.SDK_INT
        )
    }

    /**
     * Asks the OS to keep the CPU at full clocks for the lifetime of the
     * app. Useful for a scrolling video feed, which otherwise gets throttled
     * as the device heats up.
     */
    private fun requestSustainedPerformance() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return
        val powerManager =
            getSystemService(Context.POWER_SERVICE) as PowerManager
        powerManager.setSustainedPerformanceMode(true)
    }
}
