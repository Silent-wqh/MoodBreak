#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage:
  ./scripts/release.sh <version-tag> [--publish] [--install]

Examples:
  ./scripts/release.sh v0.0.3
  ./scripts/release.sh v0.0.3 --install
  ./scripts/release.sh v0.0.3 --publish
  ./scripts/release.sh v0.0.3 --publish --install

Behavior:
  - Default: local build + package only (no git push, no GitHub release).
  - --publish: create tag, push tag, create GitHub release with generated notes.
  - --install: install built app to /Applications/MoodBreak.app.
EOF
}

VERSION_TAG=""
DO_PUBLISH=false
DO_INSTALL=false
APP_NAME="MoodBreak"
BUNDLE_ID="com.silentwqh.moodbreak"
DIST_DIR="dist"
APP_DIR="${DIST_DIR}/${APP_NAME}.app"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --publish)
      DO_PUBLISH=true
      ;;
    --install)
      DO_INSTALL=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    v*)
      if [[ -n "${VERSION_TAG}" ]]; then
        echo "Error: version tag provided more than once."
        exit 1
      fi
      VERSION_TAG="$1"
      ;;
    *)
      echo "Error: unknown argument '$1'"
      usage
      exit 1
      ;;
  esac
  shift
done

if [[ -z "${VERSION_TAG}" ]]; then
  echo "Error: version tag is required (example: v0.0.3)."
  usage
  exit 1
fi

if [[ ! "${VERSION_TAG}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: version tag must look like v0.0.1"
  exit 1
fi

if ! command -v swift >/dev/null 2>&1; then
  echo "Error: swift is required."
  exit 1
fi

ZIP_NAME="${APP_NAME}-${VERSION_TAG}-macOS.zip"
ZIP_PATH="${DIST_DIR}/${ZIP_NAME}"

PREVIOUS_TAG=""
if ${DO_PUBLISH}; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "Error: gh CLI is required when using --publish."
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

  PREVIOUS_TAG="$(git tag --sort=-version:refname | head -n 1 || true)"
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

# Keep SwiftPM resource bundle under Contents/Resources so app bundle
# structure remains valid for code signing.
cp -R "${RESOURCE_BUNDLE}" "${APP_DIR}/Contents/Resources/${APP_NAME}_${APP_NAME}.bundle"

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

if ! ${DO_PUBLISH}; then
  echo "==> Done (local package only)"
  echo "Artifact: ${ZIP_PATH}"
  if ${DO_INSTALL}; then
    echo "Installed: /Applications/${APP_NAME}.app"
  fi
  exit 0
fi

echo "==> Creating git tag ${VERSION_TAG}"
git tag -a "${VERSION_TAG}" -m "Release ${VERSION_TAG}"

echo "==> Pushing tag ${VERSION_TAG}"
git push origin "${VERSION_TAG}"

echo "==> Creating GitHub release"
if [[ -n "${PREVIOUS_TAG}" ]]; then
  gh release create "${VERSION_TAG}" "${ZIP_PATH}" \
    --generate-notes \
    --notes-start-tag "${PREVIOUS_TAG}"
else
  gh release create "${VERSION_TAG}" "${ZIP_PATH}" --generate-notes
fi

echo "==> Done"
echo "Release URL:"
gh release view "${VERSION_TAG}" --json url -q .url
