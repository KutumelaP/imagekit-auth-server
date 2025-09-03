# 🚀 Afrihost Hosting Guide for Mzansi Marketplace

## Overview
This guide will help you deploy your Flutter food marketplace app to Afrihost's hosting platform. Your app is already optimized for web hosting with PWA capabilities.

## Prerequisites
- Afrihost hosting account (Shared Hosting, VPS, or Dedicated Server)
- Domain name pointed to Afrihost
- Flutter SDK installed locally
- Firebase project configured

## Step 1: Build Your Flutter Web App

### Option A: Build Locally
```bash
# Navigate to your project directory
cd /c/food_marketplace_app

# Get dependencies
flutter pub get

# Build for web with production optimizations
flutter build web --release --web-renderer html --dart-define=FLUTTER_WEB_USE_SKIA=false

# The built files will be in: build/web/
```

### Option B: Use the Existing Build Script
```bash
# Run the existing build script
./build_web_html.bat
# or
./build_web_html.ps1
```

## Step 2: Prepare Files for Upload

Your built web app will be in the `build/web/` directory. The key files are:
- `index.html` - Main entry point
- `main.dart.js` - Flutter app bundle
- `flutter_service_worker.js` - Service worker for PWA
- `manifest.json` - PWA manifest
- `icons/` - App icons
- `.htaccess` - Apache configuration

## Step 3: Upload to Afrihost

### Via cPanel File Manager
1. Log into your Afrihost cPanel
2. Open File Manager
3. Navigate to `public_html/` (or your domain's root directory)
4. Upload all contents from `build/web/` to this directory

### Via FTP/SFTP
1. Use FileZilla or similar FTP client
2. Connect to your Afrihost server
3. Upload all files from `build/web/` to `public_html/`

## Step 4: Configure Domain

### DNS Settings
Ensure your domain points to Afrihost:
- A Record: Point to Afrihost's IP
- CNAME: Point www to your domain
- Wait 24-48 hours for DNS propagation

### SSL Certificate
- Afrihost provides free Let's Encrypt SSL certificates
- Enable SSL in cPanel → SSL/TLS
- Your app will be accessible via HTTPS

## Step 5: Test Your Deployment

### Basic Functionality
- Visit your domain to ensure the app loads
- Test PWA installation on mobile devices
- Verify Firebase services are working
- Check service worker registration

### PWA Testing
- Use Chrome DevTools → Application tab
- Test offline functionality
- Verify app installation prompts

## Step 6: Performance Optimization

### Enable Afrihost Features
- **Gzip Compression**: Already configured in `.htaccess`
- **Browser Caching**: Already configured in `.htaccess`
- **CDN**: Consider Afrihost's CDN for faster global delivery

### Monitor Performance
- Use Google PageSpeed Insights
- Monitor Core Web Vitals
- Check Firebase Performance Monitoring

## Troubleshooting

### Common Issues

#### 1. App Not Loading
- Check file permissions (644 for files, 755 for directories)
- Verify `.htaccess` is uploaded
- Check browser console for errors

#### 2. PWA Not Working
- Ensure HTTPS is enabled
- Check `manifest.json` is accessible
- Verify service worker registration

#### 3. Firebase Issues
- Check Firebase configuration in `firebase_options.dart`
- Verify domain is added to Firebase authorized domains
- Check browser console for Firebase errors

#### 4. 404 Errors on Refresh
- Ensure `.htaccess` is properly configured
- Check if mod_rewrite is enabled on Afrihost
- Verify all routes are handled by `index.html`

### Afrihost Support
If you encounter hosting-specific issues:
- Contact Afrihost support via live chat
- Submit a support ticket
- Check Afrihost's knowledge base

## Maintenance

### Regular Updates
- Rebuild and redeploy after Flutter updates
- Keep Firebase dependencies updated
- Monitor app performance metrics

### Backup Strategy
- Keep local copies of your source code
- Backup your Firebase data regularly
- Document your deployment process

## Cost Considerations

### Afrihost Hosting Plans
- **Shared Hosting**: R99/month (suitable for testing)
- **VPS**: R299/month (recommended for production)
- **Dedicated Server**: R999/month (for high traffic)

### Recommended Plan
For a production marketplace app, consider:
- **VPS Hosting**: Better performance and control
- **Unlimited bandwidth**: For growing user base
- **Daily backups**: Data protection
- **24/7 support**: Technical assistance

## Next Steps

1. **Build your app** using the commands above
2. **Upload to Afrihost** via cPanel or FTP
3. **Test thoroughly** on different devices
4. **Monitor performance** and user feedback
5. **Scale as needed** based on traffic growth

## Support Resources

- [Afrihost Knowledge Base](https://afrihost.com/support)
- [Flutter Web Deployment](https://docs.flutter.dev/deployment/web)
- [PWA Best Practices](https://web.dev/progressive-web-apps/)
- [Firebase Hosting](https://firebase.google.com/docs/hosting)

---

**Need Help?** Contact Afrihost support or refer to this guide for common deployment issues.
