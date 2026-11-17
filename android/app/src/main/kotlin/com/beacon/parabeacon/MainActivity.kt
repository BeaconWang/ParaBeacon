package com.beacon.parabeacon

import android.app.Activity
import android.app.DownloadManager
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.PowerManager
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.provider.Settings
import androidx.core.content.FileProvider
import java.io.File
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val FLIGHT_LIBRARY_CHANNEL = "com.beacon.parabeacon/flight_library"
        private const val FLIGHT_PERMISSIONS_CHANNEL = "com.beacon.parabeacon/flight_permissions"
        private const val DEVICE_INFO_CHANNEL = "com.beacon.parabeacon/device_info"
        private const val APP_UPDATE_CHANNEL = "com.beacon.parabeacon/app_update"
        private const val MAX_APK_SIZE_BYTES = 512L * 1024L * 1024L
        private const val CREATE_DOCUMENT_REQUEST = 4107
        private const val OPEN_IGC_TREE_REQUEST = 4108
        private const val BATTERY_PERMISSION_SETTINGS_REQUEST = 4109
        private const val FLIGHT_BUNDLE_MIME_TYPE = "application/zip"
    }

    private var pendingSaveResult: MethodChannel.Result? = null
    private var pendingSaveBytes: ByteArray? = null
    private var pendingSaveMimeType: String? = null
    private var pendingImportResult: MethodChannel.Result? = null
    private var pendingBatteryPermissionSettingsResult: MethodChannel.Result? = null
    private var pendingApkDownloadResult: MethodChannel.Result? = null

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
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            FLIGHT_PERMISSIONS_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getFlightPermissionStatuses" -> result.success(
                    getFlightPermissionStatuses(),
                )
                "openBackgroundLocationSettings" -> openBackgroundLocationSettings(result)
                "openBatteryOptimizationSettings" -> openBatteryOptimizationSettings(result)
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DEVICE_INFO_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getDeviceInfo" -> result.success(getDeviceInfo())
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            APP_UPDATE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isWifiConnected" -> result.success(isWifiConnected())
                "isAirplaneModeEnabled" -> result.success(isAirplaneModeEnabled())
                "downloadApk" -> handleApkDownload(call, result)
                "installApk" -> handleInstallApk(call, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun isWifiConnected(): Boolean {
        val manager = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            ?: return false
        val network = manager.activeNetwork ?: return false
        val capabilities = manager.getNetworkCapabilities(network) ?: return false
        return capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)
    }

    private fun isAirplaneModeEnabled(): Boolean =
        Settings.Global.getInt(
            contentResolver,
            Settings.Global.AIRPLANE_MODE_ON,
            0,
        ) != 0

    private fun handleApkDownload(
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result,
    ) {
        if (pendingApkDownloadResult != null) {
            result.error("UPDATE_IN_PROGRESS", "An APK download is already running.", null)
            return
        }
        val rawUrl = call.argument<String>("url")
        val fileName = call.argument<String>("fileName")
        val expectedSize = call.argument<Number>("sizeBytes")?.toLong()
        val expectedSha256 = call.argument<String>("sha256")?.lowercase()
        val rawServerOrigin = call.argument<String>("serverOrigin")
        val uri = rawUrl?.let { runCatching { Uri.parse(it) }.getOrNull() }
        val serverOrigin = rawServerOrigin?.let { runCatching { Uri.parse(it) }.getOrNull() }
        fun httpsPort(value: Uri): Int? = when {
            value.port == -1 -> 443
            value.port in 1..65535 -> value.port
            else -> null
        }
        if (uri == null ||
            serverOrigin == null ||
            serverOrigin.scheme != "https" ||
            serverOrigin.host.isNullOrEmpty() ||
            !serverOrigin.userInfo.isNullOrEmpty() ||
            (serverOrigin.path.orEmpty().isNotEmpty() && serverOrigin.path != "/") ||
            serverOrigin.query != null ||
            serverOrigin.fragment != null ||
            httpsPort(serverOrigin) == null ||
            uri.scheme != "https" ||
            uri.host?.equals(serverOrigin.host, ignoreCase = true) != true ||
            httpsPort(uri) != httpsPort(serverOrigin) ||
            !uri.userInfo.isNullOrEmpty() ||
            uri.query != null ||
            uri.fragment != null ||
            uri.path?.matches(Regex("/api/v1/app/releases/[1-9][0-9]*/download")) != true ||
            !fileName.orEmpty().matches(Regex("parabeacon-[1-9][0-9]*\\.apk")) ||
            expectedSize == null || expectedSize !in 1..MAX_APK_SIZE_BYTES ||
            !expectedSha256.orEmpty().matches(Regex("[a-f0-9]{64}"))) {
            result.error("INVALID_UPDATE", "The update metadata is invalid.", null)
            return
        }
        if (!isWifiConnected()) {
            result.error("WIFI_REQUIRED", "APK updates are downloaded over Wi-Fi only.", null)
            return
        }
        val downloadDirectory = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
        if (downloadDirectory == null) {
            result.error("UPDATE_STORAGE_UNAVAILABLE", "App download storage is unavailable.", null)
            return
        }
        pendingApkDownloadResult = result
        Thread {
            var downloadId = -1L
            val manager = getSystemService(Context.DOWNLOAD_SERVICE) as? DownloadManager
            try {
                if (manager == null) throw IllegalStateException("Android DownloadManager is unavailable.")
                val destination = File(downloadDirectory, fileName!!)
                if (destination.exists() && !destination.delete()) {
                    throw IllegalStateException("Unable to replace the previous APK download.")
                }
                val request = DownloadManager.Request(uri).apply {
                    setAllowedNetworkTypes(DownloadManager.Request.NETWORK_WIFI)
                    setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
                    setTitle("ParaBeacon update $fileName")
                    setDescription("Downloading over Wi-Fi")
                    setMimeType("application/vnd.android.package-archive")
                    setDestinationInExternalFilesDir(
                        this@MainActivity,
                        Environment.DIRECTORY_DOWNLOADS,
                        fileName,
                    )
                }
                downloadId = manager.enqueue(request)
                val apk = waitForApkDownload(
                    manager,
                    downloadId,
                    downloadDirectory,
                    fileName,
                    expectedSize,
                    expectedSha256!!,
                )
                runOnUiThread {
                    if (pendingApkDownloadResult === result) pendingApkDownloadResult = null
                    result.success(apk.canonicalPath)
                }
            } catch (error: Exception) {
                if (downloadId > 0 && manager != null) manager.remove(downloadId)
                runOnUiThread {
                    if (pendingApkDownloadResult === result) pendingApkDownloadResult = null
                    result.error("UPDATE_DOWNLOAD_FAILED", error.message, null)
                }
            }
        }.start()
    }

    private fun waitForApkDownload(
        manager: DownloadManager,
        downloadId: Long,
        downloadDirectory: File,
        fileName: String,
        expectedSize: Long,
        expectedSha256: String,
    ): File {
        val deadline = System.currentTimeMillis() + 30L * 60L * 1000L
        while (System.currentTimeMillis() < deadline) {
            val query = manager.query(DownloadManager.Query().setFilterById(downloadId))
                ?: throw IllegalStateException("Unable to query the APK download.")
            query.use { cursor ->
                if (!cursor.moveToFirst()) throw IllegalStateException("APK download disappeared.")
                when (cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))) {
                    DownloadManager.STATUS_SUCCESSFUL -> {
                        val localUri = cursor.getString(
                            cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_LOCAL_URI),
                        )
                        val downloaded = File(Uri.parse(localUri).path ?: "").canonicalFile
                        val expectedDirectory = downloadDirectory.canonicalFile
                        if (downloaded.parentFile != expectedDirectory ||
                            downloaded.name != fileName ||
                            !downloaded.isFile ||
                            downloaded.length() != expectedSize ||
                            sha256File(downloaded) != expectedSha256) {
                            throw IllegalStateException("Downloaded APK failed size or SHA-256 verification.")
                        }
                        return downloaded
                    }
                    DownloadManager.STATUS_FAILED -> {
                        val reason = cursor.getInt(
                            cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON),
                        )
                        throw IllegalStateException("APK download failed (reason $reason).")
                    }
                }
            }
            Thread.sleep(1000)
        }
        throw IllegalStateException("APK download timed out.")
    }

    private fun handleInstallApk(
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result,
    ) {
        try {
            val rawPath = call.argument<String>("filePath")
            val expectedSize = call.argument<Number>("sizeBytes")?.toLong()
            val expectedSha256 = call.argument<String>("sha256")?.lowercase()
            val expectedPackageName = call.argument<String>("packageName")
            val expectedVersionCode = call.argument<Number>("versionCode")?.toLong()
            val downloadDirectory = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
                ?: throw IllegalStateException("App download storage is unavailable.")
            val apk = File(rawPath.orEmpty()).canonicalFile
            if (apk.parentFile != downloadDirectory.canonicalFile ||
                !apk.name.matches(Regex("parabeacon-[1-9][0-9]*\\.apk")) ||
                !apk.isFile ||
                expectedSize == null ||
                apk.length() != expectedSize ||
                !expectedSha256.orEmpty().matches(Regex("[a-f0-9]{64}")) ||
                sha256File(apk) != expectedSha256 ||
                expectedPackageName != packageName ||
                expectedVersionCode == null) {
                result.error("INVALID_UPDATE_FILE", "The downloaded APK failed verification.", null)
                return
            }
            @Suppress("DEPRECATION")
            val archivedPackage = packageManager.getPackageArchiveInfo(apk.path, 0)
            @Suppress("DEPRECATION")
            val archivedVersionCode = archivedPackage?.versionCode?.toLong()
            if (archivedPackage?.packageName != expectedPackageName ||
                archivedVersionCode != expectedVersionCode) {
                result.error("INVALID_UPDATE_PACKAGE", "The APK package or version does not match release metadata.", null)
                return
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !packageManager.canRequestPackageInstalls()) {
                startActivity(
                    Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                        data = Uri.parse("package:$packageName")
                    },
                )
                result.success("permission_required")
                return
            }
            val contentUri = FileProvider.getUriForFile(
                this,
                "$packageName.appupdates",
                apk,
            )
            val installIntent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(contentUri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(installIntent)
            result.success("launched")
        } catch (error: Exception) {
            result.error("UPDATE_INSTALL_FAILED", error.message, null)
        }
    }

    private fun sha256File(file: File): String {
        val digest = java.security.MessageDigest.getInstance("SHA-256")
        file.inputStream().buffered().use { input ->
            val buffer = ByteArray(64 * 1024)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                digest.update(buffer, 0, count)
            }
        }
        return digest.digest().joinToString("") { byte -> "%02x".format(byte) }
    }

    /// Minimal device descriptor used by the voice-announcement speaker to work
    /// around vendor-specific audio routing. Huawei / HarmonyOS devices mute
    /// text-to-speech tagged with the navigation-guidance audio usage unless a
    /// real navigation session is active, so the speaker needs to recognise
    /// them and fall back to the engine-default (media) usage.
    private fun getDeviceInfo(): Map<String, Any> {
        return mapOf(
            "manufacturer" to (Build.MANUFACTURER ?: ""),
            "brand" to (Build.BRAND ?: ""),
            "isHarmonyOS" to isHarmonyOS(),
        )
    }

    /// Detects Android-based HarmonyOS via Huawei's documented BuildEx API,
    /// which reports the OS brand as "harmony". Any failure (non-Huawei ROMs
    /// lack the class) is treated as "not HarmonyOS".
    private fun isHarmonyOS(): Boolean {
        return try {
            val clazz = Class.forName("com.huawei.system.BuildEx")
            val brand = clazz.getMethod("getOsBrand").invoke(clazz) as? String
            "harmony".equals(brand, ignoreCase = true)
        } catch (_: Throwable) {
            false
        }
    }

    private fun getFlightPermissionStatuses(): Map<String, Boolean> {
        val backgroundLocationGranted =
            Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
                checkSelfPermission(android.Manifest.permission.ACCESS_BACKGROUND_LOCATION) ==
                android.content.pm.PackageManager.PERMISSION_GRANTED
        // Android's power whitelist is the system signal for unrestricted
        // battery use; default/optimized status does not count as unrestricted.
        val batteryUnrestricted =
            Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
                (getSystemService(POWER_SERVICE) as PowerManager)
                    .isIgnoringBatteryOptimizations(packageName)
        return mapOf(
            "backgroundLocationGranted" to backgroundLocationGranted,
            "batteryUnrestricted" to batteryUnrestricted,
        )
    }

    private fun openBackgroundLocationSettings(result: MethodChannel.Result) {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.fromParts("package", packageName, null)
        }
        launchPermissionSettings(intent, result)
    }

    private fun openBatteryOptimizationSettings(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            result.success(false)
            return
        }
        if (pendingBatteryPermissionSettingsResult != null) {
            result.error(
                "BATTERY_SETTINGS_IN_PROGRESS",
                "Battery settings are already open.",
                null,
            )
            return
        }

        val appIntent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
            data = Uri.parse("package:$packageName")
        }
        pendingBatteryPermissionSettingsResult = result
        try {
            startActivityForResult(appIntent, BATTERY_PERMISSION_SETTINGS_REQUEST)
        } catch (_: Exception) {
            try {
                startActivityForResult(
                    Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS),
                    BATTERY_PERMISSION_SETTINGS_REQUEST,
                )
            } catch (_: Exception) {
                pendingBatteryPermissionSettingsResult = null
                result.success(false)
            }
        }
    }

    private fun launchPermissionSettings(
        intent: Intent,
        result: MethodChannel.Result,
        fallback: (() -> Intent)? = null,
    ) {
        try {
            startActivity(intent)
            result.success(true)
        } catch (_: Exception) {
            if (fallback == null) {
                result.success(false)
                return
            }
            try {
                startActivity(fallback())
                result.success(true)
            } catch (_: Exception) {
                result.success(false)
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

        handleSaveFile(fileName, FLIGHT_BUNDLE_MIME_TYPE, bytes, result)
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
        if (requestCode == BATTERY_PERMISSION_SETTINGS_REQUEST) {
            val result = pendingBatteryPermissionSettingsResult
            pendingBatteryPermissionSettingsResult = null
            result?.success(true)
            return
        }
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
