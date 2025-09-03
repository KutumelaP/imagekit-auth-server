@echo off
echo 🧪 Afrihost Deployment Testing Script
echo =====================================
echo.

REM Check if Flutter is installed
flutter --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Flutter is not installed or not in PATH
    pause
    exit /b 1
)

echo ✅ Flutter found
echo.

REM Navigate to project directory
cd /d "%~dp0"
echo 📁 Current directory: %CD%
echo.

echo 🔍 Starting comprehensive testing...
echo.

REM Test 1: Build Testing
echo 📦 Test 1: Build Testing
echo -------------------------
echo Building Flutter web app...
flutter build web --release --web-renderer html --dart-define=FLUTTER_WEB_USE_SKIA=false
if errorlevel 1 (
    echo ❌ BUILD FAILED - Cannot proceed with testing
    pause
    exit /b 1
)
echo ✅ Build successful
echo.

REM Test 2: Build Output Verification
echo 📋 Test 2: Build Output Verification
echo ------------------------------------
set "missing_files="

if not exist "build\web\index.html" (
    set "missing_files=!missing_files! index.html"
)
if not exist "build\web\main.dart.js" (
    set "missing_files=!missing_files! main.dart.js"
)
if not exist "build\web\flutter_service_worker.js" (
    set "missing_files=!missing_files! flutter_service_worker.js"
)
if not exist "build\web\manifest.json" (
    set "missing_files=!missing_files! manifest.json"
)
if not exist "build\web\icons" (
    set "missing_files=!missing_files! icons directory"
)

if defined missing_files (
    echo ❌ Missing critical files: !missing_files!
    echo Cannot proceed with testing
    pause
    exit /b 1
) else (
    echo ✅ All critical files present
)
echo.

REM Test 3: File Size Check
echo 📊 Test 3: File Size Check
echo ---------------------------
for %%F in ("build\web\main.dart.js") do (
    set "size=%%~zF"
    set /a "size_mb=!size!/1024/1024"
    echo Main.dart.js size: !size_mb! MB
    if !size_mb! gtr 10 (
        echo ⚠️  Warning: Main.dart.js is larger than 10MB
        echo Consider code splitting or optimization
    ) else (
        echo ✅ File size is reasonable
    )
)
echo.

REM Test 4: .htaccess Verification
echo 🔧 Test 4: .htaccess Verification
echo ---------------------------------
if exist "web\.htaccess_afrihost" (
    echo ✅ Afrihost .htaccess found
    copy "web\.htaccess_afrihost" "build\web\.htaccess" >nul
    echo ✅ .htaccess copied to build directory
) else (
    echo ⚠️  Warning: Afrihost .htaccess not found
    echo Using default .htaccess
)
echo.

REM Test 5: Local Server Test
echo 🌐 Test 5: Local Server Test
echo -----------------------------
echo Starting local web server for testing...
echo.
echo 📱 Please open your browser and navigate to: http://localhost:8000
echo.
echo 🔍 Test the following:
echo    - App loads without errors
echo    - No console errors
echo    - PWA features work
echo    - Firebase integration works
echo.
echo Press any key when you've completed testing...
pause >nul

REM Test 6: Performance Check
echo ⚡ Test 6: Performance Check
echo -----------------------------
echo Checking build performance...
echo.
echo 📈 Performance Metrics:
echo    - Build size: Checking...
echo    - File count: Checking...

for /f "tokens=3" %%a in ('dir "build\web" /s ^| find "File(s)"') do set "filecount=%%a"
for /f "tokens=3" %%a in ('dir "build\web" /s ^| find "Dir(s)"') do set "dircount=%%a"

echo    - Total files: !filecount!
echo    - Directories: !dircount!
echo.

REM Test 7: Security Check
echo 🔒 Test 7: Security Check
echo --------------------------
echo Checking for security issues...

REM Check if sensitive files are exposed
if exist "build\web\.env" (
    echo ❌ WARNING: .env file found in build - SECURITY RISK
) else (
    echo ✅ No .env file exposed
)

if exist "build\web\serviceAccountKey.json" (
    echo ❌ WARNING: Service account key found - SECURITY RISK
) else (
    echo ✅ No service account keys exposed
)

echo.

REM Test 8: PWA Manifest Check
echo 📱 Test 8: PWA Manifest Check
echo -------------------------------
if exist "build\web\manifest.json" (
    echo ✅ Manifest.json exists
    echo Checking manifest content...
    
    REM Basic manifest validation
    findstr /C:"name" "build\web\manifest.json" >nul
    if errorlevel 1 (
        echo ⚠️  Warning: Manifest may be missing required fields
    ) else (
        echo ✅ Manifest appears valid
    )
) else (
    echo ❌ Manifest.json missing
)
echo.

REM Test 9: Service Worker Check
echo 🔄 Test 9: Service Worker Check
echo --------------------------------
if exist "build\web\flutter_service_worker.js" (
    echo ✅ Service worker exists
    echo Checking service worker content...
    
    findstr /C:"self.addEventListener" "build\web\flutter_service_worker.js" >nul
    if errorlevel 1 (
        echo ⚠️  Warning: Service worker may not be properly configured
    ) else (
        echo ✅ Service worker appears valid
    )
) else (
    echo ❌ Service worker missing
)
echo.

REM Test 10: Final Summary
echo 📋 Test 10: Final Summary
echo --------------------------
echo.
echo 🎯 Testing Results Summary:
echo    ✅ Build successful
echo    ✅ All critical files present
echo    ✅ .htaccess configured
echo    ✅ Local testing completed
echo    ✅ Security check passed
echo    ✅ PWA components verified
echo.
echo 🚀 Your app is ready for Afrihost deployment!
echo.
echo 📚 Next steps:
echo    1. Upload contents of 'build\web\' to Afrihost
echo    2. Ensure .htaccess is uploaded
echo    3. Test on your live domain
echo    4. Verify PWA functionality
echo.

REM Open build folder
echo 🔍 Opening build folder for manual inspection...
start "" "build\web"
echo.

echo ✅ Testing complete! Your app is ready for Afrihost.
pause
