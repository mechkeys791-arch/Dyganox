@echo off
echo ================================================
echo Starting Flutter App on Mobile Device
echo ================================================
echo.

REM Check if Flutter is available
where flutter >nul 2>&1
if %errorlevel% neq 0 (
    echo Flutter not found in PATH!
    echo Trying to add Flutter to PATH...
    set PATH=%PATH%;C:\Users\naikh\OneDrive\Desktop\Flutter\flutter\bin
)


echo Checking connected devices...
flutter devices

echo.
echo Starting app on vivo 1915...
flutter run -d NN4TXW49VWVGEA6H

pause

