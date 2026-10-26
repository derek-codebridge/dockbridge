#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"

[[ -f release.local.env ]] && source release.local.env

APP=build/DockBridge.app
IDENTITY="${DOCKBRIDGE_SIGN_IDENTITY:--}"
SIGN_FLAGS=(--force --options runtime)
[[ "$IDENTITY" != "-" ]] && SIGN_FLAGS+=(--timestamp)

rm -rf "$APP" build/arch
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/arch
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
for arch in arm64 x86_64; do
  swiftc -O -swift-version 5 -target "$arch-apple-macos14" Sources/*.swift -o "build/arch/DockBridge-$arch"
done
lipo -create build/arch/DockBridge-arm64 build/arch/DockBridge-x86_64 -output "$APP/Contents/MacOS/DockBridge"
cp Info.plist "$APP/Contents/Info.plist"
codesign "${SIGN_FLAGS[@]}" --sign "$IDENTITY" "$APP"
codesign --verify --strict "$APP"

if [[ "${1:-}" == "install" ]]; then
  pkill -x DockBridge || true
  sleep 1
  rm -rf ~/Applications/DockBridge.app
  mkdir -p ~/Applications
  ditto "$APP" ~/Applications/DockBridge.app
  open ~/Applications/DockBridge.app
fi
