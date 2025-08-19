# Flutter Web Build Instructions

## For iOS Safari Compatibility & Modern Flutter Versions

### Build Commands

**For Production (Recommended):**
```bash
flutter build web --web-renderer canvaskit --release
```

**For Development/Testing:**
```bash
flutter build web --web-renderer canvaskit --profile
```

**For Debugging:**
```bash
flutter build web --web-renderer canvaskit --debug
```

### Why CanvasKit Renderer?

1. **Better Compatibility**: Works with older and newer Flutter versions
2. **iOS Safari Stability**: Less likely to cause memory pressure refreshes
3. **Consistent Rendering**: Same appearance across all browsers
4. **Better Performance**: GPU-accelerated rendering

### Flutter Version Compatibility

- **Flutter 3.0+**: Full CanvasKit support ✅
- **Flutter 2.10+**: CanvasKit available with `--web-renderer canvaskit`
- **Flutter 2.8+**: Limited CanvasKit support
- **Older versions**: May need HTML renderer fallback

### iOS Safari Optimizations Applied

✅ **Memory Management**: Enhanced garbage collection
✅ **Page Preservation**: Prevents auto-refresh on tab switch  
✅ **Keep-Alive System**: Maintains app state in background
✅ **CSS GPU Acceleration**: Reduces memory pressure
✅ **State Persistence**: LocalStorage backup for critical data

### Performance Tips

1. **Use CanvasKit for production**
2. **Enable web optimization in pubspec.yaml**:
   ```yaml
   flutter:
     web:
       compiler: dart2js
   ```
3. **Optimize images for web**
4. **Use lazy loading for large lists**

### Testing

Test on actual iOS Safari devices, not just simulators:
- iPhone Safari
- iPad Safari  
- Safari on macOS

### Deployment

When deploying, ensure:
- `/canvaskit/` folder is included
- CORS headers allow CanvasKit loading
- Gzip compression enabled
- CDN caching configured properly
