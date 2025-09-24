@echo off
echo Building optimized APK for low-end devices...

REM Clean previous builds
echo Cleaning previous builds...
flutter clean
flutter pub get

REM Build optimized APK with all optimizations
echo Building optimized APK...
flutter build apk --release ^
    --split-per-abi ^
    --obfuscate ^
    --split-debug-info=build/app/outputs/symbols ^
    --target-platform android-arm,android-arm64 ^
    --dart-define=GOOGLE_TTS_API_KEY=%GOOGLE_TTS_API_KEY% ^
    --dart-define=OPENAI_API_KEY=%OPENAI_API_KEY% ^
    --dart-define=GEMINI_API_KEY=%GEMINI_API_KEY%

REM Check if build was successful
if %ERRORLEVEL% neq 0 (
    echo Build failed!
    pause
    exit /b 1
)

REM Copy APKs to web directory
echo Copying APKs to web directory...
if exist "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" (
    copy "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" "web\app-arm64-v8a-release.apk"
    echo ARM64 APK copied
)

if exist "build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk" (
    copy "build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk" "web\app-armeabi-v7a-release.apk"
    echo ARM32 APK copied
)

REM Also copy the universal APK
if exist "build\app\outputs\flutter-apk\app-release.apk" (
    copy "build\app\outputs\flutter-apk\app-release.apk" "web\app-release.apk"
    copy "build\app\outputs\flutter-apk\app-release.apk" "web\app-release-latest.apk"
    echo Universal APK copied
)

REM Show file sizes
echo.
echo APK file sizes:
if exist "web\app-arm64-v8a-release.apk" (
    for %%A in ("web\app-arm64-v8a-release.apk") do echo ARM64: %%~zA bytes
)
if exist "web\app-armeabi-v7a-release.apk" (
    for %%A in ("web\app-armeabi-v7a-release.apk") do echo ARM32: %%~zA bytes
)
if exist "web\app-release.apk" (
    for %%A in ("web\app-release.apk") do echo Universal: %%~zA bytes
)

echo.
echo Build completed successfully!
echo Optimized APKs are in the web directory.
pause
