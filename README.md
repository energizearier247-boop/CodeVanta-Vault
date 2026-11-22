# CodeVanta Vault

A Flutter Android application starter for a private, offline-first file vault.

## Included

- Secret-code setup and unlock screen
- AES-256-GCM encryption for imported files and the encrypted file catalogue
- PBKDF2-HMAC-SHA256 key derivation
- Private application storage (no cloud backend)
- ZIP/archive, music and video library categories
- Offline audio and video playback
- Dark and light appearance setting
- Android launcher icon configuration
- GitHub Actions Android APK workflow

## Important security notes

1. The secret code is never stored as plain text. A key is derived from it with PBKDF2 and a random salt.
2. The derived key is kept in memory only while the vault is unlocked.
3. File contents and the catalogue are encrypted using AES-256-GCM with a fresh random nonce for each encryption.
4. There is no master password or online recovery service. If the code is lost, the vault cannot be recovered.
5. Unlocked audio/video playback requires a temporary decrypted copy in the app cache. The app attempts to delete these temporary files when it locks. Android may retain cache files until cleanup; do not treat cache deletion as a forensic secure erase.
6. This is a starter implementation. Before storing irreplaceable files, test it thoroughly and keep a separate encrypted backup. Large-file import currently reads the selected file into memory and may be unsuitable for very large videos on low-memory phones. Streaming/chunked encryption should be added before production use.

## Create the Android project files

This ZIP contains the Flutter/Dart source and project configuration. It does not contain generated Android Gradle wrapper files or a compiled APK.

On a computer with Flutter installed:

```bash
flutter create --platforms=android --org com.codevanta codevanta_vault
```

Copy the contents of this ZIP into the generated `codevanta_vault` folder, replacing matching files, then run:

```bash
flutter pub get
dart run flutter_launcher_icons
flutter run
```

The GitHub Actions workflow included in `.github/workflows` creates the Android platform folder in CI if it is not present and builds a release APK.

## Android permissions and backups

The app imports files through Android's system file picker. It does not request broad storage access. Vault data is stored under the app's private documents directory. Android cloud backup is disabled in the included manifest template; confirm this remains disabled in the generated Android manifest.

## Suggested production hardening

- Add chunked authenticated encryption for large files.
- Add an explicit encrypted export/backup and restore flow.
- Add rate limiting and increasing delays after repeated incorrect codes.
- Add secure memory handling where practical.
- Conduct independent security review and test on real devices.
