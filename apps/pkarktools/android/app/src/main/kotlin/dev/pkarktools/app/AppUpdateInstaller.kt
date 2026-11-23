package dev.pkarktools.app

import android.app.Activity
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageInstaller
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * Actualizar la app desde Ajustes: entrega el APK descargado al instalador del
 * sistema con una sesión de [PackageInstaller]. Android pide siempre una
 * confirmación al usuario (la app no viene de una tienda); si acepta, cierra
 * la app y la deja actualizada con sus datos.
 */
class AppUpdateInstaller(private val activity: Activity, messenger: BinaryMessenger) {
    companion object {
        const val STATUS_ACTION = "dev.pkarktools.app.INSTALL_STATUS"
    }

    private val io = Executors.newSingleThreadExecutor()
    private var pending: MethodChannel.Result? = null

    init {
        MethodChannel(messenger, "dev.pkarktools/update").setMethodCallHandler { call, result ->
            when (call.method) {
                "canInstall" -> result.success(canInstall())
                "openInstallPermission" -> {
                    openInstallPermission()
                    result.success(null)
                }
                "install" -> install(call.argument<String>("path")!!, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun canInstall(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O || activity.packageManager.canRequestPackageInstalls()

    private fun openInstallPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        activity.startActivity(
            Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:${activity.packageName}")),
        )
    }

    private fun install(path: String, result: MethodChannel.Result) {
        if (!canInstall()) {
            result.error("permission", "Falta el permiso para instalar apps", null)
            return
        }
        // Una instalación anterior sin respuesta (el usuario salió sin elegir).
        pending?.error("aborted", "Sustituida por otra instalación", null)
        pending = result
        io.execute {
            try {
                val apk = File(path)
                val installer = activity.packageManager.packageInstaller
                val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL).apply {
                    setAppPackageName(activity.packageName)
                    setSize(apk.length())
                }
                val id = installer.createSession(params)
                installer.openSession(id).use { session ->
                    session.openWrite("base.apk", 0, apk.length()).use { out ->
                        apk.inputStream().use { it.copyTo(out) }
                        session.fsync(out)
                    }
                    val intent = Intent(activity, activity.javaClass).setAction(STATUS_ACTION)
                        .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    var flags = PendingIntent.FLAG_UPDATE_CURRENT
                    // El sistema rellena los extras del estado: tiene que ser mutable.
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) flags = flags or PendingIntent.FLAG_MUTABLE
                    session.commit(PendingIntent.getActivity(activity, id, intent, flags).intentSender)
                }
            } catch (e: Exception) {
                activity.runOnUiThread { finish("install", e.message) }
            }
        }
    }

    /** Estado de la sesión (llega por onNewIntent). `true` si era nuestro. */
    fun onIntent(intent: Intent): Boolean {
        if (intent.action != STATUS_ACTION) return false
        val status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)
        val message = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)
        when (status) {
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                @Suppress("DEPRECATION")
                val confirm = intent.getParcelableExtra<Intent>(Intent.EXTRA_INTENT)
                if (confirm == null) finish("install", message) else activity.startActivity(confirm)
            }
            // Normalmente no llega: Android cierra la app al actualizarla.
            PackageInstaller.STATUS_SUCCESS -> pending?.success(null).also { pending = null }
            PackageInstaller.STATUS_FAILURE_ABORTED -> finish("aborted", message)
            PackageInstaller.STATUS_FAILURE_CONFLICT -> finish("conflict", message)
            PackageInstaller.STATUS_FAILURE_INCOMPATIBLE -> finish("incompatible", message)
            PackageInstaller.STATUS_FAILURE_STORAGE -> finish("storage", message)
            PackageInstaller.STATUS_FAILURE_BLOCKED -> finish("permission", message)
            else -> finish("install", message)
        }
        return true
    }

    private fun finish(code: String, message: String?) {
        pending?.error(code, message, null)
        pending = null
    }
}
