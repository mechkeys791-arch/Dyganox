@echo off
cd /d C:\Users\naikh\Dyganox
echo ================================================
echo Running Flutter App on Mobile Device
echo ================================================
echo.

set FLUTTER_PATH=C:\Users\naikh\Desktop\Flutter\flutter\bin
set PATH=%FLUTTER_PATH%;%PATH%

echo Checking connected devices...
flutter devices

echo.
echo Starting app on vivo 1915 device...
flutter run -d NN4TXW49VWVGEA6H

pause

