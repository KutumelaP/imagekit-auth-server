# Requires: PowerShell, Flutter in PATH
# Usage:
#   $env:OPENAI_API_KEY = "sk-..."
#   # Optional:
#   # $env:GOOGLE_TTS_API_KEY = "..."
#   # $env:GEMINI_API_KEY = "..."
#   ./scripts/run_web_with_keys.ps1

$ErrorActionPreference = 'Stop'

function Require-Env([string]$name) {
  if (-not $env:$name -or [string]::IsNullOrWhiteSpace($env:$name)) {
    throw "Environment variable $name is required. Set `$env:$name before running."
  }
}

Require-Env -name 'OPENAI_API_KEY'

$defines = @(
  "--dart-define=OPENAI_API_KEY=$($env:OPENAI_API_KEY)"
)

if ($env:GOOGLE_TTS_API_KEY) {
  $defines += "--dart-define=GOOGLE_TTS_API_KEY=$($env:GOOGLE_TTS_API_KEY)"
}
if ($env:GEMINI_API_KEY) {
  $defines += "--dart-define=GEMINI_API_KEY=$($env:GEMINI_API_KEY)"
}

Write-Host "Running flutter web with dart-defines (OPENAI_API_KEY masked)..."
Write-Host "  - OPENAI_API_KEY=(masked)"
if ($env:GOOGLE_TTS_API_KEY) { Write-Host "  - GOOGLE_TTS_API_KEY=(set)" }
if ($env:GEMINI_API_KEY) { Write-Host "  - GEMINI_API_KEY=(set)" }

flutter run -d chrome @defines




