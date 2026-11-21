package com.nightshift.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.Activity
import android.content.Intent
import android.content.res.AssetFileDescriptor
import android.net.Uri
import android.os.Bundle
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import android.view.WindowManager
import java.io.InputStream
import java.util.concurrent.Semaphore
import java.util.concurrent.atomic.AtomicInteger

class MainActivity: FlutterActivity() {
    companion object {
        // A misbehaving provider may ignore close/cancellation. Keep a process-wide
        // bound even across activity recreation, and never queue further reads.
        private val reviewReaders = Semaphore(2)
        private val reviewCleanupWorkers = Semaphore(2)
        private val reviewRequestCode = AtomicInteger(0x4000)
    }
    private val reviewHandler = Handler(Looper.getMainLooper())
    private var reviewChannel: MethodChannel? = null
    private var staffSessionBridge: StaffSessionBridge? = null
    private var callInvitationBridge: CallInvitationBridge? = null
    private var reviewSelection: ReviewSelection? = null
    private val allocatedReviewCodes = mutableSetOf<Int>()

    private class ReviewSelection(val result: MethodChannel.Result, val requestCode: Int) {
        val signal = CancellationSignal()
        @Volatile var cancelled = false
        var uri: Uri? = null
        var worker: Thread? = null
        var timeout: Runnable? = null
        private var descriptor: AssetFileDescriptor? = null
        private var stream: InputStream? = null
        @Synchronized fun attach(value: AssetFileDescriptor): Boolean {
            if (cancelled) return false
            descriptor = value
            return true
        }
        @Synchronized fun attach(value: InputStream): Boolean {
            if (cancelled) return false
            stream = value
            return true
        }
        fun closeResources() {
            val resources = synchronized(this) {
                val saved = Pair(stream, descriptor)
                stream = null
                descriptor = null
                saved
            }
            try { resources.first?.close() } catch (_: Exception) {}
            try { resources.second?.close() } catch (_: Exception) {}
        }
        fun cancel() {
            cancelled = true
            worker?.interrupt()
            // Provider cleanup must not hold the UI deadline or the next picker.
            // Never accumulate cleanup threads if a provider blocks its close.
            // When exhausted, the reader's bounded slot/finally remains responsible.
            if (reviewCleanupWorkers.tryAcquire()) {
                try { Thread({
                    try {
                        closeResources()
                        try { signal.cancel() } catch (_: Exception) {}
                    } finally { reviewCleanupWorkers.release() }
                }, "private-review-cancel").also { it.isDaemon = true; it.start() } }
                catch (_: Exception) { reviewCleanupWorkers.release() }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        staffSessionBridge?.close()
        staffSessionBridge = StaffSessionBridge(this, flutterEngine)
        callInvitationBridge?.close()
        callInvitationBridge = CallInvitationBridge(this, flutterEngine)
        reviewChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nightshift/private_review_sample").also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "chooseWav" -> if (call.arguments == null) chooseReviewSample(result)
                        else result.error("SAMPLE_SELECTION_FAILED", "Unable to select the sample.", null)
                    "cancel" -> { cancelReviewSelection(); result.success(null) }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun chooseReviewSample(result: MethodChannel.Result) {
        if (reviewSelection != null || reviewReaders.availablePermits() == 0) {
            result.error("PRIVATE_SAMPLE_BUSY", "A selection is already open.", null)
            return
        }
        if (isFinishing || isDestroyed || reviewRequestCode.get() >= 0x7fff) {
            result.error("SAMPLE_SELECTION_FAILED", "Unable to select the sample.", null)
            return
        }
        val selection = ReviewSelection(result, reviewRequestCode.getAndIncrement())
        allocatedReviewCodes.add(selection.requestCode)
        reviewSelection = selection
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "audio/*"
            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("audio/wav", "audio/x-wav", "audio/wave", "audio/vnd.wave"))
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        try { startActivityForResult(intent, selection.requestCode) }
        catch (_: Exception) {
            allocatedReviewCodes.remove(selection.requestCode)
            finishReviewSelection(selection, error = "SAMPLE_SELECTION_FAILED")
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (!allocatedReviewCodes.remove(requestCode)) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val selection = reviewSelection
        if (selection == null || selection.requestCode != requestCode) {
            releaseReturnedReviewGrants(data, selection?.uri)
            return
        }
        if (resultCode != Activity.RESULT_OK) {
            releaseReturnedReviewGrants(data)
            finishReviewSelection(selection)
            return
        }
        val uri = data?.data
        if (uri == null || uri.scheme != "content") {
            releaseReturnedReviewGrants(data)
            finishReviewSelection(selection, error = "SAMPLE_SELECTION_FAILED")
            return
        }
        releaseReturnedReviewGrants(data, uri)
        selection.uri = uri
        if (!reviewReaders.tryAcquire()) {
            finishReviewSelection(selection, error = "PRIVATE_SAMPLE_BUSY")
            return
        }
        selection.timeout = Runnable {
            selection.cancel()
            finishReviewSelection(selection, error = "SAMPLE_SELECTION_FAILED")
        }.also { reviewHandler.postDelayed(it, 20000) }
        // A cancelled provider cannot keep a later pick queued behind its read.
        try { selection.worker = Thread({
            var bytes: ByteArray? = null
            var failure: String? = null
            try {
                if (!selection.cancelled) {
                    val descriptor = contentResolver.openAssetFileDescriptor(uri, "r", selection.signal)
                        ?: throw IllegalStateException()
                    if (!selection.attach(descriptor)) descriptor.close()
                    else {
                        val input = descriptor.createInputStream()
                        if (!selection.attach(input)) input.close()
                        else bytes = BoundedReviewSampleReader.readAndClose(input) { selection.cancelled }
                    }
                }
            } catch (_: BoundedReviewSampleReader.TooLargeException) { failure = "UPLOAD_LIMIT" }
            catch (_: Exception) { failure = "SAMPLE_SELECTION_FAILED" }
            finally { selection.closeResources(); reviewReaders.release() }
            val completedBytes = bytes
            val completedFailure = failure
            reviewHandler.post {
                if (!selection.cancelled) finishReviewSelection(selection, completedBytes, completedFailure)
            }
        }, "private-review-reader").also { it.isDaemon = true; it.start() } }
        catch (_: Exception) {
            reviewReaders.release()
            finishReviewSelection(selection, error = "SAMPLE_SELECTION_FAILED")
        }
    }

    private fun releaseReturnedReviewGrants(data: Intent?, keep: Uri? = null) {
        val uris = mutableSetOf<Uri>()
        data?.data?.let { uris.add(it) }
        data?.clipData?.let { clip ->
            for (index in 0 until clip.itemCount) clip.getItemAt(index).uri?.let { uris.add(it) }
        }
        uris.filter { it != keep }.forEach { releaseReviewGrant(it) }
    }

    private fun releaseReviewGrant(uri: Uri?) {
        if (uri == null) return
        try { revokeUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION) } catch (_: Exception) {}
    }

    private fun finishReviewSelection(selection: ReviewSelection, bytes: ByteArray? = null, error: String? = null) {
        if (reviewSelection !== selection) return
        reviewSelection = null
        selection.timeout?.let { reviewHandler.removeCallbacks(it) }
        releaseReviewGrant(selection.uri)
        selection.uri = null
        if (error == null) selection.result.success(bytes)
        else selection.result.error(error, "Unable to select the private sample.", null)
    }

    private fun cancelReviewSelection() {
        val selection = reviewSelection ?: return
        selection.cancel()
        try { finishActivity(selection.requestCode) } catch (_: Exception) {}
        finishReviewSelection(selection)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        callInvitationBridge?.close()
        callInvitationBridge = null
        staffSessionBridge?.close()
        staffSessionBridge = null
        cancelReviewSelection()
        reviewChannel?.setMethodCallHandler(null)
        reviewChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onDestroy() {
        callInvitationBridge?.close()
        callInvitationBridge = null
        staffSessionBridge?.close()
        staffSessionBridge = null
        cancelReviewSelection()
        super.onDestroy()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        CallInvitationRuntime.opened(this, intent)
        // Keep capture protection in release/profile and ordinary debug builds.
        // Device QA can explicitly opt a debug APK into Vysor mirroring.
        if (BuildConfig.BUILD_TYPE != "debug" || !BuildConfig.ALLOW_DEBUG_SCREEN_CAPTURE) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        CallInvitationRuntime.opened(this, intent)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        if (requestCode == CallInvitationBridge.PERMISSION_CODE && callInvitationBridge?.permissionResult() == true) return
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }
}
