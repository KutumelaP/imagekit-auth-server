@echo off
echo 🏃‍♂️ Running Comprehensive Benchmark Tests
echo =========================================
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

echo 🔨 Building app for benchmarking...
flutter build web --release --web-renderer html --dart-define=FLUTTER_WEB_USE_SKIA=false
if errorlevel 1 (
    echo ❌ Build failed - cannot run benchmarks
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

echo.
echo 📊 Starting Benchmark Tests...
echo =============================
echo.

REM Benchmark 1: File Size Analysis
echo 📦 Benchmark 1: File Size Analysis
echo --------------------------------
for %%F in ("build\web\main.dart.js") do (
    set "size=%%~zF"
    set /a "size_mb=!size!/1024/1024"
    echo Main.dart.js: !size_mb! MB
    
    if !size_mb! lss 5 (
        echo ✅ EXCELLENT: Under 5MB (Target: <5MB)
    ) else if !size_mb! lss 10 (
        echo 🟡 GOOD: Under 10MB (Target: <10MB)
    ) else (
        echo ❌ NEEDS IMPROVEMENT: Over 10MB (Target: <10MB)
    )
)
echo.

REM Benchmark 2: Build Output Analysis
echo 📋 Benchmark 2: Build Output Analysis
echo ----------------------------------
set "score=0"
set "total=5"

if exist "build\web\index.html" (
    echo ✅ index.html exists
    set /a "score+=1"
) else (
    echo ❌ index.html missing
)

if exist "build\web\main.dart.js" (
    echo ✅ main.dart.js exists
    set /a "score+=1"
) else (
    echo ❌ main.dart.js missing
)

if exist "build\web\flutter_service_worker.js" (
    echo ✅ Service worker exists
    set /a "score+=1"
) else (
    echo ❌ Service worker missing
)

if exist "build\web\manifest.json" (
    echo ✅ Manifest exists
    set /a "score+=1"
) else (
    echo ❌ Manifest missing
)

if exist "build\web\icons" (
    echo ✅ Icons directory exists
    set /a "score+=1"
) else (
    echo ❌ Icons directory missing
)

set /a "percentage=(score*100)/total"
echo.
echo 📊 Build Completeness: !score!/!total! (!percentage!%%)
if !percentage! gte 100 (
    echo ✅ EXCELLENT: All critical files present
) else if !percentage! gte 80 (
    echo 🟡 GOOD: Most critical files present
) else (
    echo ❌ NEEDS IMPROVEMENT: Missing critical files
)
echo.

REM Benchmark 3: Performance Metrics
echo ⚡ Benchmark 3: Performance Metrics
echo --------------------------------
echo Analyzing build performance...

for /f "tokens=3" %%a in ('dir "build\web" /s ^| find "File(s)"') do set "filecount=%%a"
for /f "tokens=3" %%a in ('dir "build\web" /s ^| find "Dir(s)"') do set "dircount=%%a"

echo Total files: !filecount!
echo Directories: !dircount!

if !filecount! lss 100 (
    echo ✅ EXCELLENT: Lean build (<100 files)
) else if !filecount! lss 200 (
    echo 🟡 GOOD: Reasonable build (<200 files)
) else (
    echo ❌ NEEDS IMPROVEMENT: Heavy build (>200 files)
)
echo.

REM Benchmark 4: Security Check
echo 🔒 Benchmark 4: Security Check
echo ----------------------------
set "security_score=100"

if exist "build\web\.env" (
    echo ❌ CRITICAL: .env file exposed (SECURITY RISK)
    set "security_score=0"
) else (
    echo ✅ No .env file exposed
)

if exist "build\web\serviceAccountKey.json" (
    echo ❌ CRITICAL: Service account key exposed (SECURITY RISK)
    set "security_score=0"
) else (
    echo ✅ No service account keys exposed
)

if exist "build\web\.htaccess" (
    echo ✅ .htaccess configured for security
) else (
    echo ⚠️  No .htaccess found
    set /a "security_score-=20"
)

echo.
echo 🔒 Security Score: !security_score!/100
if !security_score! gte 90 (
    echo ✅ EXCELLENT: High security
) else if !security_score! gte 70 (
    echo 🟡 GOOD: Acceptable security
) else (
    echo ❌ NEEDS IMPROVEMENT: Security issues found
)
echo.

REM Benchmark 5: PWA Features
echo 📱 Benchmark 5: PWA Features
echo ---------------------------
set "pwa_score=0"
set "pwa_total=4"

if exist "build\web\manifest.json" (
    echo ✅ Manifest.json present
    set /a "pwa_score+=1"
    
    REM Check manifest content
    findstr /C:"name" "build\web\manifest.json" >nul
    if not errorlevel 1 (
        echo ✅ Manifest has required fields
        set /a "pwa_score+=1"
    )
) else (
    echo ❌ Manifest.json missing
)

if exist "build\web\flutter_service_worker.js" (
    echo ✅ Service worker present
    set /a "pwa_score+=1"
    
    REM Check service worker content
    findstr /C:"self.addEventListener" "build\web\flutter_service_worker.js" >nul
    if not errorlevel 1 (
        echo ✅ Service worker properly configured
        set /a "pwa_score+=1"
    )
) else (
    echo ❌ Service worker missing
)

if exist "build\web\icons" (
    echo ✅ PWA icons present
) else (
    echo ❌ PWA icons missing
)

set /a "pwa_percentage=(pwa_score*100)/pwa_total"
echo.
echo 📱 PWA Score: !pwa_score!/!pwa_total! (!pwa_percentage!%%)
if !pwa_percentage! gte 90 (
    echo ✅ EXCELLENT: Full PWA support
) else if !pwa_percentage! gte 70 (
    echo 🟡 GOOD: Good PWA support
) else (
    echo ❌ NEEDS IMPROVEMENT: PWA features incomplete
)
echo.

REM Benchmark 6: Overall Assessment
echo 🎯 Benchmark 6: Overall Assessment
echo --------------------------------
echo.

echo 📊 BENCHMARK SUMMARY:
echo =====================
echo.

REM Calculate overall score
set "overall_score=0"
set "overall_total=0"

REM File size score (25 points)
if !size_mb! lss 5 (
    set /a "overall_score+=25"
) else if !size_mb! lss 10 (
    set /a "overall_score+=20"
) else (
    set /a "overall_score+=10"
)
set /a "overall_total+=25"

REM Build completeness score (20 points)
set /a "overall_score+=(score*20)/total"
set /a "overall_total+=20"

REM Security score (25 points)
set /a "overall_score+=(security_score*25)/100"
set /a "overall_total+=25"

REM PWA score (30 points)
set /a "overall_score+=(pwa_score*30)/pwa_total"
set /a "overall_total+=30"

set /a "overall_percentage=(overall_score*100)/overall_total"

echo 🏆 OVERALL BENCHMARK SCORE: !overall_score!/!overall_total! (!overall_percentage!%%)
echo.

if !overall_percentage! gte 90 (
    echo 🎉 EXCELLENT: Your app is ready for production!
    echo ✅ Will likely pass most benchmarks
    echo 🚀 Ready for Afrihost deployment
) else if !overall_percentage! gte 80 (
    echo 🟡 GOOD: Your app is mostly ready
    echo ⚠️  Some improvements needed
    echo 🚀 Can deploy with minor fixes
) else if !overall_percentage! gte 70 (
    echo 🟡 ACCEPTABLE: Your app needs work
    echo ❌ Several issues to fix
    echo ⏳ Don't deploy yet
) else (
    echo ❌ NEEDS WORK: Your app has significant issues
    echo ❌ Will likely fail benchmarks
    echo 🛑 Don't deploy until fixed
)
echo.

echo 📋 RECOMMENDATIONS:
echo ===================
echo.

if !size_mb! gte 10 (
    echo 🔧 Optimize main.dart.js size (currently !size_mb! MB)
)

if !percentage! lss 100 (
    echo 🔧 Fix missing build files
)

if !security_score! lss 90 (
    echo 🔧 Address security issues
)

if !pwa_percentage! lss 90 (
    echo 🔧 Complete PWA implementation
)

echo.
echo 🧪 Next Steps:
echo ===============
echo 1. Fix any issues identified above
echo 2. Run this benchmark again
echo 3. Test with real tools (PageSpeed Insights, Lighthouse)
echo 4. Deploy to Afrihost when score > 80
echo.

REM Open build folder for inspection
echo 🔍 Opening build folder for manual inspection...
start "" "build\web"
echo.

echo ✅ Benchmark complete! Check the results above.
pause
