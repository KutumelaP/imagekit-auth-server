@echo off
echo Building web with API keys...

REM Clean previous builds
echo Cleaning previous builds...
flutter clean
flutter pub get

REM Build web with API keys
echo Building web...
flutter build web --release ^
    --dart-define=GOOGLE_TTS_API_KEY=%GOOGLE_TTS_API_KEY% ^
    --dart-define=OPENAI_API_KEY=%OPENAI_API_KEY% ^
    --dart-define=GEMINI_API_KEY=%GEMINI_API_KEY%

REM Check if build was successful
if %ERRORLEVEL% neq 0 (
    echo Build failed!
    pause
    exit /b 1
)

REM Copy build to web directory
echo Copying build to web directory...
robocopy build\web web /E /NFL /NDL /NJH /NJS /NP

REM Check main.dart.js size
echo Checking main.dart.js size...
for %%A in ("web\main.dart.js") do echo main.dart.js: %%~zA bytes

echo.
echo Build completed successfully!
pause

