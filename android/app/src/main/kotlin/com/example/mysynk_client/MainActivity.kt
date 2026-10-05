package com.example.mysynk_client

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private companion object {
        const val CHANNEL = "com.example.mysynk/device_identity"
        const val SAF_CHANNEL = "com.example.mysynk/saf"
        const val GET_ANDROID_ID = "getAndroidId"
        const val PICK_DIRECTORY = "pickDirectory"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                GET_ANDROID_ID -> {
                    val androidId = Settings.Secure.getString(
                        contentResolver,
                        Settings.Secure.ANDROID_ID,
                    )

                    if (androidId.isNullOrBlank()) {
                        result.error(
                            "ANDROID_ID_UNAVAILABLE",
                            "No se pudo obtener ANDROID_ID.",
                            null,
                        )
                    } else {
                        result.success(androidId)
                    }
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SAF_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                PICK_DIRECTORY -> {
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                        addFlags(
                            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
                        )
                    }

                    startActivityForResult(intent, 1001)
                    pendingSafResult = result
                }

                else -> result.notImplemented()
            }
        }
    }

    private var pendingSafResult: MethodChannel.Result? = null

    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?,
    ) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode != 1001) {
            return
        }

        val result = pendingSafResult
        pendingSafResult = null

        if (result == null) {
            return
        }

        if (resultCode != RESULT_OK || data?.data == null) {
            result.success(null)
            return
        }

        val uri: Uri = data.data!!

        try {
            contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
        } catch (error: SecurityException) {
            result.error(
                "SAF_PERMISSION_ERROR",
                "No se pudo conservar el permiso de la carpeta.",
                error.message,
            )
            return
        }

        val tree = DocumentFile.fromTreeUri(this, uri)

        if (tree == null) {
            result.error(
                "SAF_TREE_ERROR",
                "No se pudo abrir la carpeta seleccionada.",
                null,
            )
            return
        }

        result.success(
            mapOf(
                "uri" to uri.toString(),
                "name" to (tree.name ?: ""),
            ),
        )
    }
}
