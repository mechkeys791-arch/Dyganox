# Checklist: After Changing Package Name to `com.dyganox.app`

Your app now uses **`com.dyganox.app`** (required for Google Play). Update these **outside the app** so Maps, Google Sign-In, and Firebase keep working.

---

## 1. Google Cloud Console – Maps API

1. Go to [Google Cloud Console](https://console.cloud.google.com/) → your project.
2. **APIs & Services** → **Credentials** → open the **API key** used for Maps (the one in `AndroidManifest.xml`: `com.google.android.geo.API_KEY`).
3. Under **Application restrictions**:
   - Choose **Android apps**.
   - Add an entry:
     - **Package name:** `com.dyganox.app`
     - **SHA-1:** from your **release** keystore (run `cd android && ./gradlew signingReport` and copy SHA-1 for **Variant: release**).
4. Save.

If you don’t add this, Maps may fail with a restriction error on the release build.

---

## 2. Google Cloud Console – Google Sign-In (Android OAuth client)

1. Go to **APIs & Services** → **Credentials**.
2. Create **or edit** the **Android** OAuth 2.0 client used by “Continue with Google”:
   - **Package name:** `com.dyganox.app`
   - **SHA-1 certificate fingerprint:** from your **release** keystore (same as in step 1: `./gradlew signingReport` → release variant).
3. Save.

You can keep an extra Android client for `com.example.dyganox` for old builds; the one that matters for the Play build is `com.dyganox.app` + release SHA-1.

**Note:** The **Web** OAuth client ID in `lib/services/api_config.dart` (`googleWebClientId`) does **not** use package name; no change needed there.

---

## 3. Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/) → your project (**dyganox-8371c**).
2. **Project settings** (gear) → **Your apps**.
3. **Add app** → **Android**:
   - **Android package name:** `com.dyganox.app`
   - Register the app.
4. Download the new **google-services.json** and replace `android/app/google-services.json` (or keep the current file if you already added the second client for `com.dyganox.app` in the JSON).

This keeps FCM and other Firebase features tied to the new package name.

---

## 4. What you don’t need to change

- **Flutter / Dart code:** No package name is hardcoded; `api_config.dart` only has base URL and Web client ID.
- **Backend:** No change for package name.
- **AndroidManifest.xml:** No change; it doesn’t contain the app package name.
- **Cognito:** Unchanged; it doesn’t use Android package name.

---

## 5. Quick reference

| Where              | What to set / use                          |
|--------------------|--------------------------------------------|
| Play Store         | Package name: `com.dyganox.app` (already in `build.gradle.kts`) |
| Google Cloud – Maps API key | Restrict to `com.dyganox.app` + release SHA-1 |
| Google Cloud – Android OAuth | Android client: `com.dyganox.app` + release SHA-1 |
| Firebase           | Add Android app `com.dyganox.app` (or keep updated `google-services.json`) |

**Get release SHA-1:**
```bash
cd android && ./gradlew signingReport
```
Use the **SHA-1** line under **Variant: release** (your upload keystore).
