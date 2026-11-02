package net.planext4u.device_access

import android.Manifest
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.provider.ContactsContract
import android.view.WindowManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.util.UUID
import java.util.concurrent.Executors

/** Reads OS permission state only. Never reads location, camera, audio or account data. */
class DeviceAccessPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler,
    PluginRegistry.RequestPermissionsResultListener {
    private var channel: MethodChannel? = null
    private var binding: ActivityPluginBinding? = null
    private var pending: MethodChannel.Result? = null
    private var contactReadPending: MethodChannel.Result? = null
    private val mainThread = Handler(Looper.getMainLooper())
    private val contactReader = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "planext4u-contact-reader").apply { isDaemon = true }
    }
    private val privacyOwners = mutableSetOf<String>()
    private var preexistingSecureWindow = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "net.planext4u.device-access")
        channel!!.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "privacyRelease") {
            val owner = call.argument<String>("owner")
            if (owner == null || !Regex("^[0-9a-f-]{36}$").matches(owner)) {
                result.error("INVALID_OWNER", "Invalid privacy owner.", null); return
            }
            val removed = privacyOwners.remove(owner)
            if (removed && privacyOwners.isEmpty() && !preexistingSecureWindow)
                binding?.activity?.window?.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            result.success(null); return
        }
        val activity = binding?.activity
        if (activity == null) { result.error("UNAVAILABLE", "Device settings are unavailable.", null); return }
        try {
            when (call.method) {
                "privacyAcquire" -> {
                    if (privacyOwners.size >= 16) { result.error("BUSY", "Too many privacy owners.", null); return }
                    if (privacyOwners.isEmpty()) preexistingSecureWindow =
                        activity.window.attributes.flags and WindowManager.LayoutParams.FLAG_SECURE != 0
                    val owner = UUID.randomUUID().toString()
                    privacyOwners.add(owner)
                    activity.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    result.success(owner)
                }
                "read" -> result.success(snapshot(activity))
                "readContactPhones" -> {
                    val maximum = call.argument<Int>("maximum")
                    if (maximum == null || maximum !in 1..10000) {
                        result.error("INVALID_LIMIT", "Invalid contact budget.", null); return
                    }
                    if (contactReadPending != null) {
                        result.error("BUSY", "A contact read is already open.", null); return
                    }
                    if (!declared(activity, Manifest.permission.READ_CONTACTS) ||
                        !granted(activity, Manifest.permission.READ_CONTACTS)) {
                        result.error("CONTACTS_DENIED", "Contacts access is unavailable.", null); return
                    }
                    contactReadPending = result
                    val context = activity.applicationContext
                    contactReader.execute {
                        val response = try {
                            val phones = linkedSetOf<String>()
                            var skipped = 0
                            var scanned = 0
                            // A malformed/huge provider cannot hold a platform
                            // thread indefinitely or cause an unbounded result.
                            val scanBudget = maxOf(1000, maximum * 5)
                            val cursor = context.contentResolver.query(
                                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                                arrayOf(ContactsContract.CommonDataKinds.Phone.NORMALIZED_NUMBER),
                                null, null, null
                            ) ?: throw IllegalStateException("Contacts query unavailable")
                            cursor.use {
                                while (it.moveToNext()) {
                                    scanned++
                                    if (scanned > scanBudget) break
                                    val phone = it.getString(0)
                                    if (phone != null && E164.matches(phone)) phones.add(phone)
                                    else skipped++
                                    if (phones.size > maximum) break
                                }
                            }
                            if (!granted(context, Manifest.permission.READ_CONTACTS))
                                ContactReadResult("CONTACTS_DENIED", null)
                            else if (scanned > scanBudget || phones.size > maximum)
                                ContactReadResult("TOO_MANY_CONTACTS", null)
                            else ContactReadResult(null, mapOf("phones" to phones.toList(), "skipped" to skipped))
                        } catch (_: SecurityException) { ContactReadResult("CONTACTS_DENIED", null) }
                        catch (_: Exception) { ContactReadResult("UNAVAILABLE", null) }
                        mainThread.post {
                            if (contactReadPending === result) {
                                contactReadPending = null
                                if (response.error != null) result.error(response.error, "Contacts could not be read.", null)
                                else result.success(response.value)
                            }
                        }
                    }
                }
                "request" -> {
                    if (pending != null) { result.error("BUSY", "A permission request is open.", null); return }
                    val kind = call.argument<String>("kind")
                    val permissions = permissions(kind)
                    if (permissions == null) { result.error("INVALID_PERMISSION", "Unknown permission.", null); return }
                    if (permissions.isEmpty() || permissions.all { granted(activity, it) } ||
                        !permissions.all { declared(activity, it) }) {
                        result.success(snapshot(activity)); return
                    }
                    pending = result
                    activity.requestPermissions(permissions, REQUEST)
                }
                "openSettings" -> {
                    val target = call.argument<String>("target")
                    val intent = when (target) {
                        "application" -> Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.fromParts("package", activity.packageName, null))
                        "location" -> Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
                        "notifications" -> if (Build.VERSION.SDK_INT >= 26)
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName)
                            else Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", activity.packageName, null))
                        else -> { result.error("INVALID_SETTINGS", "Unknown settings destination.", null); return }
                    }
                    activity.startActivity(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        } catch (_: Exception) {
            if (pending === result) pending = null
            if (contactReadPending === result) contactReadPending = null
            result.error("UNAVAILABLE", "Device settings could not be accessed.", null)
        }
    }

    private fun permissions(kind: String?): Array<String>? = when (kind) {
        "location" -> arrayOf(Manifest.permission.ACCESS_COARSE_LOCATION, Manifest.permission.ACCESS_FINE_LOCATION)
        "camera" -> arrayOf(Manifest.permission.CAMERA)
        "microphone" -> arrayOf(Manifest.permission.RECORD_AUDIO)
        "contacts" -> arrayOf(Manifest.permission.READ_CONTACTS)
        "notifications" -> if (Build.VERSION.SDK_INT >= 33) arrayOf(Manifest.permission.POST_NOTIFICATIONS) else emptyArray()
        else -> null
    }

    private fun granted(context: Context, permission: String): Boolean =
        context.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    @Suppress("DEPRECATION")
    private fun declared(context: Context, permission: String): Boolean =
        context.packageManager.getPackageInfo(context.packageName, PackageManager.GET_PERMISSIONS)
            .requestedPermissions?.contains(permission) == true

    private fun snapshot(context: Context): Map<String, Any> {
        val precise = granted(context, Manifest.permission.ACCESS_FINE_LOCATION)
        val coarse = granted(context, Manifest.permission.ACCESS_COARSE_LOCATION)
        val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val locationEnabled = if (Build.VERSION.SDK_INT >= 28) locationManager.isLocationEnabled else
            locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER) || locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val notifications = if (Build.VERSION.SDK_INT >= 24) manager.areNotificationsEnabled() else true
        fun state(kind: String): String {
            val required = permissions(kind)!!
            if (!required.all { declared(context, it) }) return "unavailable"
            if (kind == "notifications") return if (Build.VERSION.SDK_INT < 24) "unavailable" else if (notifications && required.all { granted(context, it) }) "allowed" else "notAllowed"
            if (kind == "location") return if (precise) "precise" else if (coarse) "approximate" else "notAllowed"
            return if (required.all { granted(context, it) }) "allowed" else "notAllowed"
        }
        return mapOf("location" to state("location"), "locationServiceEnabled" to locationEnabled,
            "camera" to state("camera"), "microphone" to state("microphone"), "notifications" to state("notifications"),
            "contacts" to state("contacts"))
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray): Boolean {
        if (requestCode != REQUEST) return false
        val result = pending ?: return true
        // Always re-read the OS. Missing/empty/cancelled grant results never imply permission.
        pending = null
        val context = binding?.activity
        if (context == null) result.error("UNAVAILABLE", "The activity is unavailable.", null)
        else try { result.success(snapshot(context)) }
        catch (_: Exception) { result.error("UNAVAILABLE", "Permissions could not be refreshed.", null) }
        return true
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        this.binding = binding
        binding.addRequestPermissionsResultListener(this)
        preexistingSecureWindow = binding.activity.window.attributes.flags and WindowManager.LayoutParams.FLAG_SECURE != 0
        if (privacyOwners.isNotEmpty()) binding.activity.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }
    private fun detach(cancel: Boolean) {
        binding?.removeRequestPermissionsResultListener(this)
        binding = null
        if (cancel) {
            pending?.error("INTERRUPTED", "Permission request interrupted. Refresh to check current access.", null)
            pending = null
            contactReadPending?.error("INTERRUPTED", "Contact read interrupted. Try again.", null)
            contactReadPending = null
        }
    }
    override fun onDetachedFromActivityForConfigChanges() = detach(false)
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)
    override fun onDetachedFromActivity() = detach(true)
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        if (privacyOwners.isNotEmpty() && !preexistingSecureWindow)
            this.binding?.activity?.window?.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        privacyOwners.clear()
        detach(true); channel?.setMethodCallHandler(null); channel = null
        contactReader.shutdownNow()
    }
    private data class ContactReadResult(val error: String?, val value: Map<String, Any>?)
    companion object { private const val REQUEST = 0x5045; private val E164 = Regex("^\\+[1-9][0-9]{7,14}$") }
}
