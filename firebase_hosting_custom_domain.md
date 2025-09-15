# 🌐 Firebase Hosting Custom Domain Setup for www.omniasa.co.za

## ✅ **Domain Updates Completed**

I've updated all references from `marketplace-8d6bd.web.app` to `www.omniasa.co.za` in:

### **📱 Android Configuration:**
- ✅ `android/app/src/main/AndroidManifest.xml` - Deep linking updated
- ✅ App Links now point to `https://www.omniasa.co.za/store/...`

### **🌐 Web Configuration:**
- ✅ `web/sitemap.xml` - All URLs updated to `www.omniasa.co.za`
- ✅ `web/debug_splash.html` - Test URLs updated
- ✅ `web/flutter_test.html` - Test URLs updated

### **💻 Code Updates:**
- ✅ `lib/screens/simple_store_profile_screen.dart` - Default web base URL updated
- ✅ PayFast service already uses `omniasa.co.za` (correct!)

## 🚀 **Next Steps: Firebase Custom Domain Setup**

### **1. Add Custom Domain in Firebase Console:**
```bash
# Go to Firebase Console
https://console.firebase.google.com/project/marketplace-8d6bd/hosting

# Click "Add custom domain"
# Enter: www.omniasa.co.za
```

### **2. DNS Configuration:**
Add these DNS records in your Afrihost DNS settings:

```
Type: A
Name: www
Value: [Firebase will provide IP address]

Type: CNAME  
Name: @
Value: marketplace-8d6bd.web.app
```

### **3. SSL Certificate:**
- Firebase will automatically provision SSL certificate
- Wait 24-48 hours for SSL to activate
- Your site will be accessible at `https://www.omniasa.co.za`

### **4. Deploy with Custom Domain:**
```bash
# Build your app
flutter build web --release

# Deploy to Firebase
firebase deploy --only hosting

# Your app will be live at both:
# https://marketplace-8d6bd.web.app (Firebase default)
# https://www.omniasa.co.za (Your custom domain)
```

## 🔧 **Important Notes:**

### **Firebase Project ID Stays the Same:**
- ✅ Keep `marketplace-8d6bd` as your Firebase project ID
- ✅ This is used for Firebase Functions, Firestore, Auth, etc.
- ✅ Only the hosting domain changes

### **PayFast Integration:**
- ✅ Already correctly configured to use `omniasa.co.za`
- ✅ No changes needed for payment processing

### **Deep Linking:**
- ✅ Android app will now open `www.omniasa.co.za` links
- ✅ Web app will use your custom domain for sharing

## 🎯 **Deployment Commands:**

```bash
# Option 1: Use your existing production script
production_build.bat

# Option 2: Manual build and deploy
flutter build web --release --web-renderer html
firebase deploy --only hosting
```

## ✅ **Ready for Production!**

Your app is now configured for `www.omniasa.co.za` and ready to deploy!

**Current Status:**
- ✅ All domain references updated
- ✅ Android deep linking configured  
- ✅ Web URLs updated
- ✅ PayFast integration ready
- ✅ Firebase hosting ready for custom domain

**Next:** Add custom domain in Firebase Console and deploy! 🚀


