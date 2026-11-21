package com.nightshift.app

import android.Manifest
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.lifecycle.Lifecycle
import com.google.firebase.messaging.FirebaseMessaging
import com.google.android.gms.tasks.Tasks
import com.google.android.gms.tasks.Task
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class CallInvitationBridge(private val activity:MainActivity,engine:FlutterEngine) {
    companion object { const val PERMISSION_CODE=0x3901 }
    private val channel=MethodChannel(engine.dartExecutor.binaryMessenger,"nightshift/call_invitations")
    private val handler=Handler(Looper.getMainLooper())
    private var closed=false
    private var permission:Pair<Long,MethodChannel.Result>?=null
    init {
        CallInvitationRuntime.changed={ handler.post { if(!closed) channel.invokeMethod("changed",null) } }
        channel.setMethodCallHandler { call,result ->
            try {
                if(closed) throw IllegalStateException()
                val data=call.arguments as? Map<*,*> ?: throw IllegalArgumentException()
                when(call.method) {
                    "synchronize" -> result.success(CallInvitationRuntime.synchronize(activity,data["ownerKey"] as String?,data["locale"] as String))
                    "requestPermission" -> {
                        val generation=(data["generation"] as Number).toLong()
                        check(CallInvitationRuntime.current(activity,generation) && visible())
                        if(permission!=null) { result.error("PUSH_BUSY","Notification setup is busy.",null) }
                        else if(Build.VERSION.SDK_INT>=33 && !CallInvitationRuntime.permitted(activity)) {
                            permission=Pair(generation,result)
                            activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS),PERMISSION_CODE)
                        } else result.success(CallInvitationRuntime.configuration(activity))
                    }
                    "token" -> {
                        val generation=(data["generation"] as Number).toLong()
                        check(CallInvitationRuntime.current(activity,generation) && visible() && CallInvitationRuntime.permitted(activity))
                        if(!CallInvitationRuntime.firebase(activity)) result.error("PUSH_UNAVAILABLE","Notifications are unavailable.",null)
                        else if(!CallInvitationRuntime.tokenGate.enter()) result.error("PUSH_BUSY","Notification setup is busy.",null)
                        else {
                            var returned=false
                            val deadline=Runnable { if(!returned) { returned=true;result.error("PUSH_TIMEOUT","Notification setup timed out.",null) } }
                            handler.postDelayed(deadline,10000)
                            var providerTask:Task<*>?=null
                            try {
                                val messaging=FirebaseMessaging.getInstance()
                                val operation=if(CallInvitationRuntime.needsTokenRotation(activity)) {
                                    messaging.isAutoInitEnabled=false
                                    val deletion=messaging.deleteToken()
                                    providerTask=deletion
                                    deletion.continueWithTask { completed ->
                                        if(!completed.isSuccessful || !CallInvitationRuntime.current(activity,generation))
                                            Tasks.forException<String>(IllegalStateException("Notification setup changed"))
                                        else {
                                            CallInvitationRuntime.tokenRotated(activity,generation)
                                            messaging.isAutoInitEnabled=true
                                            messaging.token
                                        }
                                    }
                                } else { messaging.isAutoInitEnabled=true;messaging.token }
                                providerTask=operation
                                operation.addOnCompleteListener { task ->
                                    CallInvitationRuntime.tokenGate.settled();handler.removeCallbacks(deadline)
                                    if(!returned) {
                                        returned=true
                                        if(!closed && CallInvitationRuntime.current(activity,generation) && CallInvitationRuntime.permitted(activity) && task.isSuccessful)
                                            result.success(task.result)
                                        else result.error("PUSH_UNAVAILABLE","Notification setup is unavailable.",null)
                                    }
                                }
                            } catch (_:Exception) {
                                handler.removeCallbacks(deadline)
                                if(providerTask==null) CallInvitationRuntime.tokenGate.settled()
                                else {
                                    // A sync wrapper failure cannot release an already
                                    // running SDK operation. Keep its ownership barrier.
                                    try { providerTask.addOnCompleteListener { CallInvitationRuntime.tokenGate.settled() } }
                                    catch (_:Exception) { /* fail closed until process exit */ }
                                }
                                if(!returned) { returned=true;result.error("PUSH_UNAVAILABLE","Notification setup is unavailable.",null) }
                            }
                        }
                    }
                    "install" -> { CallInvitationRuntime.install(activity,(data["generation"] as Number).toLong(),data);result.success(null) }
                    "clear" -> { CallInvitationRuntime.clear(activity,(data["generation"] as Number).toLong());result.success(null) }
                    "takeOpen" -> result.success(CallInvitationRuntime.takeOpen(activity,(data["generation"] as Number).toLong()))
                    else -> result.notImplemented()
                }
            } catch (_:Exception) { result.error("PUSH_UNAVAILABLE","Notification setup is unavailable.",null) }
        }
    }
    private fun visible()=activity.lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED) && !activity.isFinishing && !activity.isDestroyed
    fun permissionResult():Boolean {
        val pending=permission ?: return false
        permission=null
        if(!closed && CallInvitationRuntime.current(activity,pending.first)) pending.second.success(CallInvitationRuntime.configuration(activity))
        else pending.second.error("PUSH_UNAVAILABLE","Notification setup changed.",null)
        return true
    }
    fun close() {
        closed=true;channel.setMethodCallHandler(null);CallInvitationRuntime.changed=null
        permission?.second?.error("PUSH_UNAVAILABLE","Notification setup changed.",null);permission=null
    }
}
