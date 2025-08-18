Write-Host "Starting ImageKit Authentication Server..." -ForegroundColor Green
Write-Host ""
Write-Host "Prerequisites:" -ForegroundColor Yellow
Write-Host "1. Node.js installed" -ForegroundColor White
Write-Host "2. Run 'npm install' first" -ForegroundColor White
Write-Host "3. Create .env file with your ImageKit credentials" -ForegroundColor White
Write-Host ""
Write-Host "Starting server on port 3001..." -ForegroundColor Cyan
Write-Host ""

try {
    node server.js
} catch {
    Write-Host "Error starting server: $_" -ForegroundColor Red
    Write-Host "Make sure Node.js is installed and dependencies are installed" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Press any key to continue..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
