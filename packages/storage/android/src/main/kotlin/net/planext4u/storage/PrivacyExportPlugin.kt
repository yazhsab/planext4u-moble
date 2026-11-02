package net.planext4u.storage

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.util.UUID
import java.util.concurrent.Executors

/** Per-engine, ephemeral document access. No URI, JSON or error cause is logged. */
class PrivacyExportPlugin : FlutterPlugin, ActivityAware,
    MethodChannel.MethodCallHandler, PluginRegistry.ActivityResultListener {
    private var binding: ActivityPluginBinding? = null
    private var channel: MethodChannel? = null
    private var picker: MethodChannel.Result? = null
    private var selectedId: String? = null
    private var selectedUri: Uri? = null
    private var writing = false
    private val main = Handler(Looper.getMainLooper())
    private val io = Executors.newSingleThreadExecutor()
    private var attached = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        attached = true
        channel = MethodChannel(binding.binaryMessenger, "net.planext4u.storage/document-export")
        channel!!.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "choose" -> choose(call, result)
            "write" -> write(call, result)
            "discard" -> {
                if (call.argument<String>("destination") == selectedId && !writing) discardSelection()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun choose(call: MethodCall, result: MethodChannel.Result) {
        val activity = binding?.activity
        val name = call.argument<String>("file_name")
        if (activity == null || !attached) { result.error("UNAVAILABLE", "The document picker is unavailable.", null); return }
        if (picker != null || selectedId != null || writing) { result.error("BUSY", "An export is already open.", null); return }
        if (name == null || !Regex("^planext4u-account-\\d{8}T\\d{6}Z\\.json$").matches(name)) {
            result.error("INVALID_EXPORT", "Invalid export name.", null); return
        }
        picker = result
        try {
            activity.startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "application/json"
                putExtra(Intent.EXTRA_TITLE, name)
                putExtra(DocumentsContract.EXTRA_INITIAL_URI,
                    DocumentsContract.buildDocumentUri("com.android.externalstorage.documents", "primary:Download"))
            }, REQUEST)
        } catch (_: Exception) {
            picker = null
            result.error("UNAVAILABLE", "The document picker could not be opened.", null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST) return false
        val pending = picker ?: return true
        picker = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) { pending.success(null); return true }
        if (uri.scheme != "content") { pending.error("INVALID_DESTINATION", "Choose a document provider.", null); return true }
        selectedId = UUID.randomUUID().toString()
        selectedUri = uri
        pending.success(selectedId)
        return true
    }

    private fun write(call: MethodCall, result: MethodChannel.Result) {
        val bytes = call.argument<ByteArray>("bytes")
        val resolver = binding?.activity?.contentResolver
        val uri = selectedUri
        if (writing || uri == null || selectedId == null || call.argument<String>("destination") != selectedId || resolver == null) {
            result.error("INVALID_DESTINATION", "Choose the export destination again.", null); return
        }
        if (bytes == null || bytes.isEmpty() || bytes.size > MAX_BYTES) {
            result.error("INVALID_EXPORT", "The export is empty or too large.", null); return
        }
        writing = true
        io.execute {
            var success = false
            try {
                resolver.openOutputStream(uri, "wt")?.use { stream ->
                    stream.write(bytes)
                    stream.flush()
                    success = true
                }
            } catch (_: Exception) { success = false }
            finally { bytes.fill(0) }
            if (!success) {
                try { DocumentsContract.deleteDocument(resolver, uri) } catch (_: Exception) { /* provider may deny cleanup */ }
            }
            main.post {
                writing = false
                selectedId = null
                selectedUri = null
                if (attached) {
                    if (success) result.success(true)
                    else result.error("WRITE_FAILED", "The document provider did not confirm the export. Retry with a writable destination.", null)
                }
            }
        }
    }

    private fun discardSelection() {
        val resolver = binding?.activity?.contentResolver
        val uri = selectedUri
        selectedId = null
        selectedUri = null
        if (resolver != null && uri != null) io.execute {
            try { DocumentsContract.deleteDocument(resolver, uri) } catch (_: Exception) { /* no plaintext application cache exists */ }
        }
    }

    private fun attach(value: ActivityPluginBinding) { binding = value; value.addActivityResultListener(this) }
    private fun detach() {
        picker?.error("CANCELLED", "The export was interrupted. Choose the destination again.", null)
        picker = null
        if (!writing) discardSelection()
        binding?.removeActivityResultListener(this)
        binding = null
    }
    override fun onAttachedToActivity(binding: ActivityPluginBinding) = attach(binding)
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = attach(binding)
    override fun onDetachedFromActivityForConfigChanges() = detach()
    override fun onDetachedFromActivity() = detach()
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        detach()
        attached = false
        channel?.setMethodCallHandler(null)
        channel = null
        io.shutdown()
    }

    companion object { private const val REQUEST = 24116; private const val MAX_BYTES = 4 * 1024 * 1024 }
}
