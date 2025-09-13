@echo off
echo 🔥 Deploying Comprehensive Firestore Rules...
echo.

REM Check if Firebase CLI is installed
firebase --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Firebase CLI not found. Installing...
    npm install -g firebase-tools
)

echo 📋 Copying comprehensive rules to firestore.rules...
copy firestore_comprehensive.rules firestore.rules

echo 🚀 Deploying to Firebase...
firebase deploy --only firestore:rules

if %errorlevel% equ 0 (
    echo.
    echo ✅ SUCCESS! Firestore rules deployed successfully!
    echo 🎉 No more permission errors!
    echo.
    echo 📝 What was fixed:
    echo   • Order submission permissions
    echo   • Error logging permissions  
    echo   • Analytics collection permissions
    echo   • Monitoring collection permissions
    echo   • All admin dashboard permissions
    echo   • Catch-all rule for any missed collections
    echo.
) else (
    echo.
    echo ❌ Deployment failed. Check the error above.
    echo 💡 Try running: firebase login
)

pause
