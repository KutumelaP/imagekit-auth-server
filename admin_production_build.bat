@echo off
echo 🚀 Starting Admin Dashboard Production Build...
echo.

cd admin_dashboard

echo 🧹 Cleaning previous builds...
call flutter clean
if %ERRORLEVEL% neq 0 (
    echo ❌ Flutter clean failed
    cd ..
    exit /b 1
)

echo 📦 Getting dependencies...
call flutter pub get
if %ERRORLEVEL% neq 0 (
    echo ❌ Flutter pub get failed
    cd ..
    exit /b 1
)

echo 🌐 Building Admin Dashboard for Web (Release)...
call flutter build web --release --base-href /admin_dashboard/
if %ERRORLEVEL% neq 0 (
    echo ❌ Admin web build failed
    cd ..
    exit /b 1
)

cd ..

echo.
echo 📁 Preparing deployable admin web folder under main build...
if not exist build\web mkdir build\web
if exist build\web\admin_dashboard rmdir /S /Q build\web\admin_dashboard
mkdir build\web\admin_dashboard
xcopy /E /I /Y admin_dashboard\build\web build\web\admin_dashboard >nul

echo ✅ Admin Dashboard production build completed and copied to build\web\admin_dashboard!
echo.
echo 🌐 Admin Web output: build\web\admin_dashboard\
echo.
echo 🎉 Admin Dashboard is ready for deployment!

