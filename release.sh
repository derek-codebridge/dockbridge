#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"

[[ -f release.local.env ]] && source release.local.env

if [[ -z "${DOCKBRIDGE_SIGN_IDENTITY:-}" || "$DOCKBRIDGE_SIGN_IDENTITY" == "-" ]]; then
  echo "Set DOCKBRIDGE_SIGN_IDENTITY to a Developer ID Application identity (in release.local.env or the environment)." >&2
  exit 1
fi

IDENTITY="$DOCKBRIDGE_SIGN_IDENTITY"
NOTARY_PROFILE="${DOCKBRIDGE_NOTARY_PROFILE:-dockbridge-notary}"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist)
DMG="build/DockBridge-$VERSION.dmg"
STAGE=build/dmg

./build.sh

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
ditto build/DockBridge.app "$STAGE/DockBridge.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "DockBridge" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG"
codesign --force --timestamp --sign "$IDENTITY" "$DMG"

if [[ "${1:-}" == "--skip-notarize" ]]; then
  echo "Built $DMG (not notarised)"
  exit 0
fi

xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
spctl --assess --type open --context context:primary-signature --verbose "$DMG"
cp "$DMG" build/DockBridge.dmg
shasum -a 256 "$DMG" build/DockBridge.dmg
