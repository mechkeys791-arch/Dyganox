@echo off
echo ================================================
echo   DYGANOX - Mobile Device Runner
echo ================================================
echo.

echo Step 1: Checking Flutter installation...
flutter --version
if %errorlevel% neq 0 (
    echo ERROR: Flutter is not installed or not in PATH!
    echo Please install Flutter first: https://flutter.dev/docs/get-started/install
    pause
    exit /b 1
)
echo.

echo Step 2: Checking connected devices...
flutter devices
if %errorlevel% neq 0 (
    echo ERROR: No devices found!
    echo Please connect your phone via USB and enable USB debugging
    pause
    exit /b 1
)
echo.

echo Step 3: Have you updated the API configuration?
echo.
echo IMPORTANT: Before continuing, make sure you have:
echo 1. Found your computer's IP address (using 'ipconfig')
echo 2. Updated lib/services/api_config.dart with your IP
echo 3. Set _useEmulator = false in api_config.dart
echo 4. Your backend is running on port 8081
echo.
echo Current directory: %cd%
echo.
set /p continue="Have you completed these steps? (y/n): "
if /i not "%continue%"=="y" (
    echo.
    echo Please complete the setup steps first!
    echo See MOBILE_SETUP_GUIDE.md for detailed instructions
    pause
    exit /b 0
)
echo.

echo Step 4: Cleaning Flutter build...
flutter clean
echo.

echo Step 5: Getting dependencies...
flutter pub get
if %errorlevel% neq 0 (
    echo ERROR: Failed to get dependencies!
    pause
    exit /b 1
)
echo.

echo Step 6: Starting Flutter app on your device...
echo.
echo The app will now launch on your connected device
echo Keep this window open to see logs and errors
echo.
echo Hot Reload: Press 'r' while app is running
echo Hot Restart: Press 'R' while app is running
echo Quit: Press 'q' or Ctrl+C
echo.
echo ================================================
echo.

flutter run

echo.
echo ================================================
echo App has stopped
echo ================================================
pause

