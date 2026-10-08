package com.spideli.store

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * Serves the admin's order ringtone (globalSettings.order_ringtone_url) to the system as
 * content://<applicationId>.order_ringtone/order_ringtones/order_ringtone_<key>.<ext>, the
 * sound of the notification channel made for it (.claude/PUSH-CHANNELS.md, "Order ringtone").
 * The Dart OrderRingtoneService downloads and stores the file under files/order_ringtones/
 * itself (also from the FCM background isolate, where the channel below does not exist).
 *
 * The system UI plays a channel's sound with its own identity, so it is granted read access
 * to the files. That grant does not survive a reboot; every process start creates this
 * provider first (an FCM push starts the process before the push is shown), and the grant
 * is renewed here. The notification service also grants it per posted notification.
 */
class OrderRingtoneProvider : FileProvider() {
    override fun onCreate(): Boolean {
        val created = super.onCreate()
        val appContext = context?.applicationContext
        if (appContext != null) {
            Handler(Looper.getMainLooper()).post { OrderRingtoneFiles.grantAll(appContext) }
        }
        return created
    }
}

/** The ringtone files and the Dart channel `spideli/order_ringtone` (foreground engine). */
object OrderRingtoneFiles {
    private const val TAG = "OrderRingtone"
    private const val CHANNEL = "spideli/order_ringtone"
    private const val DIR = "order_ringtones"
    private const val PREFIX = "order_ringtone_"
    private const val SYSTEM_UI = "com.android.systemui"
    private val KEY = Regex("^[0-9a-f]{8}$")
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    private fun authority(context: Context) = "${context.packageName}.order_ringtone"

    private fun dir(context: Context) = File(context.filesDir, DIR)

    private fun ringtoneFiles(context: Context): List<File> =
        dir(context).listFiles()?.filter { it.isFile && it.name.startsWith(PREFIX) && it.length() > 0 } ?: emptyList()

    private fun uriFor(context: Context, file: File): Uri = FileProvider.getUriForFile(context, authority(context), file)

    private fun grant(context: Context, uri: Uri) {
        try {
            context.grantUriPermission(SYSTEM_UI, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        } catch (e: Exception) {
            Log.w(TAG, "read grant to the system UI failed: $e")
        }
    }

    fun grantAll(context: Context) {
        try {
            ringtoneFiles(context).forEach { grant(context, uriFor(context, it)) }
        } catch (e: Exception) {
            Log.w(TAG, "renewing the ringtone grants failed: $e")
        }
    }

    /** Where Dart stores the files, and the provider authority (kept for the background isolate). */
    private fun paths(context: Context): Map<String, String> {
        val folder = dir(context)
        folder.mkdirs()
        return mapOf("dir" to folder.absolutePath, "authority" to authority(context), "pathName" to DIR)
    }

    /** The content URI of the stored file for [key] (read granted to the system UI), or null. */
    private fun existing(context: Context, key: String): String? {
        if (!KEY.matches(key)) return null
        val file = ringtoneFiles(context).firstOrNull { it.name.startsWith("$PREFIX$key.") } ?: return null
        val uri = uriFor(context, file)
        grant(context, uri)
        return uri.toString()
    }

    /** Removes every ringtone file except [keepKey]'s: called once that key's channel exists. */
    private fun prune(context: Context, keepKey: String) {
        if (!KEY.matches(keepKey)) return
        dir(context).listFiles()?.forEach { if (!it.name.startsWith("$PREFIX$keepKey.")) it.delete() }
    }

    private fun clear(context: Context) {
        dir(context).listFiles()?.forEach { it.delete() }
    }

    fun register(messenger: BinaryMessenger, context: Context) {
        val appContext = context.applicationContext
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "paths", "existing", "prune", "clear" -> io.execute {
                    try {
                        val key = call.argument<String>("key") ?: ""
                        val value: Any? = when (call.method) {
                            "paths" -> paths(appContext)
                            "existing" -> existing(appContext, key)
                            "prune" -> {
                                prune(appContext, key)
                                null
                            }
                            else -> {
                                clear(appContext)
                                null
                            }
                        }
                        main.post { result.success(value) }
                    } catch (e: Exception) {
                        main.post { result.error("order_ringtone", e.message ?: e.toString(), null) }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
