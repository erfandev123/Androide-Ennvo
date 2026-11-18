package com.erfan.ennvoapp

import android.app.ActivityManager
import android.app.DownloadManager
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.view.View
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
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
 *     and the notch insets reach Flutter through `MediaQuery.padding`,
 *     which mirrors the Capacitor shell's `--safe-area-inset-*` variables.
 */
class MainActivity : FlutterActivity() {

    private var channel: MethodChannel? = null
    private var mediaChannel: MethodChannel? = null

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

        requestSustainedPerformance()
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

        // Saving a reel to the Downloads folder. DownloadManager keeps the
        // transfer going when the app leaves the foreground, and on Android
        // 10 and newer it writes to Downloads without a permission.
        mediaChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ennvo/media"
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "download" -> download(call, result)
                    else -> result.notImplemented()
                }
            }
        }
    }

    /**
     * Queues a file for DownloadManager.
     *
     * A browser-like user agent is sent with the request, because the R2
     * bucket of the app answers 403 to the default one.
     */
    private fun download(call: MethodCall, result: MethodChannel.Result) {
        val url = call.argument<String>("url")
        if (url.isNullOrBlank()) {
            result.error("no_url", "The file has no address.", null)
            return
        }
        val fileName = call.argument<String>("fileName")
            ?: "ennvo_${System.currentTimeMillis()}.mp4"

        try {
            val request = DownloadManager.Request(Uri.parse(url))
            request.setTitle(fileName)
            request.setDescription("Ennvo")
            request.setMimeType(mimeOf(fileName))
            request.setNotificationVisibility(
                DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED
            )
            request.setDestinationInExternalPublicDir(
                Environment.DIRECTORY_DOWNLOADS,
                fileName
            )
            request.setAllowedOverMetered(true)
            request.setAllowedOverRoaming(true)
            request.addRequestHeader(
                "User-Agent",
                "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 " +
                    "(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36"
            )

            val manager = getSystemService(Context.DOWNLOAD_SERVICE)
                as DownloadManager
            manager.enqueue(request)
            result.success(true)
        } catch (error: Exception) {
            result.error("download_failed", error.message, null)
        }
    }

    private fun mimeOf(fileName: String): String = when {
        fileName.endsWith(".mp4", ignoreCase = true) -> "video/mp4"
        fileName.endsWith(".jpg", ignoreCase = true) ||
            fileName.endsWith(".jpeg", ignoreCase = true) -> "image/jpeg"
        fileName.endsWith(".png", ignoreCase = true) -> "image/png"
        fileName.endsWith(".webp", ignoreCase = true) -> "image/webp"
        else -> "application/octet-stream"
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        channel?.setMethodCallHandler(null)
        channel = null
        mediaChannel?.setMethodCallHandler(null)
        mediaChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    /**
     * The RAM and core count of this device.
     *
     * [totalMem] is the real physical memory, and [isLowRam] mirrors the
     * `ActivityManager.isLowRamDevice` flag that Android sets for the
     * devices in the low-RAM configuration.
     */
    private fun deviceInfo(): Map<String, Any> {
        val activityManager =
            getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val memoryInfo = ActivityManager.MemoryInfo()
        activityManager.getMemoryInfo(memoryInfo)

        val cores = Runtime.getRuntime().availableProcessors()

        // An explicit map type keeps the Kotlin inference from narrowing the
        // value type to the common supertype of the mixed values.
        val info = HashMap<String, Any>()
        info["ramBytes"] = memoryInfo.totalMem
        info["availableBytes"] = memoryInfo.availMem
        info["lowMemory"] = memoryInfo.lowMemory
        info["isLowRam"] = activityManager.isLowRamDevice
        info["cores"] = cores
        info["sdkInt"] = Build.VERSION.SDK_INT
        return info
    }

    /**
     * Asks the OS to keep the CPU at full clocks for the lifetime of the
     * app. Useful for a scrolling video feed, which otherwise gets throttled
     * as the device heats up.
     *
     * The API is hidden in the public SDK, so it is called through
     * reflection and simply skipped when it is not available.
     */
    private fun requestSustainedPerformance() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return
        try {
            val method = window.javaClass.getMethod(
                "setSustainedPerformanceMode",
                Boolean::class.javaPrimitiveType
            )
            method.invoke(window, true)
        } catch (_: Exception) {
            // Not available on this device — the app runs without it.
        }
    }
}
