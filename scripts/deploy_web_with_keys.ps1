# Requires: PowerShell, Flutter, Firebase CLI in PATH
# Usage:
#   $env:OPENAI_API_KEY = "sk-..."
#   # optional:
#   # $env:GOOGLE_TTS_API_KEY = "..."
#   # $env:GEMINI_API_KEY = "..."
#   # $env:FIREBASE_PROJECT = "marketplace-8d6bd"
#   ./scripts/deploy_web_with_keys.ps1

$ErrorActionPreference = 'Stop'

function Require-Env([string]$name) {
  if (-not $env:$name -or [string]::IsNullOrWhiteSpace($env:$name)) {
    throw "Environment variable $name is required. Set `$env:$name before running."
  }
}

# Ensure required tools
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw "flutter not found in PATH. Install Flutter or add it to PATH."
}
if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) {
  throw "firebase CLI not found in PATH. Install with 'npm i -g firebase-tools' and run 'firebase login'."
}

Require-Env -name 'OPENAI_API_KEY'

Write-Host "🔧 Building web with dart-defines (OPENAI_API_KEY masked)" -ForegroundColor Cyan
& ./build_web_with_keys.bat

if ($LASTEXITCODE -ne 0) { throw "Web build failed." }

$project = if ($env:FIREBASE_PROJECT) { $env:FIREBASE_PROJECT } else { 'marketplace-8d6bd' }

Write-Host "🚀 Deploying to Firebase Hosting (project: $project)" -ForegroundColor Green
firebase deploy --only hosting --project $project

if ($LASTEXITCODE -ne 0) { throw "Firebase deploy failed." }

Write-Host "✅ Deploy complete." -ForegroundColor Green


