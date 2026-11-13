# parabeacon

A cross-platform paraglider flight assistant with live vario audio, BLE sensors, mapping, and flight logging.

## Android APK updates

On Android startup, ParaBeacon checks the configured ParaBeacon Server for the latest release. A newer APK is downloaded only through Android DownloadManager with its network policy restricted to Wi-Fi, then checked against the server-provided size and SHA-256 digest. The app prompts before opening Android's installer; Android verifies the APK signing certificate and the user confirms installation. Allow ParaBeacon to install unknown apps in Android settings when prompted.

Release APKs must use a stable signing key across every version. Configure `PARABEACON_KEYSTORE_PATH`, `PARABEACON_KEYSTORE_PASSWORD`, `PARABEACON_KEY_ALIAS`, and `PARABEACON_KEY_PASSWORD` in the build environment; the Gradle build never falls back to the shared debug signing key for release. Without these values, release output is unsigned and cannot be installed as an update. Increase Flutter's Android build number (`versionCode`) for each published APK, upload it to ParaBeacon Server using the server's release admin API, and keep the keystore and server admin token private.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
