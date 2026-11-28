package com.beacon.parabeacon

import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.PowerManager
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.FileProvider
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Callable
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicLong
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val FLIGHT_LIBRARY_CHANNEL = "com.beacon.parabeacon/flight_library"
        private const val FLIGHT_PERMISSIONS_CHANNEL = "com.beacon.parabeacon/flight_permissions"
        private const val DEVICE_INFO_CHANNEL = "com.beacon.parabeacon/device_info"
        private const val APP_UPDATE_CHANNEL = "com.beacon.parabeacon/app_update"
        private const val CHAT_NOTIFICATIONS_CHANNEL = "com.beacon.parabeacon/chat_notifications"
        private const val CHAT_NOTIFICATION_ID = "pilot-chat-message"
        private const val CHAT_NOTIFICATION_CHANNEL_ID = "pilot_chat_messages_v2"
        private const val UPDATE_NOTIFICATION_CHANNEL_ID = "app_updates"
        private const val UPDATE_NOTIFICATION_ID = 7301
        private const val APP_UPDATE_PREFERENCES = "app_update_pending"
        private const val MAX_APK_SIZE_BYTES = 512L * 1024L * 1024L
        private const val APK_DOWNLOAD_PARTS = 4
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
    private var appUpdateChannel: MethodChannel? = null

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
        ).also { channel ->
            appUpdateChannel = channel
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "isWifiConnected" -> result.success(isWifiConnected())
                    "isMobileDataConnected" -> result.success(isMobileDataConnected())
                    "isAirplaneModeEnabled" -> result.success(isAirplaneModeEnabled())
                    "getPendingApk" -> result.success(getPendingApk())
                    "downloadApk" -> handleApkDownload(call, result)
                    "installApk" -> handleInstallApk(call, result)
                    "showUpdateReadyNotification" -> handleUpdateReadyNotification(call, result)
                    else -> result.notImplemented()
                }
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHAT_NOTIFICATIONS_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "showIncomingMessage" -> handleIncomingChatNotification(call, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun handleIncomingChatNotification(
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result,
    ) {
        val messageId = call.argument<String>("id")?.takeIf { it.isNotBlank() }
        val title = call.argument<String>("title")?.takeIf { it.isNotBlank() }
        val sourceLabel = call.argument<String>("sourceLabel")?.takeIf { it.isNotBlank() }
        val body = call.argument<String>("body")?.takeIf { it.isNotBlank() }
        val channelName = call.argument<String>("channelName")?.takeIf { it.isNotBlank() }
        val channelDescription = call.argument<String>("channelDescription")
        val senderPilotNumber = call.argument<Int>("senderPilotNumber")
        if (messageId == null || title == null || sourceLabel == null || body == null ||
            channelName == null || channelDescription == null ||
            senderPilotNumber == null || senderPilotNumber !in 100000..999999) {
            result.error("INVALID_CHAT_NOTIFICATION", "Notification data is invalid.", null)
            return
        }

        try {
            val notificationManager = NotificationManagerCompat.from(this)
            if (!notificationManager.areNotificationsEnabled()) {
                result.success(false)
                return
            }
            createChatNotificationChannel(channelName, channelDescription)
            val intent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("pilot_chat_sender", senderPilotNumber)
            }
            val pendingIntent = PendingIntent.getActivity(
                this,
                messageId.hashCode(),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val notification = NotificationCompat.Builder(this, CHAT_NOTIFICATION_CHANNEL_ID)
                .setSmallIcon(applicationInfo.icon)
                .setContentTitle("$sourceLabel · $title")
                .setContentText(body)
                .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                .setCategory(NotificationCompat.CATEGORY_MESSAGE)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setDefaults(NotificationCompat.DEFAULT_SOUND or NotificationCompat.DEFAULT_VIBRATE)
                .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
                .setAutoCancel(true)
                .setOnlyAlertOnce(true)
                .setContentIntent(pendingIntent)
                .build()
            notificationManager.notify(CHAT_NOTIFICATION_ID, messageId.hashCode(), notification)
            result.success(true)
        } catch (_: SecurityException) {
            result.success(false)
        } catch (error: Exception) {
            result.error("CHAT_NOTIFICATION_FAILED", error.message, null)
        }
    }

    private fun createChatNotificationChannel(name: String, description: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (notificationManager.getNotificationChannel(CHAT_NOTIFICATION_CHANNEL_ID) != null) return
        val audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val channel = NotificationChannel(
            CHAT_NOTIFICATION_CHANNEL_ID,
            name,
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            this.description = description
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 250, 150, 250)
            setSound(android.provider.Settings.System.DEFAULT_NOTIFICATION_URI, audioAttributes)
        }
        notificationManager.createNotificationChannel(channel)
    }

    private fun isWifiConnected(): Boolean {
        val manager = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            ?: return false
        val network = manager.activeNetwork ?: return false
        val capabilities = manager.getNetworkCapabilities(network) ?: return false
        return capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)
    }

    private fun isMobileDataConnected(): Boolean {
        val manager = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            ?: return false
        val network = manager.activeNetwork ?: return false
        val capabilities = manager.getNetworkCapabilities(network) ?: return false
        return capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)
    }

    private fun isAirplaneModeEnabled(): Boolean =
        Settings.Global.getInt(
            contentResolver,
            Settings.Global.AIRPLANE_MODE_ON,
            0,
        ) != 0

    private fun getPendingApk(): Map<String, Any?>? {
        val preferences = getSharedPreferences(APP_UPDATE_PREFERENCES, Context.MODE_PRIVATE)
        val versionName = preferences.getString("versionName", null) ?: return null
        val versionCode = preferences.getInt("versionCode", 0)
        val expectedSize = preferences.getLong("sizeBytes", 0L)
        val sha256 = preferences.getString("sha256", null) ?: return null
        val downloadUrl = preferences.getString("downloadUrl", null) ?: return null
        val path = preferences.getString("filePath", null) ?: return null
        val expectedPackage = preferences.getString("packageName", null) ?: return null
        val directory = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)?.canonicalFile ?: return null
        val apk = runCatching { File(path).canonicalFile }.getOrNull() ?: return null
        if (versionCode < 1 || versionName.isBlank() || versionName.length > 64 ||
            expectedSize !in 1..MAX_APK_SIZE_BYTES ||
            expectedPackage != packageName || !sha256.matches(Regex("[a-f0-9]{64}")) ||
            apk.parentFile != directory || apk.name != "parabeacon-$versionCode.apk" ||
            !apk.isFile || apk.length() != expectedSize) {
            preferences.edit().clear().apply()
            return null
        }
        @Suppress("DEPRECATION")
        val installedVersion = packageManager.getPackageInfo(packageName, 0).versionCode
        if (installedVersion >= versionCode) {
            preferences.edit().clear().apply()
            return null
        }
        return mapOf(
            "version_name" to versionName,
            "version_code" to versionCode,
            "package_name" to expectedPackage,
            "size_bytes" to expectedSize,
            "sha256" to sha256,
            "download_url" to downloadUrl,
            "file_path" to apk.path,
        )
    }

    private fun handleUpdateReadyNotification(
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result,
    ) {
        val title = call.argument<String>("title")?.takeIf { it.isNotBlank() }
        val body = call.argument<String>("body")?.takeIf { it.isNotBlank() }
        if (title == null || body == null) {
            result.error("INVALID_UPDATE_NOTIFICATION", "Notification text is missing.", null)
            return
        }
        try {
            val manager = NotificationManagerCompat.from(this)
            if (!manager.areNotificationsEnabled()) {
                result.success(false)
                return
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    UPDATE_NOTIFICATION_CHANNEL_ID,
                    title,
                    NotificationManager.IMPORTANCE_DEFAULT,
                )
                getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
            }
            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                ?: Intent(this, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                this,
                UPDATE_NOTIFICATION_ID,
                launchIntent.apply {
                    flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val notification = NotificationCompat.Builder(this, UPDATE_NOTIFICATION_CHANNEL_ID)
                .setSmallIcon(applicationInfo.icon)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                .setContentIntent(pendingIntent)
                .setAutoCancel(true)
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                .build()
            manager.notify(UPDATE_NOTIFICATION_ID, notification)
            result.success(true)
        } catch (error: SecurityException) {
            result.success(false)
        } catch (error: Exception) {
            result.error("UPDATE_NOTIFICATION_FAILED", error.message, null)
        }
    }

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
        val versionName = call.argument<String>("versionName")
        val versionCode = call.argument<Number>("versionCode")?.toInt()
        val expectedPackage = call.argument<String>("packageName")
        val allowMobileData = call.argument<Boolean>("allowMobileData") == true
        val rawServerOrigin = call.argument<String>("serverOrigin")
        val uri = rawUrl?.let { runCatching { Uri.parse(it) }.getOrNull() }
        val serverOrigin = rawServerOrigin?.let { runCatching { Uri.parse(it) }.getOrNull() }
        fun originPort(value: Uri): Int? {
            val defaultPort = when (value.scheme) {
                "http" -> 80
                "https" -> 443
                else -> return null
            }
            return when {
                value.port == -1 -> defaultPort
                value.port in 1..65535 -> value.port
                else -> null
            }
        }
        if (uri == null ||
            serverOrigin == null ||
            (serverOrigin.scheme != "http" && serverOrigin.scheme != "https") ||
            serverOrigin.host.isNullOrEmpty() ||
            !serverOrigin.userInfo.isNullOrEmpty() ||
            (serverOrigin.path.orEmpty().isNotEmpty() && serverOrigin.path != "/") ||
            serverOrigin.query != null ||
            serverOrigin.fragment != null ||
            originPort(serverOrigin) == null ||
            uri.scheme != serverOrigin.scheme ||
            uri.host?.equals(serverOrigin.host, ignoreCase = true) != true ||
            originPort(uri) != originPort(serverOrigin) ||
            !uri.userInfo.isNullOrEmpty() ||
            uri.query != null ||
            uri.fragment != null ||
            versionCode == null || versionCode < 1 || versionCode > 2100000000 ||
            versionName.isNullOrBlank() || versionName.length > 64 ||
            expectedPackage != packageName ||
            uri.path != "/api/v1/app/releases/$versionCode/download" ||
            fileName != "parabeacon-$versionCode.apk" ||
            expectedSize == null || expectedSize !in 1..MAX_APK_SIZE_BYTES ||
            !expectedSha256.orEmpty().matches(Regex("[a-f0-9]{64}"))) {
            result.error("INVALID_UPDATE", "The update metadata is invalid.", null)
            return
        }
        if (!isWifiConnected() && !(allowMobileData && isMobileDataConnected())) {
            result.error(
                "WIFI_REQUIRED",
                "Wi-Fi or explicitly approved mobile data is required to download updates.",
                null,
            )
            return
        }
        val downloadDirectory = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
        if (downloadDirectory == null) {
            result.error("UPDATE_STORAGE_UNAVAILABLE", "App download storage is unavailable.", null)
            return
        }
        pendingApkDownloadResult = result
        Thread {
            try {
                val apk = downloadApkWithRanges(
                    uri,
                    downloadDirectory,
                    fileName!!,
                    expectedSize,
                    expectedSha256!!,
                    allowMobileData,
                )
                getSharedPreferences(APP_UPDATE_PREFERENCES, Context.MODE_PRIVATE).edit()
                    .putString("versionName", versionName!!)
                    .putInt("versionCode", versionCode!!)
                    .putString("packageName", expectedPackage!!)
                    .putLong("sizeBytes", expectedSize)
                    .putString("sha256", expectedSha256)
                    .putString("downloadUrl", uri.toString())
                    .putString("filePath", apk.canonicalPath)
                    .apply()
                runOnUiThread {
                    if (pendingApkDownloadResult === result) pendingApkDownloadResult = null
                    result.success(apk.canonicalPath)
                }
            } catch (error: Exception) {
                runOnUiThread {
                    if (pendingApkDownloadResult === result) pendingApkDownloadResult = null
                    if (error is WifiRequiredException) {
                        result.error("WIFI_REQUIRED", error.message, null)
                    } else {
                        result.error("UPDATE_DOWNLOAD_FAILED", error.message, null)
                    }
                }
            }
        }.start()
    }

    private class WifiRequiredException : IOException("An approved network is required to download updates.")

    private fun isApprovedUpdateNetwork(allowMobileData: Boolean): Boolean =
        isWifiConnected() || (allowMobileData && isMobileDataConnected())

    private fun downloadApkWithRanges(
        uri: Uri,
        directory: File,
        fileName: String,
        expectedSize: Long,
        expectedSha256: String,
        allowMobileData: Boolean,
    ): File {
        val destination = File(directory, fileName)
        if (destination.isFile && destination.length() == expectedSize &&
            sha256File(destination) == expectedSha256) {
            publishApkProgress(expectedSize, expectedSize)
            return destination
        }
        val temporary = File(directory, "$fileName.download")
        val partCount = minOf(APK_DOWNLOAD_PARTS.toLong(), expectedSize).toInt()
        val partSize = (expectedSize + partCount - 1) / partCount
        val partFiles = (0 until partCount).map { File(directory, "$fileName.part-$it") }
        val partRanges = partFiles.mapIndexed { index, file ->
            val start = index * partSize
            val end = minOf(expectedSize - 1, start + partSize - 1)
            val length = end - start + 1
            if (file.exists() && file.length() > length && !file.delete()) {
                throw IOException("Unable to reset an invalid partial APK download.")
            }
            Triple(file, start, end)
        }
        val alreadyDownloaded = partFiles.sumOf { it.length() }
        val downloadedBytes = AtomicLong(alreadyDownloaded)
        publishApkProgress(alreadyDownloaded, expectedSize)
        val executor = Executors.newFixedThreadPool(partCount)
        val futures = try {
            partRanges.map { (part, start, end) ->
                executor.submit(Callable {
                    downloadApkPart(
                        uri,
                        part,
                        start,
                        end,
                        expectedSize,
                        downloadedBytes,
                        allowMobileData,
                    )
                })
            }
        } catch (error: Exception) {
            executor.shutdownNow()
            throw error
        }
        try {
            futures.forEach { future ->
                try {
                    future.get()
                } catch (error: java.util.concurrent.ExecutionException) {
                    futures.forEach { it.cancel(true) }
                    throw (error.cause ?: error)
                }
            }
        } finally {
            executor.shutdownNow()
        }
        temporary.outputStream().buffered().use { output ->
            partFiles.forEach { part -> part.inputStream().buffered().use { it.copyTo(output) } }
        }
        if (temporary.length() != expectedSize || sha256File(temporary) != expectedSha256) {
            temporary.delete()
            partFiles.forEach { it.delete() }
            throw IOException("Downloaded APK failed size or SHA-256 verification.")
        }
        if (destination.exists() && !destination.delete()) {
            throw IOException("Unable to replace the previous APK download.")
        }
        if (!temporary.renameTo(destination)) {
            throw IOException("Unable to finalize the downloaded APK.")
        }
        partFiles.forEach { it.delete() }
        publishApkProgress(expectedSize, expectedSize)
        return destination
    }

    private fun downloadApkPart(
        uri: Uri,
        partFile: File,
        partStart: Long,
        partEnd: Long,
        totalSize: Long,
        downloadedBytes: AtomicLong,
        allowMobileData: Boolean,
    ) {
        val partLength = partEnd - partStart + 1
        var failures = 0
        while (partFile.length() < partLength) {
            if (!isApprovedUpdateNetwork(allowMobileData)) throw WifiRequiredException()
            val rangeStart = partStart + partFile.length()
            var connection: HttpURLConnection? = null
            try {
                connection = URL(uri.toString()).openConnection() as HttpURLConnection
                connection.connectTimeout = 20_000
                connection.readTimeout = 30_000
                connection.instanceFollowRedirects = false
                connection.setRequestProperty("Accept-Encoding", "identity")
                connection.setRequestProperty("Range", "bytes=$rangeStart-$partEnd")
                if (connection.responseCode != HttpURLConnection.HTTP_PARTIAL ||
                    connection.getHeaderField("Content-Range") != "bytes $rangeStart-$partEnd/$totalSize") {
                    throw IOException("The APK server did not honor the requested byte range.")
                }
                connection.inputStream.use { input ->
                    FileOutputStream(partFile, true).use { output ->
                        val buffer = ByteArray(64 * 1024)
                        while (true) {
                            if (!isApprovedUpdateNetwork(allowMobileData)) {
                                throw WifiRequiredException()
                            }
                            val count = input.read(buffer)
                            if (count < 0) break
                            if (partFile.length() + count > partLength) {
                                throw IOException("The APK server returned too many bytes for a range.")
                            }
                            output.write(buffer, 0, count)
                            downloadedBytes.addAndGet(count.toLong())
                            publishApkProgress(downloadedBytes.get(), totalSize)
                        }
                    }
                }
                if (partFile.length() < partLength) {
                    throw IOException("The APK server ended a byte range early.")
                }
                failures = 0
            } catch (error: WifiRequiredException) {
                throw error
            } catch (error: Exception) {
                if (Thread.currentThread().isInterrupted) throw IOException("APK download was interrupted.", error)
                failures++
                if (failures >= 5) throw error
                Thread.sleep(1000L * failures)
            } finally {
                connection?.disconnect()
            }
        }
    }

    private fun publishApkProgress(downloaded: Long, total: Long) {
        runOnUiThread {
            appUpdateChannel?.invokeMethod(
                "downloadProgress",
                mapOf("bytesDownloaded" to downloaded, "totalBytes" to total),
            )
        }
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
