@echo off
echo 🚀 Afrihost Deployment Script for Mzansi Marketplace
echo ===================================================
echo.

REM Check if Flutter is installed
flutter --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Flutter is not installed or not in PATH
    echo Please install Flutter and add it to your PATH
    pause
    exit /b 1
)

echo ✅ Flutter found
echo.

REM Navigate to project directory
cd /d "%~dp0"
echo 📁 Current directory: %CD%
echo.

REM Clean previous build
echo 🧹 Cleaning previous build...
if exist "build\web" (
    rmdir /s /q "build\web"
    echo ✅ Previous build cleaned
) else (
    echo ℹ️  No previous build found
)
echo.

REM Get dependencies
echo 📦 Getting Flutter dependencies...
flutter pub get
if errorlevel 1 (
    echo ❌ Failed to get dependencies
    pause
    exit /b 1
)
echo ✅ Dependencies updated
echo.

REM Build for web
echo 🔨 Building Flutter web app...
flutter build web --release --web-renderer html --dart-define=FLUTTER_WEB_USE_SKIA=false
if errorlevel 1 (
    echo ❌ Build failed
    pause
    exit /b 1
)
echo ✅ Web app built successfully
echo.

REM Copy optimized .htaccess for Afrihost
echo 📋 Copying Afrihost-optimized .htaccess...
if exist "web\.htaccess_afrihost" (
    copy "web\.htaccess_afrihost" "build\web\.htaccess" >nul
    echo ✅ .htaccess copied for Afrihost
) else (
    echo ⚠️  Warning: .htaccess_afrihost not found, using default
)
echo.

REM Show build summary
echo 📊 Build Summary:
echo    📁 Build location: build\web\
echo    📄 Main files:
echo       - index.html
echo       - main.dart.js
echo       - flutter_service_worker.js
echo       - manifest.json
echo       - .htaccess
echo       - icons\ (PWA icons)
echo.

REM Check build size
for /f "tokens=3" %%a in ('dir "build\web" /s ^| find "File(s)"') do set "filecount=%%a"
for /f "tokens=3" %%a in ('dir "build\web" /s ^| find "Dir(s)"') do set "dircount=%%a"
echo 📈 Build statistics:
echo    📁 Directories: %dircount%
echo    📄 Files: %filecount%
echo.

REM Create deployment package
echo 📦 Creating deployment package...
if exist "afrihost_deployment.zip" del "afrihost_deployment.zip"
powershell -command "Compress-Archive -Path 'build\web\*' -DestinationPath 'afrihost_deployment.zip'"
if errorlevel 1 (
    echo ❌ Failed to create deployment package
) else (
    echo ✅ Deployment package created: afrihost_deployment.zip
)
echo.

echo 🎯 Next Steps:
echo    1. Upload the contents of 'build\web\' to your Afrihost public_html directory
echo    2. Or upload 'afrihost_deployment.zip' and extract it on the server
echo    3. Ensure .htaccess is uploaded (important for routing)
echo    4. Test your app at your domain
echo    5. Verify PWA functionality
echo.

echo 📚 For detailed instructions, see: afrihost_deployment_guide.md
echo.

REM Open build folder
echo 🔍 Opening build folder...
start "" "build\web"
echo.

echo ✅ Deployment preparation complete!
pause
