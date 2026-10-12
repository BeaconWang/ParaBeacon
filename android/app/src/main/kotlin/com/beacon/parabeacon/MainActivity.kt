package com.beacon.parabeacon

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val FLIGHT_LIBRARY_CHANNEL = "com.beacon.parabeacon/flight_library"
        private const val CREATE_DOCUMENT_REQUEST = 4107
        private const val ZIP_MIME_TYPE = "application/zip"
    }

    private var pendingSaveResult: MethodChannel.Result? = null
    private var pendingSaveBytes: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            FLIGHT_LIBRARY_CHANNEL,
        ).setMethodCallHandler { call, result ->
            if (call.method != "saveFlightBundle") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            if (pendingSaveResult != null) {
                result.error("SAVE_IN_PROGRESS", "A flight export is already being saved.", null)
                return@setMethodCallHandler
            }

            val fileName = call.argument<String>("fileName")
            val bytes = call.argument<ByteArray>("bytes")
            if (fileName.isNullOrBlank() || bytes == null) {
                result.error("INVALID_EXPORT", "The flight export data is invalid.", null)
                return@setMethodCallHandler
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                saveToDownloads(fileName, bytes, result)
            } else {
                chooseSaveLocation(fileName, bytes, result)
            }
        }
    }

    private fun saveToDownloads(
        fileName: String,
        bytes: ByteArray,
        result: MethodChannel.Result,
    ) {
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
            put(MediaStore.MediaColumns.MIME_TYPE, ZIP_MIME_TYPE)
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
        bytes: ByteArray,
        result: MethodChannel.Result,
    ) {
        pendingSaveResult = result
        pendingSaveBytes = bytes
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = ZIP_MIME_TYPE
            putExtra(Intent.EXTRA_TITLE, fileName)
        }
        try {
            startActivityForResult(intent, CREATE_DOCUMENT_REQUEST)
        } catch (error: Exception) {
            pendingSaveResult = null
            pendingSaveBytes = null
            result.error("SAVE_PICKER_FAILED", error.message, null)
        }
    }

    @Deprecated("Deprecated in Android, but required for FlutterActivity result handling")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != CREATE_DOCUMENT_REQUEST) return

        val result = pendingSaveResult ?: return
        val bytes = pendingSaveBytes
        pendingSaveResult = null
        pendingSaveBytes = null

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(null)
            return
        }

        val uri: Uri = data.data!!
        try {
            if (bytes == null) {
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
