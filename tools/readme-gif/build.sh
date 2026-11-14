#!/bin/sh
# Builds docs/brightmeup.gif: renders the frames with the app views, then makes a GIF with ffmpeg.
# Needs Xcode and ffmpeg.
cd "$(dirname "$0")/../.." || exit 1
if [ -z "$DEVELOPER_DIR" ] && [ -d /Applications/Xcode-27.0.app ]; then
   export DEVELOPER_DIR=/Applications/Xcode-27.0.app/Contents/Developer
fi
work=$(mktemp -d) || exit 1
mkdir "$work/frames"
# The app icon, drawn by the same code as the app.
swiftc -O -o "$work/app-icon" app/AppIcon.swift && "$work/app-icon" "$work/icon.png" || exit 1
swiftc -parse-as-library -O -D GIF_RENDER -target arm64-apple-macos14 -import-objc-header theme/gray-rule.h \
   -o "$work/render" app/BrightMeUp.swift app/Previews.swift tools/readme-gif/Render.swift || exit 1
"$work/render" "$PWD/docs" "$work/icon.png" "$work/frames" || exit 1
ffmpeg -v error -y -framerate 20 -i "$work/frames/frame-%04d.png" \
   -vf "scale=960:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=256:stats_mode=full[p];[b][p]paletteuse=dither=sierra2_4a" \
   -loop 0 docs/brightmeup.gif || exit 1
sips -z 256 256 "$work/icon.png" --out docs/icon.png > /dev/null
# KEEP_FRAMES=1 keeps the rendered frames for a look.
if [ -n "$KEEP_FRAMES" ]; then
   echo "Frames: $work/frames"
else
   rm -r "$work"
fi
ls -lh docs/brightmeup.gif
