@echo off
echo ================================================
echo   Building Dyganox Backend JAR
echo ================================================
echo.

cd backend

echo Cleaning previous builds...
call mvn clean
echo.

echo Building JAR file (skipping tests)...
call mvn package -DskipTests

if %errorlevel% equ 0 (
    echo.
    echo ================================================
    echo   BUILD SUCCESS!
    echo ================================================
    echo.
    echo JAR file created:
    echo target\ev-charging-backend-0.0.1-SNAPSHOT.jar
    echo.
    echo Next steps:
    echo 1. Run 'start-backend.bat' to start the server
    echo 2. Or run: java -jar target\ev-charging-backend-0.0.1-SNAPSHOT.jar
    echo.
) else (
    echo.
    echo ================================================
    echo   BUILD FAILED!
    echo ================================================
    echo.
    echo Please check the error messages above
    echo.
)

pause

