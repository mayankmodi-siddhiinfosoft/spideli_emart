package com.spideli.store

import android.app.AppOpsManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Background delivery on phones whose system blocks closed apps
        // (Xiaomi / Redmi / POCO "Autostart", Oppo, Vivo, Huawei, OnePlus):
        // with it off, swiping the app away stops it and no push is shown.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "spideli/background_delivery").setMethodCallHandler { call, result ->
            when (call.method) {
                "manufacturer" -> result.success(Build.MANUFACTURER ?: "")
                "autostartAllowed" -> result.success(miuiAutostartAllowed())
                "openAutostartSettings" -> result.success(openFirst(autostartIntents() + appDetailsIntent()))
                "openAppSettings" -> result.success(openFirst(listOf(appDetailsIntent())))
                else -> result.notImplemented()
            }
        }
    }

    /** Xiaomi only: true / false from the MIUI app-op 10008, null when unknown. */
    private fun miuiAutostartAllowed(): Boolean? {
        if (!Build.MANUFACTURER.equals("Xiaomi", ignoreCase = true)) return null
        return try {
            val ops = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val method = AppOpsManager::class.java.getMethod("checkOpNoThrow", Int::class.javaPrimitiveType, Int::class.javaPrimitiveType, String::class.java)
            (method.invoke(ops, 10008, Process.myUid(), packageName) as Int) == AppOpsManager.MODE_ALLOWED
        } catch (e: Exception) {
            null
        }
    }

    private fun autostartIntents(): List<Intent> = listOf(
        ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity"),
        ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity"),
        ComponentName("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity"),
        ComponentName("com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity"),
        ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"),
        ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity"),
        ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"),
        ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity"),
        ComponentName("com.oneplus.security", "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity"),
    ).map { Intent().setComponent(it).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }

    private fun appDetailsIntent(): Intent =
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

    /** Starts the first intent the phone has; true when one opened. */
    private fun openFirst(intents: List<Intent>): Boolean {
        for (intent in intents) {
            try {
                startActivity(intent)
                return true
            } catch (e: Exception) {
                // Not on this phone (or not exported): try the next one.
            }
        }
        return false
    }
}
