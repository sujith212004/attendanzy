@echo off
echo ================================================
echo Flutter Clean Build and Run Script
echo ================================================
echo.

REM Stop all Gradle daemons
echo [1/5] Stopping Gradle daemons...
cd android
call gradlew --stop
cd ..
echo Done.
echo.

REM Kill any Java processes that might be locking files
echo [2/5] Stopping Java processes...
taskkill /F /IM java.exe /T 2>nul
taskkill /F /IM javaw.exe /T 2>nul
echo Done.
echo.

REM Wait a moment for processes to fully close
timeout /t 2 /nobreak >nul

REM Force delete build directories
echo [3/5] Removing build directories...
if exist "build" rmdir /s /q "build" 2>nul
if exist ".dart_tool" rmdir /s /q ".dart_tool" 2>nul
if exist "android\.gradle" rmdir /s /q "android\.gradle" 2>nul
if exist "android\build" rmdir /s /q "android\build" 2>nul
if exist "android\app\build" rmdir /s /q "android\app\build" 2>nul
echo Done.
echo.

REM Get Flutter dependencies
echo [4/5] Getting Flutter dependencies...
call flutter pub get
echo Done.
echo.

REM Run the app
echo [5/5] Running Flutter app...
call flutter run
