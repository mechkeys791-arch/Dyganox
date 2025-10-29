@echo off
echo ================================================
echo   DYGANOX - Complete Startup Script
echo   Backend + Flutter App on Mobile Device
echo ================================================
echo.

echo This script will:
echo 1. Build backend JAR (if needed)
echo 2. Start backend server
echo 3. Wait for backend to start
echo 4. Launch Flutter app on your mobile device
echo.
echo IMPORTANT: Make sure your phone is connected via USB
echo           with USB Debugging enabled!
echo.
pause

echo.
echo ================================================
echo Step 1: Building Backend JAR...
echo ================================================
echo.

cd backend

if not exist "target\ev-charging-backend-0.0.1-SNAPSHOT.jar" (
    echo JAR file not found. Building...
    call mvn clean package -DskipTests
    if %errorlevel% neq 0 (
        echo ERROR: Failed to build JAR!
        pause
        exit /b 1
    )
) else (
    echo JAR file already exists. Skipping build.
)

echo.
echo ================================================
echo Step 2: Starting Backend Server
echo ================================================
echo.

echo Starting backend in background...
echo Your IP: 192.168.11.73
echo Backend URL: http://192.168.11.73:8081
echo.

start "Dyganox Backend" cmd /k "java -jar target\ev-charging-backend-0.0.1-SNAPSHOT.jar"

echo Waiting 15 seconds for backend to start...
timeout /t 15 /nobreak

cd ..

echo.
echo ================================================
echo Step 3: Checking Connected Devices
echo ================================================
echo.

flutter devices

echo.
echo ================================================
echo Step 4: Launching Flutter App on Mobile
echo ================================================
echo.

echo Running Flutter app...
echo.

flutter run

echo.
echo ================================================
echo Done!
echo ================================================
echo.
echo Note: Backend server is still running in a separate window
echo       Close that window when you're done testing
echo.

pause

