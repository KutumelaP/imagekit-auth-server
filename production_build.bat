@echo off
echo 🚀 Starting Production Build Process...
echo.

echo 🧹 Cleaning previous builds...
call flutter clean
if %ERRORLEVEL% neq 0 (
    echo ❌ Flutter clean failed
    exit /b 1
)

echo 📦 Getting dependencies...
call flutter pub get
if %ERRORLEVEL% neq 0 (
    echo ❌ Flutter pub get failed
    exit /b 1
)

echo 🔧 Building for production...
echo.

echo 📱 Building Android APK (Release)...
call flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols
if %ERRORLEVEL% neq 0 (
    echo ❌ Android APK build failed
    exit /b 1
)

echo 🌐 Building Web (Release)...
call flutter build web --release --web-renderer html
if %ERRORLEVEL% neq 0 (
    echo ❌ Web build failed
    exit /b 1
)

echo.
echo ✅ Production builds completed successfully!
echo.
echo 📱 Android APK: build\app\outputs\flutter-apk\app-release.apk
echo 🌐 Web build: build\web\
echo.
echo 🎉 Your app is ready for deployment!
pause
