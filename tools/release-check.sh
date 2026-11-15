#!/bin/sh
# The release gate (Adi, 2026-11-14): no release goes out unless this passes.
#   tools/release-check.sh [path/to/test-project.logicx] [path/to/BrightMeUp.app]
# It starts Logic Pro with the theme on a scratch copy of the test project, starts playback,
# renders every window, and lets Logic Pro end itself with no save. Then it checks:
#   - Logic Pro did not crash (no new crash report),
#   - the theme's launch self-check passed,
#   - every plug-in window kept the stock dark look,
#   - and it reports how many calls on audio (real-time) threads the theme skipped untouched.
# Save the test project with at least one built-in and one third-party plug-in window open, so
# Logic Pro opens those windows when it loads the project. Quit Logic Pro before running this.
cd "$(dirname "$0")/.." || exit 1
project=${1:-tools/test-project/BrightMeUp Test.logicx}
app=${2:-app/BrightMeUp.app}
library="$PWD/$app/Contents/Resources/light-theme.dylib"
case "$app" in /*) library="$app/Contents/Resources/light-theme.dylib" ;; esac
fail() { echo "FAIL: $1"; exit 1; }

pgrep -x "Logic Pro" > /dev/null && fail "Logic Pro is open. Quit it first."
[ -f "$library" ] || fail "No theme library at $library. Build the app first."
work=$(mktemp -d) || exit 1
mkdir "$work/out"
if [ -d "$project" ]; then
   cp -R "$project" "$work/test.logicx" || fail "Cannot copy the test project."
   target="$work/test.logicx"
   echo "Test project: $project"
else
   target=""
   echo "WARNING: no test project at '$project'. Only the launch is checked, not plug-in windows or playback."
fi
reports=~/Library/Logs/DiagnosticReports
before=$(ls "$reports" 2>/dev/null | grep -c "^Logic Pro")

open -g -n --env DYLD_INSERT_LIBRARIES="$library" --env LP_OUT="$work/out" --env LP_DELAY=50 --env LP_PLAY=1 --env LP_INVISIBLE=1 \
   -a "/Applications/Logic Pro.app" $target || fail "Logic Pro did not start."
# Logic Pro ends itself after LP_DELAY. Allow two minutes in all.
waited=0
sleep 5
while pgrep -x "Logic Pro" > /dev/null; do
   sleep 2
   waited=$((waited + 2))
   [ $waited -ge 120 ] && { pkill -x "Logic Pro"; fail "Logic Pro did not end by itself (hung?)."; }
done
sleep 2

after=$(ls "$reports" 2>/dev/null | grep -c "^Logic Pro")
log="$work/out/theme.log"
echo "--- theme.log"
cat "$log" 2>/dev/null
echo "---"
[ "$after" -gt "$before" ] && fail "Logic Pro crashed. See the newest 'Logic Pro' report in $reports."
[ -f "$log" ] || fail "No test log: Logic Pro ended before the test finished."
grep -q "^check=ok" "$log" || fail "The theme's self-check did not pass: $(head -1 "$log")"
# Calls on audio threads are skipped by the theme, so they are safe; the count is only reported.
skips=$(sed -n 's/^realtimeSkips=//p' "$log")
if grep "plugin=yes" "$log" | grep -v -q "effective=NSAppearanceNameDarkAqua"; then
   fail "A plug-in window did not keep the stock look."
fi
plugins=$(grep -c "plugin=yes" "$log")
if [ -n "$target" ] && [ "$plugins" -eq 0 ]; then
   fail "No plug-in window was open. Save the test project with plug-in windows open."
fi
mkdir -p dist/release-check
rm -f dist/release-check/*
cp "$work/out/"* dist/release-check/
rm -r "$work"
echo "PASS: no crash, self-check ok, $plugins plug-in window(s) kept the stock look, ${skips:-0} audio-thread call(s) skipped untouched."
echo "Window renders: dist/release-check/"
