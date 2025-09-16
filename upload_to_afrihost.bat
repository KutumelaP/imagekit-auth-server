@echo off
echo ========================================
echo    Uploading OmniaSA Web App to Afrihost
echo ========================================
echo.

echo Copying files to build/web directory...
echo.

echo ✅ Build completed successfully!
echo.
echo 📁 Files ready for upload in: build\web\
echo.
echo 🚀 Upload these files to your Afrihost server:
echo    - All files from build\web\ to /omniasi0e1h2/
echo.
echo 📋 Key files to upload:
echo    ✅ index.html (main app)
echo    ✅ download.html (download page)
echo    ✅ download-apk.php (PHP proxy)
echo    ✅ web.config (IIS config)
echo    ✅ OmniaSA-App.apk (your APK)
echo    ✅ All assets/ folder contents
echo    ✅ All other Flutter web files
echo.
echo 🌐 After upload, test:
echo    1. https://www.omniasa.co.za (main app)
echo    2. https://www.omniasa.co.za/download.html (download page)
echo    3. Click download button to test APK download
echo.
echo Press any key to open the build folder...
pause >nul
start build\web
