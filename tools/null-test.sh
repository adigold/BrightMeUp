#!/bin/sh
# The null test (Adi, 2026-11-14): proves BrightMeUp does not change the sound.
#   tools/null-test.sh stock-bounce.wav brightmeup-bounce.wav
# Bounce the same project twice with the same settings: once with Logic Pro started from the Dock
# (stock), once started from BrightMeUp. Use a project without random or time-based effects.
# This decodes both files to 32-bit float samples and compares them sample by sample.
[ $# -eq 2 ] || { echo "Usage: $0 stock.wav brightmeup.wav"; exit 2; }
work=$(mktemp -d) || exit 1
for i in 1 2; do
   eval "file=\${$i}"
   ffmpeg -v error -y -i "$file" -f f32le -acodec pcm_f32le "$work/$i.raw" || { echo "Cannot read $file"; exit 2; }
done
python3 -I - "$work/1.raw" "$work/2.raw" <<'PY'
import array, sys
a, b = array.array('f'), array.array('f')
a.frombytes(open(sys.argv[1], 'rb').read())
b.frombytes(open(sys.argv[2], 'rb').read())
if len(a) != len(b):
    print("DIFFERENT LENGTH: %d vs %d samples" % (len(a), len(b)))
    sys.exit(1)
diff = max((abs(x - y) for x, y in zip(a, b)), default=0.0)
if diff == 0:
    print("PASS: the two bounces are identical, sample for sample (%d samples)." % len(a))
    sys.exit(0)
import math
print("DIFFERENT: largest sample difference %.3g (%.1f dBFS)" % (diff, 20 * math.log10(diff)))
sys.exit(1)
PY
result=$?
rm -r "$work"
exit $result
