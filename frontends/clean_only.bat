@echo off
echo ================================================
echo Flutter Deep Clean Script
echo ================================================
echo.

REM Stop all Gradle daemons
echo [1/4] Stopping Gradle daemons...
cd android
call gradlew --stop
cd ..
echo Done.
echo.

REM Kill any Java processes that might be locking files
echo [2/4] Stopping Java processes...
taskkill /F /IM java.exe /T 2>nul
taskkill /F /IM javaw.exe /T 2>nul
echo Done.
echo.

REM Wait for processes to close
timeout /t 2 /nobreak >nul

REM Force delete build directories
echo [3/4] Removing build directories...
if exist "build" rmdir /s /q "build" 2>nul
if exist ".dart_tool" rmdir /s /q ".dart_tool" 2>nul
if exist "android\.gradle" rmdir /s /q "android\.gradle" 2>nul
if exist "android\build" rmdir /s /q "android\build" 2>nul
if exist "android\app\build" rmdir /s /q "android\app\build" 2>nul
if exist "ios\Flutter\ephemeral" rmdir /s /q "ios\Flutter\ephemeral" 2>nul
if exist "linux\flutter\ephemeral" rmdir /s /q "linux\flutter\ephemeral" 2>nul
if exist "macos\Flutter\ephemeral" rmdir /s /q "macos\Flutter\ephemeral" 2>nul
if exist "windows\flutter\ephemeral" rmdir /s /q "windows\flutter\ephemeral" 2>nul
echo Done.
echo.

REM Get Flutter dependencies
echo [4/4] Getting Flutter dependencies...
call flutter pub get
echo Done.
echo.

echo ================================================
echo Clean completed successfully!
echo You can now run: flutter run
echo ================================================
pause
