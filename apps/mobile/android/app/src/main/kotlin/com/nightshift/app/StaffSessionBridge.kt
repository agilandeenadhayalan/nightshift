package com.nightshift.app

import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.ViewGroup
import android.webkit.CookieManager
import android.webkit.WebSettings
import android.webkit.WebView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.webviewflutter.WebViewFlutterAndroidExternalApi
import java.lang.ref.WeakReference

/** A fixed-purpose native bridge. It never exposes cookie reads, URLs, script
 * evaluation, arbitrary headers or browser-navigation commands to Dart. */
class StaffSessionBridge(private val context: Context, private val engine: FlutterEngine) {
    companion object {
        private val shared by lazy { State() }
    }
    private class State {
        val handler = Handler(Looper.getMainLooper())
        val origin = try { StaffCookiePolicy.origin(BuildConfig.STAFF_CONSOLE_ORIGIN, BuildConfig.DEBUG) } catch (_: Exception) { "" }
        var owner: Any? = null
        var view: WeakReference<WebView>? = null
        val cookies = StaffCookieCoordinator(
            { System.currentTimeMillis() },
            { delay, action -> handler.postDelayed(action, delay); StaffCookieCoordinator.Cancellation { handler.removeCallbacks(action) } },
            { cookie, done ->
                check(origin.isNotEmpty())
                CookieManager.getInstance().setCookie(origin, cookie) { accepted -> done.complete(accepted) }
            },
            { discardView() },
        )
        fun nextGeneration() = if (cookies.generation() < StaffCookiePolicy.MAX_GENERATION) cookies.generation() + 1 else cookies.generation()
        fun discardView() {
            val old = view?.get(); view = null
            if (old != null) {
                // Hide before stopping JS/network work; a late callback must not
                // put another account's authenticated document back on screen.
                old.visibility = View.INVISIBLE
                try { old.stopLoading() } catch (_: Exception) {}
                try { old.settings.javaScriptEnabled = false } catch (_: Exception) {}
                try { old.settings.blockNetworkLoads = true } catch (_: Exception) {}
                try { old.loadUrl("about:blank") } catch (_: Exception) {}
                try { old.clearHistory() } catch (_: Exception) {}
                try { old.clearCache(true) } catch (_: Exception) {}
                try { old.clearFormData() } catch (_: Exception) {}
                // Pigeon may already have queued a loadRequest. Destroy the old
                // platform view after detaching it so that request cannot later
                // use a newer account's process-wide CookieManager cookie.
                try { (old.parent as? ViewGroup)?.removeView(old) } catch (_: Exception) {}
                try { old.removeAllViews(); old.destroy() } catch (_: Exception) {}
            }
        }
    }
    private val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "nightshift/staff_session")
    private var closed = false
    init {
        check(Looper.myLooper() == Looper.getMainLooper())
        if (shared.owner != null && shared.origin.isNotEmpty()) shared.cookies.clear(shared.nextGeneration(), null)
        shared.owner = this
        channel.setMethodCallHandler(::handle)
    }
    private fun completion(result: MethodChannel.Result) = StaffCookieCoordinator.Completion { code ->
        if (code == null) result.success(null) else result.error(code, "Staff access could not be completed.", null)
    }
    private fun arguments(call: MethodCall, names: Set<String>): Map<*, *> {
        val value = call.arguments as? Map<*, *> ?: throw IllegalArgumentException()
        require(value.keys == names)
        return value
    }
    private fun integer(value: Any?): Long = when (value) {
        is Long -> value
        is Int -> value.toLong()
        else -> throw IllegalArgumentException()
    }
    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (closed || shared.owner !== this) { result.error("STAFF_STALE", "Staff access has changed.", null); return }
        try {
            when (call.method) {
                "configuration" -> {
                    require(call.arguments == null)
                    val value = mutableMapOf<String, Any>("origin" to shared.origin, "generation" to shared.cookies.generation())
                    if (BuildConfig.DEBUG && shared.origin.isNotEmpty()) {
                        val id = context.resources.getIdentifier("nightshift_staff_dev_ca", "raw", context.packageName)
                        if (id != 0) {
                            val bytes = context.resources.openRawResource(id).use { input ->
                                val output = java.io.ByteArrayOutputStream()
                                val buffer = ByteArray(2048)
                                while (true) {
                                    val count = input.read(buffer)
                                    if (count < 0) break
                                    require(output.size() + count <= 16384)
                                    output.write(buffer, 0, count)
                                }
                                output.toByteArray()
                            }
                            require(bytes.isNotEmpty())
                            value["debugTrustBytes"] = bytes
                        }
                    }
                    result.success(value)
                }
                "install" -> {
                    if (shared.origin.isEmpty()) { result.error("STAFF_UNAVAILABLE", "Staff access is not configured.", null); return }
                    val args = arguments(call, setOf("token", "expiresAt", "generation"))
                    val token = args["token"] as? String ?: throw IllegalArgumentException()
                    val expiresAt = args["expiresAt"] as? String ?: throw IllegalArgumentException()
                    shared.cookies.install(integer(args["generation"]), token, expiresAt, completion(result))
                }
                "clear" -> {
                    val args = arguments(call, setOf("generation"))
                    val generation = integer(args["generation"])
                    if (shared.origin.isEmpty()) { result.success(null); return }
                    shared.cookies.clear(generation, completion(result))
                }
                "harden" -> {
                    val args = arguments(call, setOf("webViewId", "generation"))
                    val generation = integer(args["generation"])
                    if (!shared.cookies.canUse(generation)) { result.error("STAFF_STALE", "Staff access has changed.", null); return }
                    val id = integer(args["webViewId"]); require(id >= 0)
                    val view = WebViewFlutterAndroidExternalApi.getWebView(engine, id) ?: throw IllegalArgumentException()
                    require(shared.view?.get() == null || shared.view?.get() === view)
                    require(view.url == null || view.url == "about:blank" || shared.view?.get() === view)
                    harden(view)
                    shared.view = WeakReference(view)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (_: Exception) {
            result.error("STAFF_INVALID_SESSION", "Staff access could not be completed.", null)
        }
    }
    @Suppress("DEPRECATION")
    private fun harden(view: WebView) {
        WebView.setWebContentsDebuggingEnabled(false)
        CookieManager.getInstance().setAcceptThirdPartyCookies(view, false)
        with(view.settings) {
            javaScriptCanOpenWindowsAutomatically = false
            setSupportMultipleWindows(false)
            domStorageEnabled = false
            databaseEnabled = false
            saveFormData = false
            cacheMode = WebSettings.LOAD_NO_CACHE
            allowFileAccess = false
            allowContentAccess = false
            allowFileAccessFromFileURLs = false
            allowUniversalAccessFromFileURLs = false
            mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
            setGeolocationEnabled(false)
            mediaPlaybackRequiresUserGesture = true
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) safeBrowsingEnabled = true
        }
        view.setDownloadListener(null)
    }
    fun close() {
        if (closed) return
        closed = true
        channel.setMethodCallHandler(null)
        if (shared.owner === this) {
            if (shared.origin.isNotEmpty()) shared.cookies.clear(shared.nextGeneration(), null)
            else shared.discardView()
            shared.owner = null
        }
    }
}
