package dev.pkarktools.app

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import kotlin.random.Random

class SafError(val code: String, message: String) : Exception(message)

/**
 * Puente con el Storage Access Framework (SAF).
 *
 * Permite elegir la carpeta de saves de un emulador (Yuzu/Eden/Sudachi/Citron,
 * Ryujinx, etc.) con el selector del sistema, conservar el permiso, listar sus
 * archivos y leer/escribir saves sin pedir acceso global al almacenamiento.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "dev.pkarktools/saf"
    private val pickTreeRequest = 0x5AF1
    private var pendingPick: MethodChannel.Result? = null
    private val io = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickTree" -> pickTree(result)
                "listFiles" -> background(result) { listFiles(call) }
                "readFile" -> background(result) { readFile(call) }
                "writeFile" -> background(result) { writeFile(call); null }
                // Carpeta del Arca (rutas relativas al árbol elegido).
                "treeCheck" -> background(result) { treeCheck(tree(call)) }
                "treeList" -> background(result) { treeList(tree(call), call.argument<String>("dir") ?: "") }
                "treeRead" -> background(result) { treeRead(tree(call), call.argument<String>("path")!!) }
                "treeExists" -> background(result) { resolve(tree(call), call.argument<String>("path")!!) != null }
                "treeWriteNew" -> background(result) {
                    treeWriteNew(tree(call), call.argument<String>("path")!!, call.argument<ByteArray>("bytes")!!); null
                }
                "treeDelete" -> background(result) { treeDelete(tree(call), call.argument<String>("path")!!); null }
                else -> result.notImplemented()
            }
        }
    }

    private fun background(result: MethodChannel.Result, block: () -> Any?) {
        io.execute {
            try {
                val value = block()
                runOnUiThread { result.success(value) }
            } catch (e: SafError) {
                runOnUiThread { result.error(e.code, e.message, null) }
            } catch (e: SecurityException) {
                runOnUiThread { result.error("access", e.message, null) }
            } catch (e: Exception) {
                runOnUiThread { result.error("saf_error", e.message, null) }
            }
        }
    }

    private fun pickTree(result: MethodChannel.Result) {
        if (pendingPick != null) {
            result.error("busy", "Ya hay un selector abierto", null)
            return
        }
        pendingPick = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
            )
        }
        @Suppress("DEPRECATION")
        startActivityForResult(intent, pickTreeRequest)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickTreeRequest) return
        val result = pendingPick ?: return
        pendingPick = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        try {
            contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
        } catch (_: SecurityException) {
            // Algunos proveedores no permiten persistir escritura: seguimos con lectura.
        }
        result.success(uri.toString())
    }

    /** Lista recursivamente los archivos del árbol (sin seguir más de maxDepth niveles). */
    private fun listFiles(call: MethodCall): List<Map<String, Any?>> {
        val tree = Uri.parse(call.argument<String>("uri")!!)
        val maxDepth = call.argument<Int>("maxDepth") ?: 12
        val out = mutableListOf<Map<String, Any?>>()
        val rootId = DocumentsContract.getTreeDocumentId(tree)
        val stack = ArrayDeque<Triple<String, String, Int>>()
        stack.add(Triple(rootId, "", 0))
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_SIZE,
        )
        while (stack.isNotEmpty() && out.size < 5000) {
            val (docId, prefix, depth) = stack.removeLast()
            val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, docId)
            contentResolver.query(children, projection, null, null, null)?.use { c ->
                while (c.moveToNext()) {
                    val id = c.getString(0)
                    val name = c.getString(1) ?: id
                    val mime = c.getString(2)
                    val size = if (c.isNull(3)) 0L else c.getLong(3)
                    val path = if (prefix.isEmpty()) name else "$prefix/$name"
                    if (mime == DocumentsContract.Document.MIME_TYPE_DIR) {
                        if (depth < maxDepth) stack.add(Triple(id, path, depth + 1))
                    } else {
                        out.add(
                            mapOf(
                                "uri" to DocumentsContract.buildDocumentUriUsingTree(tree, id).toString(),
                                "name" to name,
                                "path" to path,
                                "size" to size,
                            ),
                        )
                    }
                }
            }
        }
        return out
    }

    private fun readFile(call: MethodCall): ByteArray {
        val uri = Uri.parse(call.argument<String>("uri")!!)
        return contentResolver.openInputStream(uri)?.use { it.readBytes() }
            ?: throw IllegalStateException("No se pudo abrir $uri")
    }

    private fun writeFile(call: MethodCall) {
        val uri = Uri.parse(call.argument<String>("uri")!!)
        val bytes = call.argument<ByteArray>("bytes")!!
        contentResolver.openOutputStream(uri, "wt")?.use { it.write(bytes) }
            ?: throw IllegalStateException("No se pudo escribir $uri")
    }

    // ------------------------------------------------------------------ Arca

    private fun tree(call: MethodCall): Uri = Uri.parse(call.argument<String>("tree")!!)

    private fun hasPermission(tree: Uri): Boolean =
        contentResolver.persistedUriPermissions.any { it.uri == tree && it.isReadPermission && it.isWritePermission }

    private fun requireAccess(tree: Uri) {
        if (!hasPermission(tree)) throw SafError("access", "Sin permiso persistente sobre la carpeta")
    }

    private fun treeCheck(tree: Uri): Boolean {
        if (!hasPermission(tree)) return false
        return try {
            val rootId = DocumentsContract.getTreeDocumentId(tree)
            val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, rootId)
            contentResolver.query(children, arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID), null, null, null)
                ?.use { true } ?: false
        } catch (_: Exception) {
            false
        }
    }

    private fun segments(path: String) = path.split('/').filter { it.isNotEmpty() }

    /** Id del hijo [name] de [parentId], o null. */
    private fun childId(tree: Uri, parentId: String, name: String): Pair<String, String>? {
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, parentId)
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
        )
        contentResolver.query(children, projection, null, null, null)?.use { c ->
            while (c.moveToNext()) {
                if (c.getString(1) == name) return Pair(c.getString(0), c.getString(2) ?: "")
            }
        }
        return null
    }

    /** Recorre [path] por nombre desde la raíz; crea las carpetas si [createDirs]. */
    private fun resolve(tree: Uri, path: String, createDirs: Boolean = false): String? {
        requireAccess(tree)
        var id = DocumentsContract.getTreeDocumentId(tree)
        for (seg in segments(path)) {
            val child = childId(tree, id, seg)
            id = when {
                child != null -> child.first
                createDirs -> {
                    val parent = DocumentsContract.buildDocumentUriUsingTree(tree, id)
                    val created = DocumentsContract.createDocument(
                        contentResolver, parent, DocumentsContract.Document.MIME_TYPE_DIR, seg,
                    ) ?: throw SafError("saf_error", "No se pudo crear la carpeta $seg")
                    DocumentsContract.getDocumentId(created)
                }
                else -> return null
            }
        }
        return id
    }

    private fun treeList(tree: Uri, dir: String): List<Map<String, Any?>> {
        val startId = resolve(tree, dir) ?: return emptyList()
        val out = mutableListOf<Map<String, Any?>>()
        val stack = ArrayDeque<Triple<String, String, Int>>()
        stack.add(Triple(startId, segments(dir).joinToString("/"), 0))
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_SIZE,
            DocumentsContract.Document.COLUMN_LAST_MODIFIED,
        )
        while (stack.isNotEmpty() && out.size < 50000) {
            val (docId, prefix, depth) = stack.removeLast()
            val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, docId)
            contentResolver.query(children, projection, null, null, null)?.use { c ->
                while (c.moveToNext()) {
                    val id = c.getString(0)
                    val name = c.getString(1) ?: id
                    val path = if (prefix.isEmpty()) name else "$prefix/$name"
                    if (c.getString(2) == DocumentsContract.Document.MIME_TYPE_DIR) {
                        if (depth < 8) stack.add(Triple(id, path, depth + 1))
                    } else {
                        out.add(
                            mapOf(
                                "path" to path,
                                "size" to if (c.isNull(3)) 0L else c.getLong(3),
                                "modified" to if (c.isNull(4)) null else c.getLong(4),
                            ),
                        )
                    }
                }
            }
        }
        return out
    }

    private fun treeRead(tree: Uri, path: String): ByteArray {
        val id = resolve(tree, path) ?: throw SafError("not_found", "No existe $path")
        val uri = DocumentsContract.buildDocumentUriUsingTree(tree, id)
        return contentResolver.openInputStream(uri)?.use { it.readBytes() }
            ?: throw SafError("saf_error", "No se pudo abrir $path")
    }

    /**
     * Escribe un archivo nuevo: temporal oculto + rename. Nunca sobrescribe
     * (error "exists"). Si el proveedor no permite renombrar, escribe
     * directamente el archivo final.
     */
    private fun treeWriteNew(tree: Uri, path: String, bytes: ByteArray) {
        val segs = segments(path)
        val name = segs.last()
        val parentId = resolve(tree, segs.dropLast(1).joinToString("/"), createDirs = true)!!
        if (childId(tree, parentId, name) != null) throw SafError("exists", "Ya existe $path")
        val parent = DocumentsContract.buildDocumentUriUsingTree(tree, parentId)
        val tmpName = ".$name.${Random.nextInt().toUInt().toString(16)}.tmp"
        val mime = "application/octet-stream"
        val tmp = DocumentsContract.createDocument(contentResolver, parent, mime, tmpName)
            ?: throw SafError("saf_error", "No se pudo crear $tmpName")
        try {
            contentResolver.openOutputStream(tmp, "w")?.use { it.write(bytes) }
                ?: throw SafError("saf_error", "No se pudo escribir $tmpName")
            if (childId(tree, parentId, name) != null) throw SafError("exists", "Ya existe $path")
            val renamed = try {
                DocumentsContract.renameDocument(contentResolver, tmp, name) ?: tmp
            } catch (_: UnsupportedOperationException) {
                null
            }
            if (renamed == null) {
                DocumentsContract.deleteDocument(contentResolver, tmp)
                val direct = DocumentsContract.createDocument(contentResolver, parent, mime, name)
                    ?: throw SafError("saf_error", "No se pudo crear $name")
                contentResolver.openOutputStream(direct, "w")?.use { it.write(bytes) }
                return
            }
            // Algunos proveedores renombran a "nombre (1)" si hubo carrera.
            val actual = childId(tree, parentId, name)
            if (actual == null) {
                DocumentsContract.deleteDocument(contentResolver, renamed)
                throw SafError("exists", "Ya existe $path")
            }
        } catch (e: Exception) {
            try {
                DocumentsContract.deleteDocument(contentResolver, tmp)
            } catch (_: Exception) {
            }
            throw e
        }
    }

    private fun treeDelete(tree: Uri, path: String) {
        val id = resolve(tree, path) ?: return
        DocumentsContract.deleteDocument(contentResolver, DocumentsContract.buildDocumentUriUsingTree(tree, id))
    }
}
