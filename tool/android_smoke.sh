#!/usr/bin/env bash
# Prueba de humo en el emulador Android (todo dentro del workspace) y capturas
# reales con `adb exec-out screencap` en docs/screenshots/android/.
#
#   tool/android_smoke.sh            # arranca el AVD si hace falta, instala el
#                                    # APK release y recorre la app
#   tool/android_smoke.sh --no-shots # igual, sin escribir capturas
#
# Recorrido: onboarding → «Elegir carpeta» (selector SAF real del sistema,
# manejado con uiautomator: Documents/ArcaPST, «Usar esta carpeta», «Permitir»)
# → partidas de ejemplo → detalle → cajas → editor (quitar variocolor, aplicar,
# guardar en el Arca: escribe por SAF) → inventario → Pokédex → Ajustes
# (reindexar por SAF) → tema claro → reinicio en frío (permiso persistente).
# Requiere tool/android_setup.sh --avd. Solo datos sintéticos de ejemplo.
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=tool/android_env.sh
source tool/android_env.sh
export HOME="$PST_WS/.scratch/home" # adb/emulador: nada en ~
PKG=dev.pkarktools.app
APK=apps/pkarktools/build/app/outputs/flutter-apk/app-release.apk
OUT=docs/screenshots/android
SHOTS=1
[ "${1:-}" = "--no-shots" ] && SHOTS=0
mkdir -p "$OUT" .scratch/logs

fail() { echo "FALLO: $*" >&2; adb exec-out screencap -p > .scratch/logs/smoke_fail.png || true; exit 1; }

# Nodos de la UI (Flutter expone su semántica a uiautomator).
dump() { adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1; adb exec-out cat /sdcard/ui.xml; }
find_node() { # $1 = texto o content-desc (subcadena; «=texto» exacto) → "x y" del centro
  dump | python3 -I -c '
import sys, re
q = sys.argv[1]
exact = q.startswith("=")
q = q.lstrip("=")
for m in re.finditer(r"<node ([^>]*)>", sys.stdin.read()):
    a = dict(re.findall(r"([\w-]+)=\"([^\"]*)\"", m.group(1)))
    t, d = a.get("text", ""), a.get("content-desc", "")
    if (q in (t, d)) if exact else (q in t or q in d):
        b = list(map(int, re.findall(r"\d+", a["bounds"])))
        if b[2] > b[0] and b[3] > b[1]:
            print((b[0] + b[2]) // 2, (b[1] + b[3]) // 2); break
' "$1"
}
wait_for() { # $1 = texto, $2 = segundos
  local t=0
  until [ -n "$(find_node "$1")" ]; do t=$((t + 1)); [ "$t" -gt "${2:-20}" ] && fail "no aparece «$1»"; sleep 1; done
}
tap() { local c; c=$(find_node "$1"); [ -n "$c" ] || fail "no encuentro «$1»"; adb shell input tap $c; sleep "${2:-2}"; }
swipe_up() { adb shell input swipe 540 "${1:-1700}" 540 "${2:-900}" 500; sleep 1; }
scroll_to() { # $1 = texto: desde arriba, desliza hasta que aparece
  for _ in 1 2 3; do adb shell input swipe 540 700 540 2000 200; done; sleep 1
  local t=0
  until [ -n "$(find_node "$1")" ]; do t=$((t + 1)); [ "$t" -gt 12 ] && fail "no aparece «$1» al desplazar"; swipe_up 1700 1000; done
}
shot() { [ "$SHOTS" = 1 ] && adb exec-out screencap -p > "$OUT/$1.png" && echo "captura: $OUT/$1.png"; return 0; }

# --- Emulador ---------------------------------------------------------------
if ! adb get-state >/dev/null 2>&1; then
  echo "== Arrancando el AVD pst_pixel8 (headless) =="
  nohup emulator -avd pst_pixel8 -no-window -no-audio -gpu swiftshader_indirect -no-snapshot -no-boot-anim \
    > .scratch/logs/emulator.log 2>&1 &
  adb wait-for-device
fi
for _ in $(seq 1 90); do [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ] && break; sleep 2; done
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0

# --- Instalación limpia -----------------------------------------------------
# Recompila si el APK falta o es más viejo que el código.
if [ ! -f "$APK" ] || [ -n "$(find apps/pkarktools/lib packages/pkcore/lib -newer "$APK" -name '*.dart' | head -1)" ]; then
  (cd apps/pkarktools && flutter build apk --release)
fi
adb uninstall "$PKG" >/dev/null 2>&1 || true
# Recién arrancado, el almacenamiento compartido puede no estar listo («Bad address»).
for _ in 1 2 3 4 5 6; do adb shell rm -rf /sdcard/Documents/ArcaPST 2>/dev/null && break; sleep 3; done
adb install -r "$APK" >/dev/null
adb shell cmd locale set-app-locales "$PKG" --locales es-CL
adb logcat -c
adb shell am start -n "$PKG/.MainActivity" >/dev/null

echo "== Onboarding =="
wait_for "Elegir carpeta" 40
shot 01_onboarding

echo "== Selector SAF =="
tap "Elegir carpeta" 3
wait_for "USE THIS FOLDER" 20
shot 02_selector_saf
tap "Documents"
tap "New folder"
adb shell input text "ArcaPST"
tap "=OK" 3
tap "USE THIS FOLDER"
tap "ALLOW" 4
wait_for "Probar con partidas de ejemplo" 20
adb shell dumpsys activity permissions | grep -A2 "targetPkg=$PKG" | grep -q "persisted=0x3" \
  || fail "permiso SAF no persistido (lectura+escritura)"

echo "== Partidas de ejemplo =="
tap "Probar con partidas de ejemplo" 3
wait_for "8 partidas a salvo" 60
shot 03_arca
n=$(adb shell "find /sdcard/Documents/ArcaPST/PKArkTools -type f -name '*.sav'" | wc -l | tr -d ' ')
[ "$n" = 8 ] || fail "esperaba 8 .sav en la carpeta, hay $n"
[ -z "$(adb shell "find /sdcard/Documents/ArcaPST -name '.*.tmp'")" ] || fail "quedan temporales"

echo "== Detalle, cajas y editor =="
scroll_to "Pokémon Espada"
tap "Pokémon Espada" 4
wait_for "Checksum correcto"
shot 04_detalle
swipe_up 1800 500; swipe_up 1800 300; adb shell input swipe 540 600 540 1000 500; sleep 1
shot 05_cajas
tap "Eternatus" 4
wait_for "Editar Pokémon"
shot 06_editor
swipe_up 1500 400
tap "=No" 1 # variocolor: No
tap "Aplicar cambios" 3
for _ in 1 2 3; do adb shell input swipe 540 600 540 1800 300; done; sleep 1
tap "Guardar en el Arca" 3
c=$(dump | python3 -I -c '
import sys, re
nodes = [dict(re.findall(r"([\w-]+)=\"([^\"]*)\"", m.group(1))) for m in re.finditer(r"<node ([^>]*)>", sys.stdin.read())]
hits = [a for a in nodes if "Guardar en el Arca" in a.get("content-desc", "") and a.get("clickable") == "true"]
b = list(map(int, re.findall(r"\d+", hits[-1]["bounds"]))); print((b[0]+b[2])//2, (b[1]+b[3])//2)')
adb shell input tap $c; sleep 4
n=$(adb shell "find '/sdcard/Documents/ArcaPST/PKArkTools/Pokémon Espada - Escudo' -type f -name '*.sav'" | wc -l | tr -d ' ')
[ "$n" = 2 ] || fail "esperaba 2 copias de Espada tras guardar, hay $n"

echo "== Inventario y Pokédex =="
swipe_up 1700 900
tap "Inventario" 3
swipe_up 1700 1100; adb shell input swipe 540 1000 540 1300 400; sleep 1
shot 07_inventario
y=$(find_node "Inventario" | cut -d' ' -f2)
adb shell input swipe 1000 "$y" 100 "$y" 600; sleep 1
tap "Pokédex" 4
swipe_up 1700 1000
shot 08_pokedex

echo "== Ajustes: reindexar y tema claro =="
tap "Pestaña 3" 3
tap "Reindexar" 5
wait_for "copias"
shot 09_ajustes_carpeta
tap "Claro" 2

echo "== Reinicio en frío (permiso persistente) =="
adb shell am force-stop "$PKG"
adb shell am start -n "$PKG/.MainActivity" >/dev/null
wait_for "8 partidas a salvo" 30
shot 10_arca_claro
scroll_to "Pokémon Espada"
tap "Pokémon Espada" 4
swipe_up 1700 900
y=$(find_node "Inventario" | cut -d' ' -f2)
adb shell input swipe 1000 "$y" 100 "$y" 600; sleep 1
tap "Pokédex" 4
swipe_up 1700 1000
shot 11_pokedex_claro

if adb logcat -d | grep -E "E/flutter|FATAL EXCEPTION" | grep -q .; then
  adb logcat -d | grep -E "E/flutter|FATAL EXCEPTION" | head -20
  fail "errores en logcat"
fi
echo "OK: recorrido Android completo"
