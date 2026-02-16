# Optional: Custom loud notification sound for mechanic requests

To use a custom (e.g. louder) sound when a mechanic request notification arrives:

1. Add an MP3 file in `android/app/src/main/res/raw/` with the exact name: **notification_alert.mp3**
   (no spaces; lowercase). Use a short, clear alert sound (1-3 seconds).
   Note: File names in `res/raw/` must be lowercase a-z, 0-9, or underscore only.

2. In `lib/services/fcm_notification_service.dart`, find `AndroidNotificationDetails`
   and add the sound parameter:
   ```dart
   sound: RawResourceAndroidNotificationSound('notification_alert'),
   ```

3. Rebuild the app. If the file is missing, remove the sound line to avoid errors.

The app works without this file; it uses the device default notification sound
and a strong vibration pattern.
