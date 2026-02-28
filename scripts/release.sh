#!/usr/bin/env bash
set -euo pipefail

VERSION_TAG="${1:-v0.0.1}"
APP_NAME="MoodBreak"
BUNDLE_ID="com.silentwqh.moodbreak"
DIST_DIR="dist"
APP_DIR="${DIST_DIR}/${APP_NAME}.app"
ZIP_NAME="${APP_NAME}-${VERSION_TAG}-macOS.zip"
ZIP_PATH="${DIST_DIR}/${ZIP_NAME}"

if [[ ! "${VERSION_TAG}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: version tag must look like v0.0.1"
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "Error: gh CLI is required."
  exit 1
fi

if ! command -v swift >/dev/null 2>&1; then
  echo "Error: swift is required."
  exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Error: working tree is not clean. Commit or stash first."
  exit 1
fi

if git rev-parse "${VERSION_TAG}" >/dev/null 2>&1; then
  echo "Error: tag ${VERSION_TAG} already exists."
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

# Bundle.module in SwiftPM executable resolves to:
# Bundle.main.bundleURL/<target>_<module>.bundle
cp -R "${RESOURCE_BUNDLE}" "${APP_DIR}/${APP_NAME}_${APP_NAME}.bundle"

cat > "${APP_DIR}/Contents/Info.plist" <<EOF
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
  <string>${VERSION_TAG#v}</string>
  <key>CFBundleVersion</key>
  <string>${VERSION_TAG#v}</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
EOF

echo "==> Creating zip artifact ${ZIP_PATH}"
mkdir -p "${DIST_DIR}"
ditto -c -k --keepParent "${APP_DIR}" "${ZIP_PATH}"

echo "==> Creating git tag ${VERSION_TAG}"
git tag -a "${VERSION_TAG}" -m "Release ${VERSION_TAG}"

CURRENT_BRANCH="$(git branch --show-current)"
echo "==> Pushing branch ${CURRENT_BRANCH} and tag ${VERSION_TAG}"
git push origin "${CURRENT_BRANCH}"
git push origin "${VERSION_TAG}"

echo "==> Creating GitHub release"
gh release create "${VERSION_TAG}" "${ZIP_PATH}" \
  --title "${VERSION_TAG}" \
  --notes "Release ${VERSION_TAG}\n\n- Packaged macOS .app bundle\n- Includes status bar icon assets and resource bundle"

echo "==> Done"
echo "Release URL:"
gh release view "${VERSION_TAG}" --json url -q .url
