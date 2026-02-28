#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOH
Usage:
  ./scripts/release.sh [--install]

Examples:
  ./scripts/release.sh
  ./scripts/release.sh --install

Behavior:
  - Local only: build + package .app into dist (no git tag, no GitHub release).
  - --install: install built app to /Applications/MoodBreak.app.
EOH
}

DO_INSTALL=false
APP_NAME="MoodBreak"
BUNDLE_ID="com.silentwqh.moodbreak"
LOCAL_VERSION="0.0.0"
DIST_DIR="dist"
APP_DIR="${DIST_DIR}/${APP_NAME}.app"
ZIP_NAME="${APP_NAME}-local-macOS.zip"
ZIP_PATH="${DIST_DIR}/${ZIP_NAME}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install)
      DO_INSTALL=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown argument '$1'"
      usage
      exit 1
      ;;
  esac
  shift
done

if ! command -v swift >/dev/null 2>&1; then
  echo "Error: swift is required."
  exit 1
fi

echo "==> Building release binary"
swift build -c release

BIN_PATH="$(find .build -type f -path "*/release/${APP_NAME}" | head -n 1)"
if [[ -z "${BIN_PATH}" ]]; then
  echo "Error: cannot find built binary for ${APP_NAME}."
  exit 1
fi

RESOURCE_BUNDLE="$(find .build -type d -path "*/release/${APP_NAME}_${APP_NAME}.bundle" | head -n 1)"
if [[ -z "${RESOURCE_BUNDLE}" ]]; then
  echo "Error: cannot find SwiftPM resource bundle."
  exit 1
fi

echo "==> Preparing app bundle at ${APP_DIR}"
rm -rf "${APP_DIR}" "${ZIP_PATH}"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"

cp "${BIN_PATH}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_DIR}/Contents/MacOS/${APP_NAME}"
cp -R "${RESOURCE_BUNDLE}" "${APP_DIR}/Contents/Resources/${APP_NAME}_${APP_NAME}.bundle"

cat > "${APP_DIR}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${LOCAL_VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${LOCAL_VERSION}</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
PLIST

echo "==> Codesigning app bundle"
codesign --force --deep --sign - --identifier "${BUNDLE_ID}" "${APP_DIR}"
codesign --verify --deep --strict --verbose=2 "${APP_DIR}"

echo "==> Creating zip artifact ${ZIP_PATH}"
mkdir -p "${DIST_DIR}"
ditto -c -k --keepParent "${APP_DIR}" "${ZIP_PATH}"

if ${DO_INSTALL}; then
  echo "==> Installing app to /Applications/${APP_NAME}.app"
  rm -rf "/Applications/${APP_NAME}.app"
  ditto "${APP_DIR}" "/Applications/${APP_NAME}.app"
fi

echo "==> Done (local package only)"
echo "Artifact: ${ZIP_PATH}"
if ${DO_INSTALL}; then
  echo "Installed: /Applications/${APP_NAME}.app"
fi
