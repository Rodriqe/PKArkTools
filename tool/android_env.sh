# Entorno Android contenido en el workspace (nada en ~).
#
#   source tool/android_env.sh
#
# Todo vive en .ref/android/ (ignorado por git): JDK, Android SDK, AVDs,
# caché de Gradle y estado de adb/emulador. Ver README, «Android».
# Se puede «sourcear» desde bash o zsh y desde cualquier carpeta.

if [ -n "${BASH_SOURCE[0]:-}" ]; then
  _pst_env_file="${BASH_SOURCE[0]}"
elif [ -n "${ZSH_VERSION:-}" ]; then
  # shellcheck disable=SC2296
  _pst_env_file="${(%):-%x}"
else
  _pst_env_file="$0"
fi
PST_WS="$(cd "$(dirname "$_pst_env_file")/.." && pwd)"
unset _pst_env_file
export PST_WS

export PST_ANDROID="$PST_WS/.ref/android"
export PUB_CACHE="$PST_WS/.pub-cache"

# JDK (Temurin) descomprimido en .ref/android/jdk/<versión>/Contents/Home.
_pst_jdk="$(ls -d "$PST_ANDROID"/jdk/*/Contents/Home 2>/dev/null | sort | tail -1)"
if [ -n "$_pst_jdk" ]; then
  export JAVA_HOME="$_pst_jdk"
fi
unset _pst_jdk

export ANDROID_HOME="$PST_ANDROID/sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export ANDROID_USER_HOME="$PST_ANDROID/user-home"
export ANDROID_EMULATOR_HOME="$ANDROID_USER_HOME"
export ANDROID_AVD_HOME="$PST_ANDROID/avd"
export GRADLE_USER_HOME="$PST_ANDROID/gradle"
# Kotlin daemon y temporales de Gradle/adb dentro del workspace.
mkdir -p "$PST_WS/.scratch/tmp" "$PST_WS/.scratch/home" "$ANDROID_USER_HOME" "$ANDROID_AVD_HOME" "$GRADLE_USER_HOME"
export TMPDIR="$PST_WS/.scratch/tmp"
# Cualquier JVM (Gradle, daemon de Kotlin, sdkmanager, avdmanager) ve como
# «home» una carpeta del workspace. Las comillas protegen rutas con espacios.
export JAVA_TOOL_OPTIONS="-Djava.io.tmpdir=\"$TMPDIR\" -Duser.home=\"$PST_WS/.scratch/home\""

_pst_path="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator"
[ -n "${JAVA_HOME:-}" ] && _pst_path="$JAVA_HOME/bin:$_pst_path"
export PATH="$_pst_path:$PATH"
unset _pst_path
