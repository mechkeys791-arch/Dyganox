@echo off
echo ================================================
echo   Starting Dyganox Backend Server
echo ================================================
echo.

cd backend

echo Checking if JAR file exists...
if not exist "target\ev-charging-backend-0.0.1-SNAPSHOT.jar" (
    echo ERROR: JAR file not found!
    echo.
    echo Building JAR file first...
    echo.
    call mvn clean package -DskipTests
    if %errorlevel% neq 0 (
        echo ERROR: Failed to build JAR file!
        pause
        exit /b 1
    )
)

echo.
echo Starting backend server on port 8081...
echo Your IP: 192.168.11.73
echo.
echo Backend will be accessible at:
echo - From this computer: http://localhost:8081
echo - From your phone: http://192.168.11.73:8081
echo.
echo ================================================
echo Press Ctrl+C to stop the server
echo ================================================
echo.

java -jar target\ev-charging-backend-0.0.1-SNAPSHOT.jar

pause

