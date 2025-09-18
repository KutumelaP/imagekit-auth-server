# 🔐 Android Production Signing Setup

## Current Issue:
Your APK shows "might be harmful" because it's using **debug signing** instead of production signing.

## ✅ Solution: Generate Production Keystore

### Step 1: Generate Production Keystore
```bash
# Navigate to android/app directory
cd android/app

# Generate production keystore
keytool -genkey -v -keystore omniasa-release-key.keystore -alias omniasa -keyalg RSA -keysize 2048 -validity 10000

# You'll be prompted for:
# - Keystore password (remember this!)
# - Key password (can be same as keystore)
# - Your name, organization, city, state, country
```

### Step 2: Create key.properties file
Create `android/key.properties`:
```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=omniasa
storeFile=../app/omniasa-release-key.keystore
```

### Step 3: Update build.gradle.kts
Add this to `android/app/build.gradle.kts`:

```kotlin
// Add at the top after plugins
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    // ... existing code ...
    
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }
    
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            minifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}
```

### Step 4: Build Production APK
```bash
# Build production APK
flutter build apk --release

# The APK will be at: build/app/outputs/flutter-apk/app-release.apk
```

## 🛡️ Security Benefits:
- ✅ **Properly Signed**: Recognized as legitimate app
- ✅ **No Warnings**: Android won't show "harmful" message
- ✅ **Play Store Ready**: Can be uploaded to Google Play
- ✅ **User Trust**: Professional appearance

## 📱 Alternative: Quick Fix for Testing
If you just want to test without warnings:

1. **Enable "Install Unknown Apps"** on Android device
2. **Trust the source** when prompted
3. **Install anyway** - the warning is just Android being cautious

## 🎯 Recommendation:
Generate the production keystore for a professional, trustworthy app that users will install without hesitation!




