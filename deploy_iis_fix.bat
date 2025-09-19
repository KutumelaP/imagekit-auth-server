@echo off
echo ========================================
echo   OmniaSA IIS MIME Type Fix Deployment
echo ========================================
echo.

echo [1/4] Building Flutter web app...
call flutter build web --release
if %errorlevel% neq 0 (
    echo ERROR: Flutter build failed!
    pause
    exit /b 1
)

echo.
echo [2/4] Copying corrected web.config to build directory...
copy web.config build\web\web.config /Y
if %errorlevel% neq 0 (
    echo ERROR: Failed to copy web.config!
    pause
    exit /b 1
)

echo.
echo [3/4] Creating deployment package...
if exist "iis_deployment.zip" del "iis_deployment.zip"
powershell Compress-Archive -Path "build\web\*" -DestinationPath "iis_deployment.zip" -Force
if %errorlevel% neq 0 (
    echo ERROR: Failed to create deployment package!
    pause
    exit /b 1
)

echo.
echo [4/4] Deployment package created successfully!
echo.
echo ========================================
echo   DEPLOYMENT INSTRUCTIONS
echo ========================================
echo.
echo 1. Upload the contents of 'iis_deployment.zip' to your IIS server
echo 2. Make sure the web.config file is in the root directory
echo 3. Restart IIS or the application pool
echo 4. Test your site at https://omnisa.co.za
echo.
echo The web.config now includes:
echo - Proper MIME types for HTML, CSS, JS files
echo - SPA routing for Flutter app
echo - Security headers for PWA
echo - Compression settings
echo - API proxy rules for Payfast
echo.
echo Files ready for upload:
echo - iis_deployment.zip (contains all files)
echo - build\web\ (contains individual files)
echo.
pause
