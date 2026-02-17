# Mechanic request notifications – sound & alarm

## 30-second continuous alarm (default)

When a mechanic request notification arrives **while the app is in foreground**, the app plays the device's **alarm sound in a loop for 30 seconds** (or until the mechanic taps Accept or Reject). This uses the system alarm ringtone.

- **Foreground**: 30-sec alarm works automatically
- **Background/terminated**: Standard notification sound plays once (Android limitation)
- Alarm stops immediately when mechanic taps **Accept** or **Reject**

## Optional: Custom notification sound

To use a custom sound instead of the device default when the notification first appears:

1. Add an MP3 file in `android/app/src/main/res/raw/` with the exact name: **notification_alert.mp3**
   (no spaces; lowercase). Use a short, clear alert sound (1-3 seconds).
   Note: File names in `res/raw/` must be lowercase a-z, 0-9, or underscore only.

2. In `lib/services/fcm_notification_service.dart`, find `AndroidNotificationDetails`
   and add the sound parameter:
   ```dart
   sound: RawResourceAndroidNotificationSound('notification_alert'),
   ```

3. Rebuild the app. If the file is missing, remove the sound line to avoid errors.

The 30-second foreground alarm still uses the device alarm sound; the custom sound affects only the initial notification popup.
