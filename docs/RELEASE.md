# KalaSetu Android Release Guide (docs/RELEASE.md)

This document explains how to build, sign, and release the KalaSetu Android APK for GitHub Releases.

---

## 1. Application Identifiers

- **Application ID / Package Name**: `com.kalasetu.app`
- **Application Label**: `KalaSetu`
- **Launcher Icon**: `@mipmap/launcher_icon` (Linen & Olive handcrafted potter icon)
- **Minimum SDK**: 21 (Android 5.0 Lollipop)
- **Target SDK**: 34 (Android 14)
- **Network Security**: HTTPS-only (`usesCleartextTraffic="false"` in release builds)

---

## 2. Release Keystore & Backup Instructions

### 2.1 Generating a Keystore
The keystore `upload-keystore.jks` was generated using Java Keytool:
```bash
keytool -genkey -v -keystore frontend/android/app/upload-keystore.jks \
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 \
  -alias kalasetu \
  -dname "CN=KalaSetu, OU=Mobile, O=KalaSetu, L=NewDelhi, ST=Delhi, C=IN"
```

### 2.2 Critical Keystore Backup Policy
> [!CAUTION]
> **NEVER LOSE YOUR KEYSTORE OR COMMIT IT TO GIT.**
> If you lose `upload-keystore.jks` or its passwords, you will permanently lose the ability to release app updates for existing users on Android.

1. **Backup Storage**:
   - Store a copy of `upload-keystore.jks` in a secure encrypted password manager (1Password, Bitwarden) or team secret vault.
   - Store the passwords alongside the file:
     - **Store Password**: Stored in team password manager
     - **Key Password**: Stored in team password manager
     - **Key Alias**: `kalasetu`
2. **Git Safeguard**:
   - Both `*.jks`, `*.keystore`, and `android/key.properties` are strictly listed in `.gitignore`.
   - Never commit keystores or `key.properties` to source control.

---

## 3. Configuring `android/key.properties`

Create `frontend/android/key.properties` (never committed):
```properties
storePassword=your_keystore_password
keyPassword=your_key_password
keyAlias=kalasetu
storeFile=upload-keystore.jks
```

`frontend/android/app/build.gradle.kts` automatically detects this file and configures release signing.

---

## 4. Building the Signed Release APK

Run the automated build script:
```powershell
.\scripts\build_release.ps1 -ApiBaseUrl "https://kalasetu-backend.onrender.com/api/v1"
```

Or manually:
```bash
cd frontend
flutter pub get
flutter build apk --release --no-tree-shake-icons \
  --dart-define=API_BASE_URL=https://kalasetu-backend.onrender.com/api/v1
```

The compiled and signed APK is output to:
```
frontend/build/app/outputs/flutter-apk/app-release.apk
```
And copied to:
```
KalaSetu-release.apk (in project root)
```

---

## 5. Publishing to GitHub Releases

1. In your GitHub repository, navigate to **Releases** > **Draft a new release**.
2. **Tag version**: e.g., `v1.0.0`.
3. **Release title**: `KalaSetu v1.0.0 - Production Release`.
4. Upload `KalaSetu-release.apk`.
5. Include the SHA256 checksum from the build script output:
   ```
   SHA256: <checksum>
   ```
6. Click **Publish release**.
