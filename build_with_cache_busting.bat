@echo off
echo 🚀 Building with automatic cache busting...

echo.
echo 📋 Step 1: Updating cache versions...
dart run scripts/update_cache_version.dart

if %ERRORLEVEL% neq 0 (
    echo ❌ Failed to update cache versions
    exit /b 1
)

echo.
echo 🧹 Step 2: Cleaning previous build...
flutter clean

echo.
echo 📦 Step 3: Getting dependencies...
flutter pub get

echo.
echo 🏗️ Step 4: Building web release...
flutter build web --release --web-renderer html

if %ERRORLEVEL% neq 0 (
    echo ❌ Build failed
    exit /b 1
)

echo.
echo ✅ Build completed successfully with cache busting!
echo 🌐 Your web app is ready for deployment in the build/web directory
echo.
echo 💡 Tips for sellers/users:
echo   - New users will automatically get the latest version
echo   - Existing users will be forced to refresh on first visit
echo   - Service worker will auto-clear old caches
echo   - App version is now embedded in all requests
echo.
pause
