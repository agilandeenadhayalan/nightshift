package com.nightshift.app

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.SystemClock
import android.provider.Settings
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions
import com.google.firebase.messaging.FirebaseMessaging
import org.json.JSONObject
import java.security.KeyStore
import java.util.UUID
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Process-wide serialized owner/binding boundary. No Firebase bearer is stored. */
object CallInvitationRuntime {
    const val CHANNEL = "nightshift_audio_invitations_v1"
    const val ACTION = "com.nightshift.app.OPEN_INVITATION"
    private const val STORAGE = "nightshift_call_invitations"
    private const val KEY = "nightshift_call_invitation_binding_v1"
    private val processBoot = UUID.randomUUID().toString()
    private var loaded = false
    private var owner: String? = null
    private var generation = 1L
    private var locale = "en"
    private var binding: CallInvitationPolicy.Binding? = null
    private val seen = LinkedHashMap<String, CallInvitationPolicy.Seen>()
    private var pending: Map<String,String>? = null
    private var rotateToken = true
    private var durableFailure = false
    val tokenGate = InvitationTokenGate()
    var changed: (() -> Unit)? = null

    fun firebase(context: Context): Boolean {
        if (BuildConfig.FIREBASE_PROJECT_ID != "nightshift-c3e1a" ||
            BuildConfig.FIREBASE_WEB_API_KEY.isBlank() || BuildConfig.FIREBASE_ANDROID_APP_ID.isBlank() ||
            BuildConfig.FIREBASE_MESSAGING_SENDER_ID.isBlank()) return false
        return try {
            val existing = FirebaseApp.getApps(context).firstOrNull { it.name == FirebaseApp.DEFAULT_APP_NAME }
            if (existing == null) FirebaseApp.initializeApp(context, FirebaseOptions.Builder()
                .setApiKey(BuildConfig.FIREBASE_WEB_API_KEY).setApplicationId(BuildConfig.FIREBASE_ANDROID_APP_ID)
                .setGcmSenderId(BuildConfig.FIREBASE_MESSAGING_SENDER_ID).setProjectId(BuildConfig.FIREBASE_PROJECT_ID).build())
            else if (existing.options.projectId != BuildConfig.FIREBASE_PROJECT_ID ||
                existing.options.applicationId != BuildConfig.FIREBASE_ANDROID_APP_ID) return false
            true
        } catch (_: Exception) { false }
    }
    private fun boot(context: Context): String = if (Build.VERSION.SDK_INT >= 24) {
        try { "boot:${Settings.Global.getInt(context.contentResolver, Settings.Global.BOOT_COUNT)}" }
        catch (_: Exception) { "process:$processBoot" }
    } else "process:$processBoot"
    private fun secret(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(KEY, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder(KEY, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
        }.generateKey()
    }
    private fun persist(context: Context) {
        val value = JSONObject().put("owner", owner).put("generation",generation).put("locale",locale).put("rotateToken",rotateToken)
        binding?.let { b -> value.put("binding",JSONObject().put("id",b.registrationId).put("bindingId",b.bindingId)
            .put("version",b.version).put("boot",b.boot).put("server",b.serverUpper).put("expiry",b.expiry)
            .put("wall",b.wall).put("elapsed",b.elapsed)) }
        val records=JSONObject()
        seen.forEach { (id,v) -> records.put(id,JSONObject().put("version",v.version).put("expires",v.expires).put("terminal",v.terminal)) }
        value.put("seen",records)
        val cipher=Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.ENCRYPT_MODE,secret()) }
        val ciphertext=cipher.doFinal(value.toString().toByteArray(Charsets.UTF_8))
        val envelope=Base64.encodeToString(cipher.iv+ciphertext,Base64.NO_WRAP)
        check(context.getSharedPreferences(STORAGE,Context.MODE_PRIVATE).edit().putString("state",envelope).commit())
    }
    private fun invalidateDisk(context: Context) {
        try { InvitationInvalidation.invalidate(object:InvitationInvalidation.Storage {
            override fun deleteKey() {
                KeyStore.getInstance("AndroidKeyStore").apply { load(null);deleteEntry(KEY) }
            }
            override fun deleteCiphertext() {
                check(context.getSharedPreferences(STORAGE,Context.MODE_PRIVATE).edit().remove("state").commit())
            }
        }); durableFailure=false }
        catch(failure:Exception) { durableFailure=true;throw failure }
    }
    private fun load(context: Context) {
        if(loaded) return
        loaded=true
        try {
            val encoded=context.getSharedPreferences(STORAGE,Context.MODE_PRIVATE).getString("state",null) ?: return
            require(encoded.length<65536)
            val bytes=Base64.decode(encoded,Base64.NO_WRAP)
            val cipher=Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.DECRYPT_MODE,secret(),GCMParameterSpec(128,bytes.copyOfRange(0,12))) }
            val value=JSONObject(String(cipher.doFinal(bytes.copyOfRange(12,bytes.size)),Charsets.UTF_8))
            owner=value.optString("owner").takeIf { it.matches(Regex("[a-f0-9]{64}")) }
            generation=value.getLong("generation").coerceAtLeast(1)
            locale=if(value.optString("locale")=="ta") "ta" else "en"
            rotateToken=value.optBoolean("rotateToken",true)
            value.optJSONObject("binding")?.let { b -> binding=CallInvitationPolicy.Binding(b.getString("id"),b.getString("bindingId"),b.getLong("version"),b.getString("boot"),b.getLong("server"),b.getLong("expiry"),b.getLong("wall"),b.getLong("elapsed"),0) }
            value.optJSONObject("seen")?.let { entries ->
                require(entries.length()<=64)
                entries.keys().forEach { id -> val v=entries.getJSONObject(id)
                    if(CallInvitationPolicy.uuid(id)) seen[id]=CallInvitationPolicy.Seen(v.getLong("version"),v.getLong("expires"),v.getBoolean("terminal")) }
            }
            if(owner==null || binding?.valid(System.currentTimeMillis(),SystemClock.elapsedRealtime(),boot(context))!=true) {
                binding=null; seen.clear(); cancelAll(context)
                try { invalidateDisk(context) } catch (_:Exception) {}
            }
        } catch (_: Exception) { owner=null;binding=null;seen.clear();cancelAll(context) }
    }
    private fun invalidateBadClock(context:Context) {
        if(binding!=null && binding?.valid(System.currentTimeMillis(),SystemClock.elapsedRealtime(),boot(context))!=true) {
            generation++;binding=null;seen.clear();pending=null;cancelAll(context)
            try { invalidateDisk(context) } catch (_:Exception) {}
        }
    }
    fun channel(context: Context) {
        if(Build.VERSION.SDK_INT>=26) {
            val manager=context.getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(NotificationChannel(CHANNEL,"Audio invitations",NotificationManager.IMPORTANCE_HIGH).apply {
                description="Short-lived invitations; open NightShift to review and answer."
                lockscreenVisibility=android.app.Notification.VISIBILITY_PRIVATE
            })
        }
    }
    fun permitted(context: Context): Boolean = NotificationManagerCompat.from(context).areNotificationsEnabled() &&
        (Build.VERSION.SDK_INT<33 || context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)==PackageManager.PERMISSION_GRANTED) &&
        (Build.VERSION.SDK_INT<26 || context.getSystemService(NotificationManager::class.java).getNotificationChannel(CHANNEL)?.importance != NotificationManager.IMPORTANCE_NONE)
    private fun cancelAll(context: Context) { NotificationManagerCompat.from(context).cancelAll() }
    @Synchronized fun synchronize(context: Context, key: String?, language: String): Map<String,Any?> {
        load(context);channel(context)
        require(key==null || key.matches(Regex("[a-f0-9]{64}")))
        if(owner!=key || durableFailure) {
            generation++;owner=null;binding=null;seen.clear();pending=null;cancelAll(context)
            invalidateDisk(context);owner=key;rotateToken=true
        }
        locale=if(language=="ta") "ta" else "en"
        if(!permitted(context) || binding?.valid(System.currentTimeMillis(),SystemClock.elapsedRealtime(),boot(context))==false) {
            val hadBinding=binding!=null
            binding=null;seen.clear();pending=null;cancelAll(context)
            if(hadBinding) invalidateDisk(context)
        }
        persist(context)
        return configuration(context)
    }
    @Synchronized fun configuration(context: Context): Map<String,Any?> {
        load(context);invalidateBadClock(context)
        return mapOf("available" to (!durableFailure && Build.VERSION.SDK_INT>=26 && firebase(context)), "permission" to permitted(context), "channelEnabled" to permitted(context),
            "generation" to generation,"bindingId" to binding?.bindingId)
    }
    @Synchronized fun current(context:Context, expected:Long): Boolean {
        load(context);return !durableFailure && generation==expected && owner!=null
    }
    @Synchronized fun needsTokenRotation(context:Context):Boolean { load(context);return rotateToken }
    @Synchronized fun tokenRotated(context:Context,expected:Long) {
        check(current(context,expected));rotateToken=false;persist(context)
    }
    @Synchronized fun install(context:Context, expected:Long, data:Map<*,*>) {
        check(Build.VERSION.SDK_INT>=26 && current(context,expected) && permitted(context))
        val next=CallInvitationPolicy.Binding(data["registrationId"] as String,data["bindingId"] as String,
            (data["registrationVersion"] as Number).toLong(),boot(context),
            CallInvitationPolicy.date(data["serverTime"] as String),CallInvitationPolicy.date(data["leaseExpiresAt"] as String),
            System.currentTimeMillis(),SystemClock.elapsedRealtime(),(data["requestElapsedMs"] as Number).toLong())
        check(next.valid(System.currentTimeMillis(),SystemClock.elapsedRealtime(),boot(context)))
        val previous=binding
        if(previous?.bindingId!=next.bindingId || previous.version!=next.version) {
            binding=null;seen.clear();pending=null;cancelAll(context);invalidateDisk(context)
        }
        binding=next
        try { persist(context) } catch (e:Exception) {
            binding=null;seen.clear();pending=null;cancelAll(context)
            try { invalidateDisk(context) } catch (_:Exception) {}
            throw e
        }
    }
    @Synchronized fun clear(context:Context,expected:Long) {
        load(context)
        if(expected!=generation) return
        generation++;binding=null;seen.clear();pending=null;cancelAll(context)
        invalidateDisk(context);persist(context)
        if(firebase(context)) FirebaseMessaging.getInstance().isAutoInitEnabled=false
    }
    @Synchronized fun rotated(context:Context) {
        load(context)
        if(binding!=null) generation++
        binding=null;seen.clear();pending=null;cancelAll(context)
        try { invalidateDisk(context) } catch (_:Exception) { owner=null }
        try { persist(context) } catch (_:Exception) { owner=null }
        changed?.invoke()
    }
    @Synchronized fun receive(context:Context,data:Map<String,String>) {
        if(Build.VERSION.SDK_INT<26) return
        load(context);invalidateBadClock(context);channel(context)
        val result=CallInvitationPolicy.receive(data,binding,seen,System.currentTimeMillis(),SystemClock.elapsedRealtime(),boot(context),permitted(context))
        if(result.action=="ignore") return
        try { persist(context) } catch (_:Exception) {
            binding=null;seen.clear();pending=null;cancelAll(context)
            try { invalidateDisk(context) } catch (_:Exception) {}
            return
        }
        val manager=NotificationManagerCompat.from(context)
        if(result.action=="dismiss") { manager.cancel(result.callId,1); if(pending?.get("callId")==result.callId) pending=null;return }
        val open=Intent(context,MainActivity::class.java).apply {
            action=ACTION;this.data=android.net.Uri.parse("nightshift-invitation:${result.callId}:${data["callVersion"]}")
            flags=Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("invitation",JSONObject(data).toString())
        }
        val intent=PendingIntent.getActivity(context,0,open,PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val title=if(locale=="ta") "ஆடியோ அழைப்பு அழைப்பிதழ்" else "Audio call invitation"
        val copy=if(locale=="ta") "பதிலளிக்க NightShift செயலியைத் திறந்து சரிபார்க்கவும்." else "Open NightShift to review and answer."
        val remaining=CallInvitationPolicy.remaining(data,binding,System.currentTimeMillis(),SystemClock.elapsedRealtime(),boot(context))
        val notification=NotificationCompat.Builder(context,CHANNEL).setSmallIcon(R.drawable.ic_call_invitation)
            .setContentTitle(title).setContentText(copy).setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(NotificationCompat.PRIORITY_HIGH).setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setAutoCancel(true).setTimeoutAfter(remaining.coerceAtLeast(1)).setContentIntent(intent)
            .addAction(0,if(locale=="ta") "திற" else "Open",intent).build()
        try { manager.notify(result.callId,1,notification) } catch (_:SecurityException) {
            binding=null;seen.clear();pending=null;cancelAll(context)
            try { invalidateDisk(context) } catch (_:Exception) {}
        }
    }
    @Synchronized fun opened(context:Context,intent:Intent?) {
        load(context);invalidateBadClock(context)
        if(intent?.action!=ACTION) return
        try {
            val raw=intent.getStringExtra("invitation") ?: return
            require(raw.toByteArray().size<=2048)
            val json=JSONObject(raw);val data=mutableMapOf<String,String>()
            json.keys().forEach { key -> data[key]=json.get(key) as String }
            if(CallInvitationPolicy.addressed(data,binding,System.currentTimeMillis(),SystemClock.elapsedRealtime(),boot(context)) &&
                data["type"]=="call.invitation" && seen[data["callId"]]?.terminal!=true) {
                pending=data;NotificationManagerCompat.from(context).cancel(data["callId"],1);changed?.invoke()
            }
        } catch (_:Exception) {} finally { intent.removeExtra("invitation") }
    }
    @Synchronized fun takeOpen(context:Context,expected:Long): Map<String,Any>? {
        invalidateBadClock(context)
        if(!current(context,expected)) return null
        val result=pending;pending=null
        val valid=result?.takeIf { CallInvitationPolicy.addressed(it,binding,System.currentTimeMillis(),SystemClock.elapsedRealtime(),boot(context)) && seen[it["callId"]]?.terminal!=true } ?: return null
        return valid + mapOf("remainingMilliseconds" to CallInvitationPolicy.remaining(valid,binding,System.currentTimeMillis(),SystemClock.elapsedRealtime(),boot(context)))
    }
}
