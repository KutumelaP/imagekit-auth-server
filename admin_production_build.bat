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
call flutter build web --release --web-renderer html
if %ERRORLEVEL% neq 0 (
    echo ❌ Admin web build failed
    cd ..
    exit /b 1
)

cd ..

echo.
echo ✅ Admin Dashboard production build completed!
echo.
echo 🌐 Admin Web build: admin_dashboard\build\web\
echo.
echo 🎉 Admin Dashboard is ready for deployment!
pause
