package com.nightshift.app

import android.app.Application
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class NightShiftApplication: Application() {
    override fun onCreate() {
        super.onCreate()
        CallInvitationRuntime.firebase(this)
    }
}

class NightShiftMessagingService: FirebaseMessagingService() {
    override fun onMessageReceived(message: RemoteMessage) {
        CallInvitationRuntime.receive(this,message.data)
    }
    override fun onNewToken(token: String) {
        // Never persist/log the token here or silently re-register another owner.
        CallInvitationRuntime.rotated(this)
    }
}
