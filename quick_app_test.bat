@echo off
echo 🚀 Quick App Test Runner
echo ========================
echo.

REM Check if Python is available for local server
python --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Python not found - cannot start local server
    echo Please install Python or use: npx serve .
    pause
    exit /b 1
)

echo ✅ Python found - starting local server
echo.

REM Build the app first
echo 📦 Building Flutter web app...
flutter build web --release --web-renderer html --dart-define=FLUTTER_WEB_USE_SKIA=false
if errorlevel 1 (
    echo ❌ Build failed
    pause
    exit /b 1
)
echo ✅ Build successful
echo.

REM Copy optimized .htaccess
if exist "web\.htaccess_afrihost" (
    copy "web\.htaccess_afrihost" "build\web\.htaccess" >nul
    echo ✅ Afrihost .htaccess copied
)

REM Start local server
echo 🌐 Starting local web server...
echo.
echo 📱 Your app is now running at: http://localhost:8000
echo.
echo 🔍 Manual Testing Checklist:
echo    [ ] App loads without errors
echo    [ ] No red error screens
echo    [ ] Navigation works (try different routes)
echo    [ ] Firebase login works
echo    [ ] PWA install prompt appears
echo    [ ] Service worker registers (check DevTools)
echo    [ ] No console errors
echo.
echo 📊 Performance Check:
echo    - Open Chrome DevTools (F12)
echo    - Go to Performance tab
echo    - Click record and refresh page
echo    - Check for any long tasks
echo.
echo 🧪 PWA Testing:
echo    - Open DevTools → Application tab
echo    - Check Service Workers section
echo    - Verify manifest loads correctly
echo    - Test offline functionality
echo.
echo ⚠️  IMPORTANT: Test thoroughly before deploying to Afrihost!
echo.
echo Press Ctrl+C to stop the server when done testing
echo.

REM Change to build directory and start server
cd build\web
python -m http.server 8000

echo.
echo ✅ Testing complete!
pause
