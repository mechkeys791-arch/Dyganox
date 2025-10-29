# Setup Mobile Device for Flutter Development

## Current Issue
Your mobile device is not showing up because **Android SDK is not installed**.

## Solution: Install Android SDK

### Method 1: Install Android Studio (Recommended)

1. **Download Android Studio**
   - Go to: https://developer.android.com/studio
   - Download the latest version for Windows
   - File size: ~1GB

2. **Install Android Studio**bbbbb
   - Run the installer
   - During installation, make sure these are checked:
     - ✅ Android SDK
     - ✅ Android SDK Platform
     - ✅ Android SDK Platform-Tools
     - ✅ Android Virtual Device (optional)

3. **First Launch**
   - Open Android Studio
   - It will show "Android SDK Setup" wizard
   - Click "Next" and let it download required components
   - This may take 10-15 minutes

4. **Configure Flutter to use Android SDK**
   - After installation, run this command:
   ```
   flutter config --android-sdk C:\Users\prems\AppData\Local\Android\Sdk
   ```

### Method 2: Install SDK Command Line Tools Only (Lightweight)

If you don't want to install Android Studio:

1. Download SDK Command Line Tools from: https://developer.android.com/studio#command-line-tools-only
2. Extract to: `C:\Android\sdk`
3. Add to system PATH:
   - `C:\Android\sdk\platform-tools`
   - `C:\Android\sdk\tools`
4. Install platform tools:
   ```
   sdkmanager "platform-tools" "platforms;android-33"
   ```

## After Installing Android SDK

### Enable USB Debugging on Your Phone

1. **Enable Developer Options**
   - Go to Settings → About Phone
   - Tap "Build Number" 7 times
   - You'll see "You are now a developer!"

2. **Enable USB Debugging**
   - Go to Settings → Developer Options
   - Turn ON "Developer Options"
   - Turn ON "USB Debugging"
   - Turn ON "Install via USB" (if available)

3. **Connect Your Phone**
   - Connect phone via USB cable
   - When popup appears "Allow USB debugging?", tap "ALLOW"
   - Check "Always allow from this computer"

4. **Change USB Mode**
   - Pull down notification shade
   - Tap on "USB charging this device"
   - Select "File Transfer" or "MTP"

### Install USB Drivers (For Vivo Phone)

Your phone is a **Vivo 1915**. You may need to:
1. Download Vivo USB drivers from Vivo website
2. Or install Universal ADB Drivers: https://adb.clockworkmod.com/

### Verify Device Connection

After setup, run:
```batch
.\check-device.bat
```

You should see your phone listed!

## Troubleshooting

### Device shows as "unauthorized"
- Check phone screen for USB debugging permission dialog
- Tap "Allow"

### Device still not showing
1. Try different USB cable
2. Try different USB port (USB 2.0 ports work better)
3. Restart ADB: Run `.\fix-device-connection.bat`
4. Restart phone
5. Unplug and replug USB cable

### ADB offline
Run: `.\fix-device-connection.bat`

## Running Your App

Once device is detected:
```batch
.\run-flutter-app.bat
```

Or manually:
```batch
flutter run -d <device-id>
```

Your current device ID from the script: `NN4TXW49VWVGEA6H`

