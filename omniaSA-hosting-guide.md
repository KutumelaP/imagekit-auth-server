# OmniaSA Hosting Guide for Afrihost

## 📦 Files Ready for Upload

You now have **2 zip files** ready for hosting:

### 1. Main App: `omniaSA-web-app.zip` (54.99 MB)
- **Location**: `C:\food_marketplace_app\omniaSA-web-app.zip`
- **Contents**: Main Flutter marketplace app
- **URL**: `https://www.omniasa.co.za`

### 2. Admin Dashboard: `omniaSA-admin-dashboard.zip` (8.16 MB)
- **Location**: `C:\food_marketplace_app\admin_dashboard\omniaSA-admin-dashboard.zip`
- **Contents**: Admin dashboard for managing the platform
- **URL**: `https://www.omniasa.co.za/admin`

---

## 🚀 Step-by-Step Hosting Instructions

### **Step 1: Upload Main App**

1. **In Afrihost File Manager:**
   - Navigate to: `Home / omniasa.co.za / wwwroot`
   - Upload `omniaSA-web-app.zip`
   - Extract it to the `wwwroot` directory
   - Delete the zip file after extraction

2. **Your `wwwroot` should now contain:**
   ```
   wwwroot/
   ├── index.html (Main Flutter app)
   ├── main.dart.js
   ├── assets/
   ├── canvaskit/
   ├── icons/
   ├── manifest.json
   ├── sitemap.xml
   ├── landing.php (existing)
   ├── payfastCancel.php (existing)
   ├── payfastFormRedirect.php (existing)
   ├── payfastNotify.php (existing)
   ├── payfastReturn.php (existing)
   └── web.config (existing)
   ```

### **Step 2: Create Admin Directory**

1. **In Afrihost File Manager:**
   - Navigate to: `Home / omniasa.co.za / wwwroot`
   - Create a new folder called `admin`
   - Upload `omniaSA-admin-dashboard.zip` to the `admin` folder
   - Extract it inside the `admin` folder
   - Delete the zip file after extraction

2. **Your `wwwroot/admin/` should contain:**
   ```
   wwwroot/admin/
   ├── index.html (Admin dashboard)
   ├── main.dart.js
   ├── assets/
   ├── canvaskit/
   ├── icons/
   └── manifest.json
   ```

### **Step 3: Configure Default Pages**

**Option A: Main App as Default (Recommended)**
- Keep `index.html` in `wwwroot` as the main page
- Users visiting `https://www.omniasa.co.za` will see the marketplace
- Admin dashboard accessible at `https://www.omniasa.co.za/admin`

**Option B: Landing Page First**
- Rename `index.html` to `app.html` in `wwwroot`
- Keep `landing.php` as the main page
- Add a link in `landing.php` to redirect to `app.html`

---

## 🔧 Final File Structure

```
wwwroot/
├── index.html (Main marketplace app)
├── main.dart.js
├── assets/
├── canvaskit/
├── icons/
├── manifest.json
├── sitemap.xml
├── admin/
│   ├── index.html (Admin dashboard)
│   ├── main.dart.js
│   ├── assets/
│   ├── canvaskit/
│   ├── icons/
│   └── manifest.json
├── landing.php (existing)
├── payfastCancel.php (existing)
├── payfastFormRedirect.php (existing)
├── payfastNotify.php (existing)
├── payfastReturn.php (existing)
└── web.config (existing)
```

---

## 🌐 URLs After Hosting

- **Main Marketplace**: `https://www.omniasa.co.za`
- **Admin Dashboard**: `https://www.omniasa.co.za/admin`
- **Landing Page**: `https://www.omniasa.co.za/landing.php` (if kept)

---

## ✅ Testing Checklist

After uploading, test these URLs:

1. **Main App**: Visit `https://www.omniasa.co.za`
   - Should load the Flutter marketplace
   - Test login, browsing, checkout

2. **Admin Dashboard**: Visit `https://www.omniasa.co.za/admin`
   - Should load the admin dashboard
   - Test admin login and functionality

3. **Mobile App**: Test the APK download
   - Should work from the main app

---

## 📱 Mobile App Integration

The main app includes:
- **PWA Installation**: Users can install as PWA
- **APK Download**: Android users can download the native app
- **Deep Linking**: Links work between web and mobile

---

## 🔒 Security Notes

- **Admin Access**: Only users with `role: 'admin'` can access `/admin`
- **Authentication**: Both apps use Firebase Auth
- **Data**: All data stored in Firebase Firestore

---

## 🆘 Troubleshooting

**If main app doesn't load:**
- Check that `index.html` is in `wwwroot` root directory
- Verify all files were extracted properly

**If admin dashboard doesn't load:**
- Check that `admin/index.html` exists
- Verify admin folder structure

**If mobile app download fails:**
- Check that `app-release.apk` is in `wwwroot` root directory

---

## 📞 Support

If you encounter any issues:
1. Check the browser console for errors
2. Verify file permissions in Afrihost
3. Test with different browsers
4. Contact support if needed

**Your OmniaSA marketplace is now ready for production! 🎉**








