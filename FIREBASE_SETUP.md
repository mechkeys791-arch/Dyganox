# Firebase Cloud Messaging (FCM) Setup

This project uses Firebase Cloud Messaging so **mechanics receive push notifications** when a user requests them (with Accept/Reject in the notification).

## 1. Firebase Console (you said this is already done)

- Create a project at [Firebase Console](https://console.firebase.google.com/)
- Enable **Cloud Messaging** (FCM)
- Add an **Android app** (package: `com.example.dyganox`) and download `google-services.json`
- Add an **iOS app** if needed and download `GoogleService-Info.plist`

## 2. Backend: Service account key file (re-add the deleted file)

The backend sends FCM from the server using a **service account** JSON key.

### Get the key file

1. Go to [Firebase Console](https://console.firebase.google.com/) → your project → **Project settings** (gear).
2. Open the **Service accounts** tab.
3. Click **Generate new private key** (or use an existing one).
4. Download the JSON file. It looks like:  
   `your-project-firebase-adminsdk-xxxxx.json`

### Place it in the backend

1. **Rename** the file to:  
   `firebase-service-account.json`
2. **Copy** it into:  
   `backend/src/main/resources/firebase-service-account.json`

So the full path is:

```
Dyganox/
  backend/
    src/
      main/
        resources/
          firebase-service-account.json   <-- put the key file here
```

The file is in `.gitignore` so it will **not** be committed to git (keep it secret).

### If the file is missing

- The backend still runs; it just won’t send push notifications.
- You’ll see in logs:  
  `Firebase FCM not initialized (missing or invalid service account file)`  
  and when a request is created:  
  `Mechanic has no FCM token; skipping push notification` (if mechanic hasn’t registered token yet).

### Optional: custom path

In `backend/src/main/resources/application.properties` you can set:

```properties
firebase.service-account=classpath:firebase-service-account.json
```

Or an absolute path:

```properties
firebase.service-account=/path/to/your-firebase-key.json
```

## 3. Flutter app: Android

1. Put **google-services.json** (from Firebase Console → Project settings → your Android app) in:
   ```
   android/app/google-services.json
   ```
2. The project is already set up to apply the Google services plugin in `android/app/build.gradle.kts` and `android/build.gradle.kts` (see below). If you add the file and sync, FCM will work.

## 4. Flutter app: iOS

1. Put **GoogleService-Info.plist** (from Firebase Console → your iOS app) in:
   ```
   ios/Runner/GoogleService-Info.plist
   ```
2. Add it in Xcode to the **Runner** target if needed.

## 5. Flow summary

1. **User** (app): Find mechanic → Request mechanic → backend creates request.
2. **Backend**: Saves request, loads mechanic’s `fcmToken`, sends FCM to that token.
3. **Mechanic** (app): Receives notification; notification has **Accept** and **Reject** actions (handled in the app).
4. Tapping Accept/Reject calls the backend API to update the request status.

If the backend key file is missing, step 2 is skipped and the mechanic won’t get a push (but the request is still saved and visible in the mechanic dashboard).
