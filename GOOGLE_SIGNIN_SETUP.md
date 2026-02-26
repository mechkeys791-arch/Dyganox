# Google Sign-In setup (Android)

Follow these steps **once** so "Continue with Google" works in your Android app. The app and backend are already implemented; you only need to create one OAuth credential in Google Cloud.

---

## 1. Create a project in Google Cloud Console (if you don’t have one)

1. Go to [Google Cloud Console](https://console.cloud.google.com/).
2. Create a project or select an existing one.
3. No extra APIs need to be enabled for basic Google Sign-In.

---

## 2. Create one OAuth 2.0 client (Android)

1. In Google Cloud Console go to **APIs & Services** → **Credentials**.
2. Click **Create credentials** → **OAuth client ID**.
3. If asked, configure the **OAuth consent screen**:
   - User type: **External** (or Internal for testing only).
   - App name: e.g. **Dyganox**.
   - Support email: your email.
   - Save.

4. Create the Android client:
   - Application type: **Android**.
   - Name: e.g. **Dyganox Android**.
   - **Package name:** must match your app. Check `android/app/build.gradle.kts` → `applicationId` (e.g. `com.dyganox.app`).
   - **SHA-1 certificate fingerprint:** run in your project folder:
     ```bash
     cd android && ./gradlew signingReport
     ```
     Copy the **SHA-1** from the **debug** key (and add **release** SHA-1 later when you build for release). Paste it into the form.
   - Click **Create**.

That’s the only credential you need for Android. You do **not** paste the Android Client ID into your app — Google matches by package name and SHA-1.

### If you see "Could not get Google account info"

Android often needs a **Web** OAuth client so the app can receive an `id_token`. Do this:

1. In **Credentials** click **Create credentials** → **OAuth client ID**.
2. Application type: **Web application**. Name: e.g. **Dyganox Web**. Click **Create**.
3. Copy the **Web client ID** (e.g. `xxxxx.apps.googleusercontent.com`).
4. In your project open `lib/services/api_config.dart` and set:
   ```dart
   static const String? googleWebClientId = 'YOUR_WEB_CLIENT_ID_HERE';
   ```
   Replace with the copied value. Save and run again.

---

## 3. Run the app

- Run the app on a device or emulator. Tap **Continue with Google**, choose an account. You should be signed in and taken to the home screen.
- When you reopen the app, you stay logged in with that Gmail until you sign out.

---

## 4. How it’s different from email sign-in

| | Email / password + OTP | Google Sign-In |
|---|------------------------|----------------|
| **Flow** | Enter email + password → OTP → Cognito. | Tap “Continue with Google” → choose account → app gets id_token → backend verifies and finds/creates user by email. |
| **Password** | You have a password (Cognito). | No app password; Google handles security. |
| **Session** | Stored: `is_logged_in`, `user_email`, Cognito tokens. | Stored: `is_logged_in`, `user_email`, `user_name`, `auth_provider=google`. No Cognito tokens. |
| **Same account** | One Person per email. | Same: one Person per email. Same Gmail = same account; stays logged in on reopen. |

---

## 5. Troubleshooting (Android)

- **“Sign in failed” / “Invalid token” / 12501:**  
  - Package name in Google Cloud must exactly match `applicationId` in `android/app/build.gradle.kts` (e.g. `com.dyganox.app`).  
  - SHA-1 must match the key you’re signing with. Run `cd android && ./gradlew signingReport` and use that SHA-1 in the Android OAuth client.  
  - OAuth client type must be **Android**, not Web.
- **Backend returns error:**  
  - Backend must be able to reach `https://oauth2.googleapis.com/tokeninfo?id_token=...`.  
  - Redeploy backend so that `POST /api/auth/google` is available.

---

## Summary (Android only)

1. In Google Cloud: create **one** OAuth client of type **Android** with your app’s package name and SHA-1 (from `./gradlew signingReport`).
2. Run the app and use **Continue with Google**; the same Gmail stays logged in until sign-out.

When you add iOS later, you’ll create an iOS OAuth client and add the URL scheme; for now you only need the Android client.
