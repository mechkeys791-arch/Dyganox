@echo off
echo ================================================
echo Checking Connected Mobile Devices
echo ================================================
echo.

set FLUTTER_PATH=C:\Users\prems\Documents\flutter\bin
set ANDROID_SDK=C:\Users\naikh\AppData\Local\Android\Sdk
set PATH=%FLUTTER_PATH%;%ANDROID_SDK%\platform-tools;%PATH%

echo Checking if ADB is working...
echo.
adb version
echo.

echo ================================================
echo Connected Devices (via ADB):
echo ================================================
adb devices
echo.

echo ================================================
echo Connected Devices (via Flutter):
echo ================================================
flutter devices
echo.

echo ================================================
echo If no devices show above:
echo 1. Make sure USB Debugging is enabled on your phone
echo 2. Check if you allowed USB debugging prompt on your phone
echo 3. Try different USB cable or USB port
echo 4. Install USB drivers for your phone brand
echo 5. Try running: adb kill-server then adb start-server
echo ================================================
echo.

pause

