#!/usr/bin/env bash
# Instala el entorno Android DENTRO del workspace, en .ref/android/ (ignorado
# por git): JDK Temurin 21, command-line tools, platform-tools, plataforma y
# build-tools que pide Flutter, NDK, emulador e imagen arm64-v8a.
# Nada se escribe en ~ (ver tool/android_env.sh). Es idempotente.
#
#   tool/android_setup.sh            # instala lo que falte
#   tool/android_setup.sh --avd      # además crea el AVD «pst_pixel8»
set -euo pipefail
cd "$(dirname "$0")/.."
WS="$PWD"
A="$WS/.ref/android"
mkdir -p "$A/dl" "$A/jdk" "$A/sdk/cmdline-tools"

API=36
BUILD_TOOLS=36.0.0
NDK=28.2.13676358
IMAGE="system-images;android-$API;google_apis;arm64-v8a"
CMDLINE_ZIP=commandlinetools-mac-13114758_latest.zip

if ! ls -d "$A"/jdk/*/Contents/Home >/dev/null 2>&1; then
  echo "== JDK 21 (Temurin, macOS aarch64) =="
  rm -rf "$A/dl/jdk" && mkdir -p "$A/dl/jdk"
  curl -fsSL -o "$A/dl/jdk/jdk.tar.gz" \
    "https://api.adoptium.net/v3/binary/latest/21/ga/mac/aarch64/jdk/hotspot/normal/eclipse"
  tar -xzf "$A/dl/jdk/jdk.tar.gz" -C "$A/jdk"
fi

if [ ! -x "$A/sdk/cmdline-tools/latest/bin/sdkmanager" ]; then
  echo "== Android command-line tools =="
  rm -rf "$A/dl/cmdline" && mkdir -p "$A/dl/cmdline"
  curl -fsSL -o "$A/dl/cmdline/cmdline.zip" "https://dl.google.com/android/repository/$CMDLINE_ZIP"
  (cd "$A/dl/cmdline" && unzip -q cmdline.zip)
  rm -rf "$A/sdk/cmdline-tools/latest"
  mv "$A/dl/cmdline/cmdline-tools" "$A/sdk/cmdline-tools/latest"
fi

# Los lanzadores de sdkmanager/avdmanager/apkanalyzer se rompen si la ruta tiene
# espacios (p. ej. «/Volumes/Disco Externo/...»): se citan las opciones de la JVM.
# (apkanalyzer lo usa `flutter build appbundle` para comprobar que los .so del
# AAB van sin símbolos de depuración; sin el parche el build termina en error.)
for f in "$A"/sdk/cmdline-tools/*/bin/sdkmanager "$A"/sdk/cmdline-tools/*/bin/avdmanager \
         "$A"/sdk/cmdline-tools/*/bin/apkanalyzer; do
  [ -f "$f" ] || continue
  sed -i '' "s|^DEFAULT_JVM_OPTS='\(-D[a-z.]*toolsdir=\)\$APP_HOME'|DEFAULT_JVM_OPTS='\"\1\$APP_HOME\"'|" "$f"
done

# shellcheck source=tool/android_env.sh
source "$WS/tool/android_env.sh"

echo "== Paquetes del SDK =="
yes | sdkmanager --sdk_root="$ANDROID_HOME" --licenses >/dev/null || true
sdkmanager --sdk_root="$ANDROID_HOME" \
  "platform-tools" "platforms;android-$API" "build-tools;$BUILD_TOOLS" \
  "ndk;$NDK" "emulator" "$IMAGE" \
  "platforms;android-35" "cmake;3.22.1" \
  | tr '\r' '\n' | grep -vE '^\[|^ *$' || true
# (android-35 y CMake los pide algún plugin; Gradle los instalaría solo.)

if [ "${1:-}" = "--avd" ] && [ ! -d "$ANDROID_AVD_HOME/pst_pixel8.avd" ]; then
  echo "== AVD pst_pixel8 =="
  echo no | avdmanager create avd -n pst_pixel8 -k "$IMAGE" -d pixel_8
fi

rm -rf "$A/dl" # descargas ya descomprimidas

echo "== Espacio =="
du -sh "$A"/jdk "$A"/sdk "$A"/avd "$A"/gradle 2>/dev/null || true
