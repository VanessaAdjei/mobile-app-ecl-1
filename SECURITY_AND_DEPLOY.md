# Security and deployment

This doc describes how to handle **secrets** and **release builds** so they are not committed and work in CI/production.

## Android release signing

Release builds must be signed with a non-debug keystore.

1. **Create a keystore** (once per app / team):

   ```bash
   keytool -genkey -v -keystore android/upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

   Store the file somewhere safe (e.g. `android/upload-keystore.jks`) and **do not commit it**. Add `android/upload-keystore.jks` to `.gitignore` if you keep it in the repo tree.

2. **Create `android/key.properties`** (do not commit; already in `.gitignore`):

   ```properties
   storePassword=your_store_password
   keyPassword=your_key_password
   keyAlias=upload
   storeFile=../upload-keystore.jks
   ```

   `storeFile` is relative to `android/app`. So `../upload-keystore.jks` points to `android/upload-keystore.jks`.

3. **Build release**:

   ```bash
   flutter build apk --release
   # or
   flutter build appbundle --release
   ```

   If `key.properties` is missing, the release build falls back to the debug signing config so local/CI builds still succeed.

## API keys

### Gemini (Ernest AI)

The Gemini API key is read at compile time so it is not hardcoded in source.

- **Release / CI:** pass the key via `--dart-define`:

  ```bash
  flutter build apk --release --dart-define=GEMINI_API_KEY=your_gemini_api_key
  flutter build appbundle --release --dart-define=GEMINI_API_KEY=your_gemini_api_key
  ```

- **Local dev:** either use the same `--dart-define` when running, or set the key in the in-app AI settings screen if that flow is implemented to persist it.

- If `GEMINI_API_KEY` is not set, the AI feature will not work until a key is provided (e.g. via dart-define or in-app).

### Google Maps

- **Android:** the Maps API key is in `AndroidManifest.xml`. Prefer loading it from `local.properties` (e.g. `MAPS_API_KEY=...`) and injecting it in `build.gradle` so the key is not committed. Add `local.properties` to `.gitignore` if you put secrets there.
- **iOS:** the key is in `AppDelegate.swift` / xcconfig. Prefer a non-committed xcconfig or build-phase injection so the key is not in source control.

The placeholder in `lib/config/api_config.dart` (`googleMapsApiKey`) is used for web/other; avoid committing a production key there.

## ProGuard (Android release)

Release builds use R8/ProGuard with `android/app/proguard-rules.pro`. Keep rules are in place for:

- Flutter engine and plugins  
- OkHttp / Volley  
- Kotlin  
- ExpressPay SDK  

If you see runtime crashes or missing classes in release, add keep rules for the affected packages and test again.

## Summary

| Item              | Where / how |
|-------------------|-------------|
| Android keystore  | Create `android/upload-keystore.jks`, do not commit. |
| Signing config    | `android/key.properties` (from `key.properties.example`), do not commit. |
| Gemini API key    | `--dart-define=GEMINI_API_KEY=...` for release; optional in-app entry. |
| Google Maps keys  | Prefer `local.properties` (Android) and xcconfig/build args (iOS); do not commit. |
