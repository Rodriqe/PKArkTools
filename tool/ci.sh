#!/usr/bin/env bash
# CI local: análisis estático + tests de pkcore y de la app.
# Nunca lanza la app de escritorio (nada de `flutter run/drive -d macos`): todo
# es headless (flutter test) y la compilación Android no abre ventanas.
set -euo pipefail
cd "$(dirname "$0")/.."
export PUB_CACHE="${PUB_CACHE:-$PWD/.pub-cache}"
# Los temporales de los tests (Directory.systemTemp) se quedan dentro del workspace.
mkdir -p .scratch/tmp
export TMPDIR="$PWD/.scratch/tmp"

flutter pub get
echo "== pkcore: dart analyze ==";   (cd packages/pkcore && dart analyze --fatal-infos)
echo "== pkcore: dart test ==";      (cd packages/pkcore && dart test)
echo "== app: flutter analyze ==";   (cd apps/pkarktools && flutter analyze --fatal-infos)
echo "== app: flutter test ==";      (cd apps/pkarktools && flutter test)
echo "== docs: enlaces ==";          python3 tool/check_links.py
echo "== generador Champions ==";    python3 tool/test_gen_champions_data.py
# Opcional: compilación Android, solo si el entorno está instalado en el
# workspace (tool/android_setup.sh). Se omite con CI_ANDROID=0.
if [ -d .ref/android/sdk ] && [ "${CI_ANDROID:-1}" != 0 ]; then
  echo "== app: flutter build apk --debug (Android) =="
  (source tool/android_env.sh && cd apps/pkarktools && flutter build apk --debug)
else
  echo "== Android: omitido (no existe .ref/android) =="
fi
echo "OK"
