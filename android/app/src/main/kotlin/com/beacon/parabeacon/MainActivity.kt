package com.beacon.parabeacon

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val FLIGHT_LIBRARY_CHANNEL = "com.beacon.parabeacon/flight_library"
        private const val CREATE_DOCUMENT_REQUEST = 4107
        private const val OPEN_IGC_TREE_REQUEST = 4108
        private const val ZIP_MIME_TYPE = "application/zip"
    }

    private var pendingSaveResult: MethodChannel.Result? = null
    private var pendingSaveBytes: ByteArray? = null
    private var pendingSaveMimeType: String? = null
    private var pendingImportResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            FLIGHT_LIBRARY_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveFlightBundle" -> handleSaveFlightBundle(call, result)
                "saveFlightFile" -> handleSaveFlightFile(call, result)
                "importIgcFolder" -> handleImportIgcFolder(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun handleSaveFlightBundle(
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result,
    ) {
        if (pendingSaveResult != null) {
            result.error("SAVE_IN_PROGRESS", "A flight export is already being saved.", null)
            return
        }

        val fileName = call.argument<String>("fileName")
        val bytes = call.argument<ByteArray>("bytes")
        if (fileName.isNullOrBlank() || bytes == null) {
            result.error("INVALID_EXPORT", "The flight export data is invalid.", null)
            return
        }

        handleSaveFile(fileName, ZIP_MIME_TYPE, bytes, result)
    }

    private fun handleSaveFlightFile(
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result,
    ) {
        if (pendingSaveResult != null) {
            result.error("SAVE_IN_PROGRESS", "A flight export is already being saved.", null)
            return
        }
        val fileName = call.argument<String>("fileName")
        val mimeType = call.argument<String>("mimeType")
        val bytes = call.argument<ByteArray>("bytes")
        if (fileName.isNullOrBlank() || mimeType.isNullOrBlank() || bytes == null) {
            result.error("INVALID_EXPORT", "The flight export data is invalid.", null)
            return
        }
        handleSaveFile(fileName, mimeType, bytes, result)
    }

    private fun handleSaveFile(
        fileName: String,
        mimeType: String,
        bytes: ByteArray,
        result: MethodChannel.Result,
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            saveToDownloads(fileName, mimeType, bytes, result)
        } else {
            chooseSaveLocation(fileName, mimeType, bytes, result)
        }
    }

    // ── XCTrack .igc folder import (Storage Access Framework) ───────────────

    /// Launches the system folder picker. The user grants read access to a
    /// whole directory tree in one selection (no per-file count limit), and we
    /// read every `.igc` file in it via the content resolver — so an unlimited
    /// number of tracklogs can be imported.
    private fun handleImportIgcFolder(result: MethodChannel.Result) {
        if (pendingImportResult != null) {
            result.error("IMPORT_IN_PROGRESS", "A folder import is already in progress.", null)
            return
        }
        pendingImportResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
        try {
            startActivityForResult(intent, OPEN_IGC_TREE_REQUEST)
        } catch (error: Exception) {
            pendingImportResult = null
            result.error("IMPORT_PICKER_FAILED", error.message, null)
        }
    }

    private fun readIgcTree(treeUri: Uri, result: MethodChannel.Result) {
        Thread {
            try {
                val files = ArrayList<Map<String, Any>>()
                val rootDocId = DocumentsContract.getTreeDocumentId(treeUri)
                collectIgcFiles(treeUri, rootDocId, files)
                runOnUiThread { result.success(files) }
            } catch (error: Exception) {
                runOnUiThread { result.error("IMPORT_READ_FAILED", error.message, null) }
            }
        }.start()
    }

    private fun collectIgcFiles(
        treeUri: Uri,
        documentId: String,
        out: MutableList<Map<String, Any>>,
    ) {
        val childrenUri =
            DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, documentId)
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
        )
        contentResolver.query(childrenUri, projection, null, null, null)?.use { cursor ->
            val idIdx = cursor.getColumnIndexOrThrow(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            )
            val nameIdx = cursor.getColumnIndexOrThrow(
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            )
            val mimeIdx = cursor.getColumnIndexOrThrow(
                DocumentsContract.Document.COLUMN_MIME_TYPE,
            )
            while (cursor.moveToNext()) {
                val childId = cursor.getString(idIdx)
                val name = cursor.getString(nameIdx) ?: ""
                val mime = cursor.getString(mimeIdx)
                if (mime == DocumentsContract.Document.MIME_TYPE_DIR) {
                    // Recurse so a Tracklogs folder with year/subfolders is covered.
                    collectIgcFiles(treeUri, childId, out)
                } else if (name.lowercase().endsWith(".igc")) {
                    val fileUri =
                        DocumentsContract.buildDocumentUriUsingTree(treeUri, childId)
                    val bytes = contentResolver.openInputStream(fileUri)?.use {
                        it.readBytes()
                    }
                    if (bytes != null) {
                        out.add(mapOf("name" to name, "content" to bytes))
                    }
                }
            }
        }
    }

    private fun saveToDownloads(
        fileName: String,
        mimeType: String,
        bytes: ByteArray,
        result: MethodChannel.Result,
    ) {
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
            put(
                MediaStore.MediaColumns.RELATIVE_PATH,
                "${Environment.DIRECTORY_DOWNLOADS}/ParaBeacon",
            )
        }
        val uri = contentResolver.insert(
            MediaStore.Downloads.EXTERNAL_CONTENT_URI,
            values,
        )
        if (uri == null) {
            result.error("SAVE_FAILED", "Unable to create a file in Downloads/ParaBeacon.", null)
            return
        }

        try {
            contentResolver.openOutputStream(uri, "w")?.use { output ->
                output.write(bytes)
                output.flush()
            } ?: throw IllegalStateException("Unable to open the export file.")
            result.success(uri.toString())
        } catch (error: Exception) {
            contentResolver.delete(uri, null, null)
            result.error("SAVE_FAILED", error.message, null)
        }
    }

    private fun chooseSaveLocation(
        fileName: String,
        mimeType: String,
        bytes: ByteArray,
        result: MethodChannel.Result,
    ) {
        pendingSaveResult = result
        pendingSaveBytes = bytes
        pendingSaveMimeType = mimeType
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeType
            putExtra(Intent.EXTRA_TITLE, fileName)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                putExtra(
                    DocumentsContract.EXTRA_INITIAL_URI,
                    Uri.parse("content://com.android.externalstorage.documents/document/primary%3ADownload"),
                )
            }
        }
        try {
            startActivityForResult(intent, CREATE_DOCUMENT_REQUEST)
        } catch (error: Exception) {
            pendingSaveResult = null
            pendingSaveBytes = null
            pendingSaveMimeType = null
            result.error("SAVE_PICKER_FAILED", error.message, null)
        }
    }

    @Deprecated("Deprecated in Android, but required for FlutterActivity result handling")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == OPEN_IGC_TREE_REQUEST) {
            val result = pendingImportResult ?: return
            pendingImportResult = null
            val treeUri = data?.data
            if (resultCode != Activity.RESULT_OK || treeUri == null) {
                result.success(null) // user cancelled
                return
            }
            readIgcTree(treeUri, result)
            return
        }
        if (requestCode != CREATE_DOCUMENT_REQUEST) return

        val result = pendingSaveResult ?: return
        val bytes = pendingSaveBytes
        val mimeType = pendingSaveMimeType
        pendingSaveResult = null
        pendingSaveBytes = null
        pendingSaveMimeType = null

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(null)
            return
        }

        val uri: Uri = data.data!!
        try {
            if (bytes == null || mimeType.isNullOrBlank()) {
                result.error("INVALID_EXPORT", "The flight export data is missing.", null)
                return
            }
            contentResolver.openOutputStream(uri, "w")?.use { output ->
                output.write(bytes)
                output.flush()
            } ?: throw IllegalStateException("Unable to open the selected destination.")
            result.success(uri.toString())
        } catch (error: Exception) {
            result.error("SAVE_FAILED", error.message, null)
        }
    }
}
