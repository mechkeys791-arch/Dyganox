@echo off
echo ================================================
echo   FINDING YOUR COMPUTER'S IP ADDRESS
echo ================================================
echo.
echo Looking for your local IP address...
echo.

ipconfig | findstr /i "IPv4"

echo.
echo ================================================
echo.
echo Look for the IPv4 Address above (should look like 192.168.x.x or 10.0.x.x)
echo.
echo Next Steps:
echo 1. Copy the IP address shown above
echo 2. Open lib/services/api_config.dart
echo 3. Replace the IP address in _localIpAddress with yours
echo 4. Set _useEmulator = false
echo 5. Run 'run-on-mobile.bat' to start the app
echo.
echo Full instructions: See MOBILE_SETUP_GUIDE.md
echo.
pause

