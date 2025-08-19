# Flutter Web HTML Renderer Configuration

This project has been configured to use Flutter's HTML renderer for better stability and navigation performance.

## Why HTML Renderer?

✅ **Better for your use case:**
- More stable navigation (fixes "reload to home" issues)
- Lower memory usage (better for Safari/iOS)
- Faster initial load
- Better compatibility with mobile browsers

❌ **Trade-offs:**
- Slightly slower for complex animations
- Text rendering may vary slightly between browsers

## How to Use

### Option 1: Build with HTML Renderer (Recommended)
```bash
# Windows (PowerShell)
.\build_web_html.ps1

# Windows (Command Prompt)
build_web_html.bat

# Manual build
flutter build web --web-renderer html --release
```

### Option 2: Run Locally with HTML Renderer
```bash
flutter run -d chrome --web-renderer html
```

### Option 3: Test in Development
```bash
flutter run -d chrome --web-renderer html --debug
```

## What Was Changed

1. **`web/index.html`** - Added HTML renderer configuration
2. **`analysis_options.yaml`** - Removed deprecated lint rules
3. **Build scripts** - Created easy-to-use build commands

## Configuration Details

The HTML renderer is configured in `web/index.html`:
```html
<script>
  window.flutterConfiguration = {
    renderer: "html"
  };
</script>
```

## When to Switch Back to CanvasKit

Consider switching back to CanvasKit if you need:
- Heavy 3D graphics or complex animations
- Pixel-perfect rendering across all browsers
- Gaming or graphics-intensive features

To switch back:
```bash
flutter build web --web-renderer canvaskit --release
```

## Troubleshooting

If you encounter issues:
1. Clear browser cache
2. Run `flutter clean` before building
3. Check browser console for errors
4. Ensure you're using the latest Flutter version

## Performance Tips

- Use `const` constructors where possible
- Minimize complex animations
- Optimize images and assets
- Consider lazy loading for heavy components
