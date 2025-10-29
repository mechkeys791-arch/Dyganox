@echo off
echo ================================================
echo Fixing Device Connection Issues
echo ================================================
echo.

set FLUTTER_PATH=C:\Users\prems\Documents\flutter\bin
set ANDROID_SDK=C:\Users\naikh\AppData\Local\Android\Sdk
set PATH=%FLUTTER_PATH%;%ANDROID_SDK%\platform-tools;%PATH%

echo Step 1: Killing ADB server...
adb kill-server
timeout /t 2 /nobreak >nul

echo Step 2: Starting ADB server...
adb start-server
echo.

echo Step 3: Checking connected devices...
adb devices
echo.

echo ================================================
echo If your device shows as "unauthorized":
echo   - Check your phone screen for USB debugging permission
echo   - Tap "Allow" or "Always allow from this computer"
echo.
echo If no devices show:
echo   1. Disconnect and reconnect your phone
echo   2. Change USB mode to "File Transfer" (MTP)
echo   3. Try a different USB cable or port
echo   4. Make sure USB Debugging is enabled
echo   5. Install USB drivers for your phone brand
echo ================================================
echo.

pause

