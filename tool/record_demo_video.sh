#!/usr/bin/env bash
# Graba las tomas del vídeo de demostración en el emulador Android headless.
#
#   tool/record_demo_video.sh es    # UI en español (Facebook)
#   tool/record_demo_video.sh en    # UI en inglés (repo)
#
# Lanza integration_test/demo_video_test.dart (perfil, datos sintéticos) en
# emulator-5554 y lo graba con `adb shell screenrecord` desde que la prueba
# avisa «DEMO_READY» (iconos ya en caché) hasta «DEMO_DONE». Deja la toma y
# los tiempos de cada escena en .scratch/video/takes/:
#   demo_<lang>.mp4         grabación cruda 1080×2400
#   demo_<lang>.scenes      «segundos nombre» por escena, desde el inicio de la toma
# Luego tool/make_demo_video.sh monta los vídeos finales.
set -euo pipefail
cd "$(dirname "$0")/.."
LANG_UI="${1:-en}"
# shellcheck source=tool/android_env.sh
source tool/android_env.sh
export HOME="$PST_WS/.scratch/home"
DEV=emulator-5554
ADB=(adb -s "$DEV")
OUT=.scratch/video/takes
mkdir -p "$OUT"
LOG="$OUT/drive_$LANG_UI.log"
SCENES="$OUT/demo_$LANG_UI.scenes"
: > "$SCENES"

# Barra de estado limpia (modo demo de SystemUI): 12:00, batería llena, sin avisos.
"${ADB[@]}" shell settings put global sysui_demo_allowed 1
demo() { "${ADB[@]}" shell am broadcast -a com.android.systemui.demo -e command "$@" >/dev/null; }
demo enter
demo clock -e hhmm 1200
demo battery -e level 100 -e plugged false
demo network -e wifi show -e level 4
demo network -e mobile hide
demo notifications -e visible false
"${ADB[@]}" shell cmd uimode night yes >/dev/null

# La prueba imprime marcas; se les pone la hora del Mac para cortar después.
(
  cd apps/pkarktools
  flutter drive --profile -d "$DEV" --driver test_driver/integration_test.dart \
    --target integration_test/demo_video_test.dart --dart-define=DEMO_LANG="$LANG_UI" 2>&1
) | python3 -I -u -c '
import sys, time
for line in sys.stdin:
    sys.stdout.write("%.3f %s" % (time.time(), line))
' > "$LOG" &
DRIVE=$!

wait_mark() { # $1 = marca
  until grep -q "$1" "$LOG"; do
    kill -0 "$DRIVE" 2>/dev/null || { echo "flutter drive terminó sin «$1»; ver $LOG" >&2; exit 1; }
    sleep 0.2
  done
}
wait_mark DEMO_READY
# Si algo falla, que no siga grabando.
trap '"${ADB[@]}" shell pkill -INT screenrecord >/dev/null 2>&1 || true' EXIT
"${ADB[@]}" shell rm -f /sdcard/demo.mp4
"${ADB[@]}" shell screenrecord --bit-rate 16000000 --time-limit 180 /sdcard/demo.mp4 &
REC=$!
T0=$(python3 -c 'import time; print("%.3f" % time.time())')
wait_mark DEMO_DONE
sleep 0.5
"${ADB[@]}" shell pkill -INT screenrecord || true
wait "$REC" || true
sleep 1
"${ADB[@]}" pull /sdcard/demo.mp4 "$OUT/demo_$LANG_UI.mp4" >/dev/null
"${ADB[@]}" shell rm -f /sdcard/demo.mp4
wait "$DRIVE" || true
demo exit

grep -E "DEMO_(SCENE|DONE)" "$LOG" | python3 -I -c '
import sys
t0 = float(sys.argv[1])
for line in sys.stdin:
    t, rest = line.split(" ", 1)
    name = rest.strip().split("DEMO_SCENE ")[-1] if "DEMO_SCENE" in rest else "done"
    print("%.2f %s" % (float(t) - t0, name))
' "$T0" > "$SCENES"
cat "$SCENES"
echo "toma: $OUT/demo_$LANG_UI.mp4"
