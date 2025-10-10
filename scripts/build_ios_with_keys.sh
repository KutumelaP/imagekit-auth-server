#!/usr/bin/env bash

set -euo pipefail

#
# Build iOS with required dart-defines injected (no secrets committed)
#
# Usage (on macOS):
#   export OPENAI_API_KEY="sk-..."
#   # Optional:
#   # export GOOGLE_TTS_API_KEY="..."
#   # export GEMINI_API_KEY="..."
#   # CLEAN=0 BUILD_MODE=release
#   bash scripts/build_ios_with_keys.sh
#
# Notes:
# - Requires macOS + Xcode + Flutter SDK in PATH
# - This script only builds. After success, open ios/Runner.xcworkspace in Xcode to Archive/Distribute.
#

if [[ "$(uname)" != "Darwin" ]]; then
  echo "This script must be run on macOS (required for iOS builds)." >&2
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter not found in PATH. Install Flutter and ensure it is available." >&2
  exit 1
fi

OPENAI_API_KEY="${OPENAI_API_KEY:-}"
GOOGLE_TTS_API_KEY="${GOOGLE_TTS_API_KEY:-}"
GEMINI_API_KEY="${GEMINI_API_KEY:-}"

if [[ -z "${OPENAI_API_KEY}" ]]; then
  echo "OPENAI_API_KEY is required. Export it before running this script." >&2
  echo "Example: export OPENAI_API_KEY=sk-... && bash scripts/build_ios_with_keys.sh" >&2
  exit 1
fi

BUILD_MODE="${BUILD_MODE:-release}"   # release | debug | profile
CLEAN="${CLEAN:-1}"                   # 1 to run flutter clean, 0 to skip

DEFINE_ARGS=(
  --dart-define=OPENAI_API_KEY="${OPENAI_API_KEY}"
)

if [[ -n "${GOOGLE_TTS_API_KEY}" ]]; then
  DEFINE_ARGS+=(--dart-define=GOOGLE_TTS_API_KEY="${GOOGLE_TTS_API_KEY}")
fi
if [[ -n "${GEMINI_API_KEY}" ]]; then
  DEFINE_ARGS+=(--dart-define=GEMINI_API_KEY="${GEMINI_API_KEY}")
fi

echo "🚀 Building iOS (${BUILD_MODE}) with dart-defines:"
for arg in "${DEFINE_ARGS[@]}"; do
  case "$arg" in
    *OPENAI_API_KEY*) echo "  - OPENAI_API_KEY=(masked)" ;;
    *GOOGLE_TTS_API_KEY*) echo "  - GOOGLE_TTS_API_KEY=(set)" ;;
    *GEMINI_API_KEY*) echo "  - GEMINI_API_KEY=(set)" ;;
    *) echo "  - $arg" ;;
  esac
done

if [[ "${CLEAN}" == "1" ]]; then
  echo "🧹 flutter clean"
  flutter clean
fi

case "${BUILD_MODE}" in
  release)
    flutter build ios --release "${DEFINE_ARGS[@]}"
    ;;
  debug)
    flutter build ios --debug "${DEFINE_ARGS[@]}"
    ;;
  profile)
    flutter build ios --profile "${DEFINE_ARGS[@]}"
    ;;
  *)
    echo "Unknown BUILD_MODE: ${BUILD_MODE}. Use release|debug|profile" >&2
    exit 1
    ;;
esac

echo "✅ iOS build complete. Next: open ios/Runner.xcworkspace in Xcode to Archive/Distribute."




