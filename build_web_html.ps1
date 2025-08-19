Write-Host "Building Flutter Web with HTML Renderer..." -ForegroundColor Green
Write-Host "This will create a more stable web app with better navigation" -ForegroundColor Yellow

flutter build web --web-renderer html --release

Write-Host ""
Write-Host "Build complete!" -ForegroundColor Green
Write-Host "Files are in: build/web/" -ForegroundColor Cyan
Write-Host ""
Write-Host "To test locally, run: flutter run -d chrome --web-renderer html" -ForegroundColor Cyan
Write-Host ""
Write-Host "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
