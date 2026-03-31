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

Keys are **not** committed. Set them as follows for release and CI.

- **Dart (map/geocoding):** pass at build time:

  ```bash
  flutter build apk --release --dart-define=GOOGLE_MAPS_API_KEY=your_google_maps_key
  flutter build appbundle --release --dart-define=GOOGLE_MAPS_API_KEY=your_google_maps_key
  ```

- **Android:** create or edit `android/local.properties` (do not commit; already in `.gitignore`):

  ```properties
  sdk.dir=/path/to/your/android/sdk
  MAPS_API_KEY=your_google_maps_key
  ```

  The app reads `MAPS_API_KEY` via `build.gradle` and injects it into the manifest. If missing, the placeholder `YOUR_GOOGLE_MAPS_API_KEY` is used and Maps will not work until you set it.

- **iOS:** the repo contains the placeholder `YOUR_GOOGLE_MAPS_API_KEY` in `ios/Runner/Info.plist` (no real key committed).

  - **Local run:** replace it manually with your key, or inject before building (see below).
  - **CI / release:** inject the key so it is never committed. Example (run from repo root, with `GMS_API_KEY` set in CI secrets):

    ```bash
    plutil -replace GMSApiKey -string "$GMS_API_KEY" ios/Runner/Info.plist
    flutter build ios --release
    ```

  - `AppDelegate.swift` reads the key from `Info.plist` at runtime; do not hardcode the key there.

## Payment redirect URL

The payment gateway redirect URL defaults to `https://eclcommerce.ernestchemists.com.gh/complete`. For test environments, override with:

```bash
--dart-define=PAYMENT_REDIRECT_URL=https://your-test-host/complete
```

## Security hardening (vulnerability testing)

- **SSL:** The app uses default certificate validation; no custom `badCertificateCallback` in production.
- **iOS ATS:** `NSAllowsArbitraryLoads` and `NSAllowsArbitraryLoadsInWebContent` are `false`; no arbitrary HTTP loads.
- **Auth tokens:** Stored in secure storage (Keychain/EncryptedSharedPreferences); SharedPreferences is used only when secure storage fails (e.g. iOS simulator keychain issues).
- **ExpressPay:** Debug  mode is ignored in release builds (`kDebugMode`); payment tokens are not logged in release.
- **Logging:** API keys and tokens are not printed in logs.
- **API keys in repo:** No real Google Maps or Gemini keys in version control; use dart-define / local.properties / CI injection.

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
| Google Maps (Dart) | `--dart-define=GOOGLE_MAPS_API_KEY=...` for release. |
| Google Maps (Android) | `android/local.properties` → `MAPS_API_KEY=...`; do not commit. |
| Google Maps (iOS) | Replace `YOUR_GOOGLE_MAPS_API_KEY` in `Info.plist` at build time; do not commit. |
| Payment redirect  | Default production URL; override with `--dart-define=PAYMENT_REDIRECT_URL=...` for test. |
