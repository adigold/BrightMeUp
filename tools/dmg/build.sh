#!/bin/sh
# Builds dist/BrightMeUp.dmg, the drag-and-drop installer, from a signed and notarized app.
#   tools/dmg/build.sh [path/to/BrightMeUp.app]   (default: app/BrightMeUp.app)
# SKIP_NOTARIZE=1 skips notarizing the DMG. Needs Xcode and the brightmeup-notary keychain profile.
cd "$(dirname "$0")/../.." || exit 1
app=${1:-app/BrightMeUp.app}
sign_id="Developer ID Application: Adi Goldstein (4HJV6RPCLU)"
if [ -z "$DEVELOPER_DIR" ] && [ -d /Applications/Xcode-27.0.app ]; then
   export DEVELOPER_DIR=/Applications/Xcode-27.0.app/Contents/Developer
fi
codesign --verify --strict "$app" || { echo "The app is not signed: $app"; exit 1; }
work=$(mktemp -d) || exit 1
# The background, at 1x and 2x in one TIFF so it is sharp on Retina screens.
swiftc -parse-as-library -O -o "$work/background" tools/dmg/Background.swift || exit 1
"$work/background" "$work" || exit 1
tiffutil -cathidpicheck "$work/background.png" "$work/background@2x.png" -out "$work/background.tiff" > /dev/null || exit 1
# The disk icon is the app icon.
cp "$app/Contents/Resources/AppIcon.icns" "$work/VolumeIcon.icns"
ditto "$app" "$work/BrightMeUp.app"
dmgbuild="build/dmgbuild/bin/dmgbuild"
[ -x "$dmgbuild" ] || { python3 -m venv build/dmgbuild && build/dmgbuild/bin/pip install -q "dmgbuild==1.6.7"; } || exit 1
mkdir -p dist
rm -f dist/BrightMeUp.dmg
"$dmgbuild" -s tools/dmg/settings.py -D app="$work/BrightMeUp.app" -D icon="$work/VolumeIcon.icns" \
   -D background="$work/background.tiff" "BrightMeUp" dist/BrightMeUp.dmg > /dev/null || exit 1
codesign --sign "$sign_id" --timestamp dist/BrightMeUp.dmg || exit 1
if [ -z "$SKIP_NOTARIZE" ]; then
   xcrun notarytool submit dist/BrightMeUp.dmg --keychain-profile brightmeup-notary --wait || exit 1
   xcrun stapler staple dist/BrightMeUp.dmg || exit 1
fi
cp "$work/background@2x.png" dist/dmg-background@2x.png
rm -r "$work"
ls -lh dist/BrightMeUp.dmg
