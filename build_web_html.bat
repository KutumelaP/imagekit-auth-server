@echo off
echo Building Flutter Web with HTML Renderer...
echo This will create a more stable web app with better navigation

flutter build web --web-renderer html --release

echo.
echo Build complete! 
echo Files are in: build/web/
echo.
echo To test locally, run: flutter run -d chrome --web-renderer html
echo.
pause

