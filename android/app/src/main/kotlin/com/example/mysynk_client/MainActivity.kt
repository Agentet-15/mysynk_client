package com.example.mysynk_client

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.security.MessageDigest

class MainActivity : FlutterActivity() {

    private companion object {
        const val CHANNEL = "com.example.mysynk/device_identity"
        const val SAF_CHANNEL = "com.example.mysynk/saf"
        const val GET_ANDROID_ID = "getAndroidId"
        const val GET_DEVICE_NAME = "getDeviceName"
        const val PICK_DIRECTORY = "pickDirectory"
        const val CHECK_DIRECTORY = "checkDirectory"
        const val LIST_DIRECTORY = "listDirectory"
        const val READ_FILE = "readFile"
        const val HASH_FILE = "hashFile"
        const val WRITE_FILE = "writeFile"
        const val CREATE_DIRECTORY = "createDirectory"
        const val DELETE_ENTRY = "deleteEntry"
        const val SAF_REQUEST_CODE = 1001
    }

    private var pendingSafResult: MethodChannel.Result? = null

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

                GET_DEVICE_NAME -> {
                    val manufacturer = Build.MANUFACTURER.trim()
                    val model = Build.MODEL.trim()

                    val label = if (
                        model.startsWith(manufacturer, ignoreCase = true)
                    ) {
                        model
                    } else {
                        "$manufacturer $model"
                    }

                    result.success(
                        label.replace(Regex("\\s+"), " ").trim(),
                    )
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SAF_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                PICK_DIRECTORY -> pickDirectory(result)

                CHECK_DIRECTORY -> withRoot(
                    call.argument("root"),
                    result,
                ) { result.success(true) }

                LIST_DIRECTORY -> withRoot(call.argument("root"), result) { tree ->
                    val entries = mutableListOf<Map<String, Any?>>()
                    listDocuments(tree, "", entries)
                    result.success(entries)
                }

                READ_FILE -> withDocument(
                    call.argument("root"),
                    call.argument("path"),
                    result,
                ) { document ->
                    val offset = (call.argument<Number>("offset")?.toLong() ?: 0L)
                        .coerceAtLeast(0L)
                    val length = call.argument<Number>("length")?.toLong() ?: -1L

                    contentResolver.openInputStream(document.uri).use { stream ->
                        if (stream == null) {
                            result.error(
                                "SAF_READ_ERROR",
                                "No se pudo abrir el archivo.",
                                null,
                            )
                            return@withDocument
                        }

                        var skipped = 0L
                        while (skipped < offset) {
                            val count = stream.skip(offset - skipped)
                            if (count <= 0L) break
                            skipped += count
                        }

                        val bytes = if (length < 0) {
                            stream.readBytes()
                        } else {
                            stream.readLimited(length.toInt())
                        }

                        result.success(bytes)
                    }
                }

                HASH_FILE -> withDocument(
                    call.argument("root"),
                    call.argument("path"),
                    result,
                ) { document ->
                    val digest = MessageDigest.getInstance("SHA-256")
                    contentResolver.openInputStream(document.uri).use { stream ->
                        if (stream == null) {
                            result.error(
                                "SAF_READ_ERROR",
                                "No se pudo abrir el archivo.",
                                null,
                            )
                            return@withDocument
                        }

                        val buffer = ByteArray(64 * 1024)
                        while (true) {
                            val count = stream.read(buffer)
                            if (count <= 0) break
                            digest.update(buffer, 0, count)
                        }
                    }

                    result.success(
                        digest.digest().joinToString("") { "%02x".format(it) },
                    )
                }

                WRITE_FILE -> withRoot(call.argument("root"), result) { tree ->
                    val relativePath = normalizePath(call.argument<String>("path"))
                    val bytes = call.argument<ByteArray>("bytes")

                    if (relativePath.isNullOrBlank() || bytes == null) {
                        result.error(
                            "SAF_INVALID_ARGUMENT",
                            "Faltan la ruta o el contenido del archivo.",
                            null,
                        )
                        return@withRoot
                    }

                    val segments = relativePath.split('/').filter { it.isNotBlank() }
                    var parent = tree

                    for (segment in segments.dropLast(1)) {
                        parent = parent.findFile(segment)
                            ?: parent.createDirectory(segment)
                            ?: run {
                                result.error(
                                    "SAF_WRITE_ERROR",
                                    "No se pudo crear la carpeta $segment.",
                                    null,
                                )
                                return@withRoot
                            }
                    }

                    val name = segments.last()
                    parent.findFile(name)?.delete()

                    val file = parent.createFile("application/octet-stream", name)
                    if (file == null) {
                        result.error(
                            "SAF_WRITE_ERROR",
                            "No se pudo crear el archivo $name.",
                            null,
                        )
                        return@withRoot
                    }

                    contentResolver.openOutputStream(file.uri).use { output ->
                        if (output == null) {
                            result.error(
                                "SAF_WRITE_ERROR",
                                "No se pudo abrir el archivo para escribir.",
                                null,
                            )
                            return@withRoot
                        }
                        output.write(bytes)
                        output.flush()
                    }

                    result.success(
                        mapOf(
                            "path" to relativePath,
                            "size" to bytes.size.toLong(),
                        ),
                    )
                }

                CREATE_DIRECTORY -> withRoot(call.argument("root"), result) { tree ->
                    val relativePath = normalizePath(call.argument<String>("path"))

                    if (relativePath.isNullOrBlank()) {
                        result.error(
                            "SAF_INVALID_ARGUMENT",
                            "La ruta de la carpeta está vacía.",
                            null,
                        )
                        return@withRoot
                    }

                    var current = tree

                    for (segment in relativePath.split('/').filter { it.isNotBlank() }) {
                        current = current.findFile(segment)
                            ?: current.createDirectory(segment)
                            ?: run {
                                result.error(
                                    "SAF_WRITE_ERROR",
                                    "No se pudo crear la carpeta $segment.",
                                    null,
                                )
                                return@withRoot
                            }
                    }

                    result.success(mapOf("path" to relativePath))
                }

                DELETE_ENTRY -> withDocument(
                    call.argument("root"),
                    call.argument("path"),
                    result,
                ) { document ->
                    result.success(document.delete())
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun pickDirectory(result: MethodChannel.Result) {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
            )
        }

        pendingSafResult = result
        startActivityForResult(intent, SAF_REQUEST_CODE)
    }

    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?,
    ) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode != SAF_REQUEST_CODE) {
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

    private fun InputStream.readLimited(length: Int): ByteArray {
        val output = ByteArrayOutputStream()
        val buffer = ByteArray(64 * 1024)
        var remaining = length

        while (remaining > 0) {
            val count = read(buffer, 0, minOf(buffer.size, remaining))

            if (count <= 0) {
                break
            }

            output.write(buffer, 0, count)
            remaining -= count
        }

        return output.toByteArray()
    }

    private fun normalizePath(path: String?): String? =
        path?.trim()?.replace('\\', '/')?.trim('/')

    private fun treeFor(root: String?): DocumentFile? {
        if (root.isNullOrBlank()) {
            return null
        }

        return try {
            DocumentFile.fromTreeUri(this, Uri.parse(root))
        } catch (_: Exception) {
            null
        }
    }

    private inline fun withRoot(
        root: String?,
        result: MethodChannel.Result,
        block: (DocumentFile) -> Unit,
    ) {
        val tree = treeFor(root)

        if (tree == null || !tree.isDirectory) {
            result.error(
                "SAF_INVALID_ROOT",
                "La carpeta SAF no está disponible. Vuelve a elegirla.",
                null,
            )
            return
        }

        try {
            block(tree)
        } catch (error: Exception) {
            result.error(
                "SAF_ERROR",
                error.message ?: "Error al acceder a la carpeta.",
                null,
            )
        }
    }

    private inline fun withDocument(
        root: String?,
        path: String?,
        result: MethodChannel.Result,
        block: (DocumentFile) -> Unit,
    ) = withRoot(root, result) { tree ->
        val relativePath = normalizePath(path)

        if (relativePath.isNullOrBlank()) {
            result.error(
                "SAF_INVALID_ARGUMENT",
                "La ruta del archivo está vacía.",
                null,
            )
            return@withRoot
        }

        var current = tree

        for (segment in relativePath.split('/').filter { it.isNotBlank() }) {
            current = current.findFile(segment) ?: run {
                result.error(
                    "SAF_NOT_FOUND",
                    "No se encontró $segment dentro de la carpeta.",
                    null,
                )
                return@withRoot
            }
        }

        block(current)
    }

    private fun listDocuments(
        directory: DocumentFile,
        prefix: String,
        output: MutableList<Map<String, Any?>>,
    ) {
        for (child in directory.listFiles()) {
            val name = child.name ?: continue
            val path = if (prefix.isEmpty()) name else "$prefix/$name"
            val isDirectory = child.isDirectory

            output.add(
                mapOf(
                    "path" to path,
                    "type" to if (isDirectory) "directory" else "file",
                    "size" to if (isDirectory) 0L else child.length(),
                    "modified" to child.lastModified(),
                    "uri" to child.uri.toString(),
                ),
            )

            if (isDirectory) {
                listDocuments(child, path, output)
            }
        }
    }
}
