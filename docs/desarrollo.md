# Desarrollo

## Requisitos

| Herramienta | Versión probada | Para qué |
|---|---|---|
| Flutter (estable) | 3.47 / Dart 3.13 (SDK mínimo `^3.10`) | Todo |
| Xcode + CocoaPods/SwiftPM | Xcode 27 | iOS y macOS (SwiftPM activado en `pubspec.yaml`) |
| JDK, Android SDK, NDK | JDK 21, SDK 36, NDK 28.2, CMake 3.22.1 | Android (se instala dentro del proyecto) |
| Python 3 | 3.11+ | Generadores de `tool/` y verificación de enlaces |
| .NET SDK | 10 | Solo para el oráculo PKHeX (opcional) |

## Regla del workspace

Todo lo que genera el desarrollo vive **dentro del proyecto** y fuera de git:

| Carpeta | Contenido |
|---|---|
| `.pub-cache/` | Caché de paquetes (`PUB_CACHE`) |
| `.ref/` | Entorno Android, clon de PKHeX, saves reales opcionales (`.ref/real-saves/`), logo original (`.ref/branding/`) |
| `.scratch/` | Temporales (`TMPDIR`), salidas del oráculo, DerivedData, APK/AAB copiados |

Nunca se lanza la app de escritorio para probarla o capturarla (nada de
`flutter run -d macos`, `flutter drive -d macos` ni `open`): todo es headless.
No uses `flutter config` (escribe en tu *home*).

## Primeros pasos

```bash
export PUB_CACHE="$PWD/.pub-cache"
flutter pub get                 # resuelve el workspace (pkcore + app)
tool/ci.sh                      # análisis + tests + enlaces (+ APK debug si hay entorno Android)
```

En la app, **Probar con partidas de ejemplo** genera saves sintéticos válidos
(`pkcore/lib/src/testing/synthetic.dart`), así que no hace falta ningún save
real para desarrollar.

## CI local: `tool/ci.sh`

1. `flutter pub get`
2. `pkcore`: `dart analyze --fatal-infos` y `dart test`
3. App: `flutter analyze --fatal-infos` y `flutter test`
4. Documentación: `python3 tool/check_links.py` (enlaces relativos, anclas e
   imágenes de todos los `.md`)
5. Si existe `.ref/android/sdk`: `flutter build apk --debug` (`CI_ANDROID=0` lo
   omite)

Los temporales de los tests (`Directory.systemTemp`) van a `.scratch/tmp`.

## Entorno Android dentro del proyecto

```bash
tool/android_setup.sh --avd      # JDK Temurin 21, cmdline-tools, platform-tools,
                                 # platforms;android-36 (+35), build-tools 36.0.0,
                                 # NDK 28.2, CMake 3.22.1, emulador, imagen
                                 # google_apis arm64-v8a (API 36) y AVD pst_pixel8
source tool/android_env.sh       # JAVA_HOME, ANDROID_HOME, GRADLE_USER_HOME,
                                 # PUB_CACHE, TMPDIR, JAVA_TOOL_OPTIONS (user.home)…
cd apps/pkarktools
flutter build apk --release      # clave debug, o la de release si está configurada (abajo)
flutter build appbundle --release
cd ../..
tool/android_smoke.sh            # emulador headless + recorrido + capturas
```

Ocupa ~17 GB en `.ref/android/`. Notas:

* **Rutas con espacios** (p. ej. un volumen externo con espacios en el nombre): `flutter doctor`
  marca el SDK con ✗ porque `ndk-build` falla con espacios; este proyecto no lo
  usa y compila igual. Los lanzadores de `sdkmanager`, `avdmanager` y
  `apkanalyzer` también se rompen con espacios: `android_setup.sh` los parchea
  (sin el parche de `apkanalyzer`, `flutter build appbundle` genera el AAB pero
  termina con «failed to strip debug symbols»).
* El emulador se arranca con `-no-window -no-audio -gpu swiftshader_indirect`.

`tool/android_smoke.sh` instala el APK release en `pst_pixel8` y recorre la UI
real con `uiautomator`: onboarding con el selector SAF real, permiso
persistente, partidas de ejemplo, editor, guardado en el Arca, Pokédex,
reindexado por SAF, tema claro y arranque en frío. Deja capturas en
`docs/screenshots/android/`.

## CI en GitHub (`.github/workflows/ci.yml`)

| Job | Cuándo | Qué hace |
|---|---|---|
| `test` | siempre | Análisis, tests y enlaces (lo mismo que `tool/ci.sh`). En tags, comprueba también que el tag coincide con `pubspec.yaml` y que el CHANGELOG tiene su sección. |
| `android` | siempre | `flutter build apk --release` → `PKArkTools-<ref>.apk`. |
| `windows` | siempre | `flutter build windows --release` → zip portátil (`PKArkTools.exe`, DLL y `data/`) e instalador de Inno Setup (`windows/packaging/PKArkTools.iss`). |
| `linux` | siempre | `flutter build linux --release` → `tar.gz` con la carpeta `PKArkTools/`. |
| `macos` | tags `v*` y ejecución manual | `flutter build macos --release` → zip de `PKArkTools.app`. |
| `release` | tags `v*` | Borrador de GitHub Release con todos los binarios y las notas de `tool/release_notes.py`. |

En pushes y pull requests los binarios quedan como *artifacts* 7 días: sirven
para comprobar que todas las plataformas compilan. **Windows y Linux solo se
validan así** (compilación en la CI); no se han probado en un PC real.

### Firma de Android

`android/app/build.gradle.kts` firma el release con un keystore propio si
encuentra los cuatro datos, y si no con la **clave debug** (avisándolo en el
log; vale para probar, no para Google Play ni para actualizar una instalación
firmada con otra clave). Los busca primero en variables de entorno y después
en `apps/pkarktools/android/key.properties` (ignorado por git):

| Variable de entorno | `key.properties` | Secreto de GitHub |
|---|---|---|
| `ANDROID_KEYSTORE_PATH` | `storeFile` (ruta absoluta o relativa a `android/app/`) | `ANDROID_KEYSTORE_BASE64` (el `.jks` en base64; el workflow lo decodifica y fija la ruta) |
| `ANDROID_STORE_PASSWORD` | `storePassword` | `ANDROID_STORE_PASSWORD` |
| `ANDROID_KEY_ALIAS` | `keyAlias` | `ANDROID_KEY_ALIAS` |
| `ANDROID_KEY_PASSWORD` | `keyPassword` | `ANDROID_KEY_PASSWORD` |
| `ANDROID_STORE_TYPE` (opcional) | `storeType` (`PKCS12` o `JKS`) | — (el workflow usa `PKCS12`) |

Para configurarlo (una vez, y **guarda el keystore y las contraseñas fuera del
repo**: si se pierden no se pueden publicar actualizaciones con la misma
firma):

```bash
keytool -genkey -v -storetype PKCS12 -keystore pkarktools-release.p12 -keyalg RSA \
  -keysize 2048 -validity 10000 -alias pkarktools
base64 -i pkarktools-release.p12 | pbcopy        # macOS; en Linux: base64 -w0 …
```

En GitHub: *Settings → Secrets and variables → Actions → New repository
secret* con los cuatro nombres de la tabla. El job `android` decodifica el
keystore (PKCS12) a un temporal del runner, escribe
`android/key.properties` con `storeType=PKCS12` y los borra al terminar. Sin secretos (por ejemplo en pull
requests de forks) el APK sale con la clave debug y el job lo avisa.

## Cómo publicar un release

1. **Versión**: sube `version:` en `apps/pkarktools/pubspec.yaml`
   (`X.Y.Z+N`; el `+N` es el `versionCode` de Android y el build de iOS/macOS
   y debe crecer siempre). La primera es `0.1.0+1`.
2. **CHANGELOG**: añade `## [X.Y.Z] — AAAA-MM-DD` arriba con lo que incluye,
   **en inglés**, en `CHANGELOG.md`. Esa sección es el texto del Release
   (`tool/release_notes.py` le añade *Downloads* y el descargo). Añade la
   misma sección traducida en `CHANGELOG.es.md`: se actualizan a la par.
3. **README**: actualiza la versión de la sección *Install* / *Instalar* (y los
   nombres de archivo) en `README.md` y `README.es.md`.
4. Comprueba en local: `tool/ci.sh` en verde y
   `python3 tool/release_notes.py vX.Y.Z` (falla si el tag no coincide con el
   `pubspec.yaml` o falta la sección del CHANGELOG). Para regenerar las notas
   de un release ya publicado: `--any-version vX.Y.Z salida.md`.
5. Commit en `main` y **tag**: `git tag -a vX.Y.Z -m "PKArkTools X.Y.Z"` y
   `git push origin main vX.Y.Z`.
6. El workflow compila Android, Windows, Linux y macOS y crea un **borrador**
   de Release `PKArkTools vX.Y.Z` con las notas en inglés y los binarios:
   `PKArkTools-vX.Y.Z.apk`, `…-macos.zip`, `…-windows-x64-setup.exe`,
   `…-windows-x64.zip` y `…-linux-x64.tar.gz`.
7. Revisa el borrador en GitHub (*Releases*), descarga al menos el APK y la app
   de macOS para probarlos y pulsa **Publish release**.

Idioma: las notas del Release, `CHANGELOG.md` y los mensajes de commit van
en **inglés**; `CHANGELOG.es.md` es su traducción y se actualiza en el mismo
commit. La documentación de `docs/` sigue en español.

Checklist antes de publicar:

- [ ] `version:` del `pubspec.yaml` = tag sin la `v`; `+N` mayor que el anterior.
- [ ] Sección en `CHANGELOG.md` (inglés) y `CHANGELOG.es.md` con fecha y
      contenido; README con la versión nueva.
- [ ] `tool/ci.sh` en verde; todos los jobs del tag en verde.
- [ ] APK firmado con el keystore de release (el log de `android` no avisa de
      la clave debug) si el release es para usuarios.
- [ ] APK instalado en un teléfono y app de macOS abierta con clic derecho →
      Abrir; capturas y enlaces de la documentación sin errores
      (`tool/check_links.py`).
- [ ] Windows/Linux: si nadie los ha probado en un PC, el texto del Release lo
      dice (ya viene en las notas).

## Generadores de `tool/`

Las tablas de `packages/pkcore/lib/src/data/generated/` y el índice de iconos
se generan; no se editan a mano.

```bash
python3 tool/gen_species_data.py <csv_de_pokeapi> packages/pkcore/lib/src/data/generated/species_data.dart
python3 tool/gen_charsets.py <PKHeX.Core/PKM/Strings> packages/pkcore/lib/src/data/generated/charsets.dart
python3 tool/gen_game_data.py <PKHeX.Core> packages/pkcore/lib/src/data/generated     # movimientos, objetos, habilidades, stats, learnsets
python3 tool/gen_event_labels.py <PKHeX.Core> packages/pkcore/lib/src/data/generated/event_labels.dart
python3 tool/gen_dex_data.py <PKHeX.Core> packages/pkcore/lib/src/data/generated/dex_data.dart
python3 tool/gen_encounter_data.py <PKHeX.Core> <pokemon_species.csv> packages/pkcore/lib/src/data/generated/encounter_data.dart
python3 tool/gen_ribbon_data.py <PKHeX.Core> packages/pkcore/lib/src/data/generated/ribbon_data.dart
python3 tool/gen_sprite_manifest.py <clon de PKHeX> apps/pkarktools/lib/data/sprites/sprite_manifest.g.dart   # commit fijo
.scratch/venv/bin/python tool/gen_branding.py .ref/branding/logo-transparente.png    # iconos de todas las plataformas (Pillow, numpy, scipy)
python3 tool/l10n_add.py …        # añade una clave a app_es.arb y app_en.arb
```

`<PKHeX.Core>` es `.ref/PKHeX/PKHeX.Core` (clon de
https://github.com/kwsch/PKHeX). Tras regenerar, `tool/ci.sh` debe seguir en
verde.

## Oráculo PKHeX

`tools/pkhex_oracle` es una consola .NET que carga un save con PKHeX.Core y lo
vuelca a JSON con el mismo esquema que `packages/pkcore/tool/pkhex_dump.dart`.

```bash
git clone https://github.com/kwsch/PKHeX .ref/PKHeX     # una vez
tool/compare_with_pkhex.sh <save> [--legality-detail]
```

Compara campo por campo entrenador, equipo, cajas, inventario, Pokédex y el
veredicto de legalidad. Los JSON se escriben en `.scratch/compare/` (contienen
datos personales del save: nunca se versionan). Cada discrepancia encontrada se
convierte en un test con **datos sintéticos** (ver
`packages/pkcore/test/legality_pkhex_oracle_test.dart`). Comandos extra de la
consola: `roundtrip <save>` y `edit <in> <out>`.

## Tests con saves reales (opcionales)

Si existen saves en `.ref/real-saves/` (p. ej. `Pokemon Soul Silver.sav`,
`sword/main`), `packages/pkcore/test/real_saves_test.dart` los lee, comprueba
ida y vuelta y que la legalidad no dé falsos positivos. Si no existen, esos
grupos se marcan como *skip*. Nunca se versionan saves reales ni sus
capturas.

`integration_test/real_save_screenshots_test.dart` permite capturar la app
con un save real, pero sus salidas van a `.scratch/` y no se publican.

## Capturas

Todas usan un `MemoryFolderFs` y datos sintéticos: no escriben en disco ni
contienen datos reales. Las del repo van **en inglés** (el idioma por
defecto de los arneses); `--dart-define=SHOTS_LANG=es` las saca en español y
`SHOTS_OUT` (define en los tests offscreen, variable de entorno del driver en
los de dispositivo) cambia la carpeta de salida, por ejemplo a un kit fuera
del repo.

| Destino | Cómo | Salida |
|---|---|---|
| Guía de usuario (offscreen) | `flutter test test/guide_screenshots_test.dart --dart-define=SHOTS_GUIDE=true` — varios tamaños de ventana | `docs/screenshots/NN_*` |
| Escritorio (offscreen) | `flutter test test/desktop_screenshots_test.dart --dart-define=SHOTS_DESKTOP=true` — 1440×900 a 2×, fuentes reales, `RepaintBoundary.toImage`, sin ventana | `docs/screenshots/v2/mac_*` |
| Android (emulador headless) | `flutter drive -d emulator-5554 --driver test_driver/screenshot_driver.dart --target integration_test/features_screenshots_test.dart --dart-define=SHOTS=android/v2` (emulador con `-no-window`; con otro dispositivo conectado, indica siempre `-d`) | `docs/screenshots/android/` |
| Actualizar (escritorio, offscreen) | `flutter test test/update_screenshots_test.dart --dart-define=SHOTS_UPDATE=true` | `docs/screenshots/v2/mac_46_update.png` |
| Actualizar (Android, release real) | `flutter drive -d emulator-5554 --driver test_driver/screenshot_driver.dart --target integration_test/update_test.dart` (simula la 0.1.0 frente al último release de GitHub: descarga el APK, lee las firmas con PackageManager y comprueba que con la clave debug **se bloquea**; luego el camino feliz con un lector de firmas falso). Con `--dart-define=UPDATE_STEP=permission` y sin «Instalar apps desconocidas» captura la explicación del permiso; sin esa define hay que concederlo (`adb -s emulator-5554 shell appops set dev.pkarktools.app REQUEST_INSTALL_PACKAGES allow`) en cuanto se instala | `docs/screenshots/android/v2_47…51_update_*` |
| Dex (offscreen) | `flutter test test/dex_screenshots_test.dart --dart-define=SHOTS_DEX=true` — Dex sintética de `test/dex_demo.dart`, escritorio y teléfono | `docs/screenshots/dex/` |
| Dex (emulador / simulador) | `flutter drive -d DISPOSITIVO --driver test_driver/screenshot_driver.dart --target integration_test/dex_screenshots_test.dart --dart-define=SHOTS=android/dex` (o `ios/dex`) | `docs/screenshots/{android,ios}/dex_*` |
| iOS (simulador headless) | el mismo `features_screenshots_test.dart` con `--dart-define=SHOTS=ios/v2_pro` en un iPhone 16 Pro arrancado con `simctl boot` (con poco disco: compila antes con `xcodebuild -derivedDataPath .scratch/dd` y usa `--use-application-binary`) | `docs/screenshots/ios/` |

Ejemplo del kit en español: `flutter test test/desktop_screenshots_test.dart
--dart-define=SHOTS_DESKTOP=true --dart-define=SHOTS_LANG=es
--dart-define=SHOTS_OUT=../../.scratch/kit/es`. El simulador se arranca sin
abrir Simulator.app. Solo se versionan las capturas que enlaza algún `.md`, y
a las del simulador de iOS se les quitan los bloques `eXIf`/`iDOT` (sin
pérdida).

## Vídeo de demostración

`docs/media/pkarktools-demo.mp4` (inglés, 1920×1080) y su vista previa
animada `docs/media/pkarktools-demo.webp` (600 px, la que muestra el README)
se reconstruyen en dos pasos, sin abrir ventanas en el Mac:

1. **Tomas**: `tool/record_demo_video.sh en` (y `es`) ejecuta
   `integration_test/demo_video_test.dart` en perfil en el emulador headless
   (`emulator-5554`, Pixel 8 1080×2400, tema oscuro) y lo graba con
   `adb shell screenrecord`. La prueba importa partidas sintéticas a un Arca en
   memoria, precarga los iconos, dibuja un círculo en cada toque y marca cada
   escena con `DEMO_SCENE`; el script guarda la toma y los tiempos de las
   escenas en `.scratch/video/takes/`.
2. **Montaje**: `tool/make_demo_video.sh` recorta y acelera cada escena según
   esas marcas, la encaja en un marco de teléfono sobre el fondo de la marca
   con un rótulo en Manrope, añade la tarjeta de título y la de cierre con el
   logo, y une todo con fundidos. Sin música (pista AAC en silencio) y sin
   metadatos. Además de los archivos del repo, deja las versiones en español
   para redes (vertical 1080×1920 y cuadrada 1080×1080) en
   `.scratch/video/fb/`, fuera de git.

Necesita un ffmpeg estático con libx264, libfreetype y libwebp en
`.ref/ffmpeg/bin/` y las instancias estáticas de Manrope (OFL) en
`.ref/fonts/Manrope-{500,700,800}.ttf`; ambas rutas se pueden cambiar con
`FFMPEG`, `FFPROBE` y `FONTS`.

## Cómo añadir un juego o formato

1. **Datos**: si el juego trae especies, movimientos u objetos nuevos,
   actualiza los generadores de `tool/` y regenera las tablas.
2. **Modelo**: añade la versión a `GameVersion` (`pkcore/lib/src/model/game.dart`)
   con generación, plataforma, código y nombres es/en.
3. **Detección**: añade la regla en `SaveDetector.detect` (tamaño + firma +
   checksum). Debe ser inequívoca frente a los formatos existentes: añade un
   caso a `detector_test.dart`.
4. **Lectura**: un lector en `formats/` que produzca `SaveFile` (entrenador,
   equipo, cajas, inventario).
5. **Entidad**: si el Pokémon usa un formato nuevo, añade su `PkFormat` y la
   lectura/escritura en `pkm/`.
6. **Escritura**: un editor en `edit/` registrado en `SaveEditor.open`, con
   checksums en `util/checksums.dart` y `SaveVerifier` para diagnosticar daños.
7. **Sintéticos**: soporte en `testing/synthetic.dart`, para tests, capturas y
   partidas de ejemplo.
8. **Tests**: ida y vuelta (bytes idénticos), edición (cambio aplicado y
   checksums válidos), mutación en `robustness_test.dart` y, si hay save real,
   comparación con el oráculo PKHeX.
9. **App**: color de versión (`ui/common/cartridge.dart`/`version_chip.dart`),
   textos en los `.arb`, y documentación en [Formatos](formatos.md) y el
   [CHANGELOG](../CHANGELOG.md) (y [CHANGELOG.es.md](../CHANGELOG.es.md)).
10. **Créditos**: si portas código de PKHeX.Core, añádelo a `NOTICE` y a
    [Licencias](licencias.md).

## Convenciones de commits

* Mensajes en **español**, en una línea descriptiva que diga qué cambia y
  dónde; prefijo `pkcore:` para cambios solo del núcleo, `README:`/`Capturas:`
  para documentación y capturas.
* Commits pequeños por bloque (núcleo, app, tests, capturas, docs por
  separado). `tool/ci.sh` en verde antes de cada commit.
* Nunca se versionan saves reales, capturas con datos reales, salidas del
  oráculo, claves de firma ni nada de `.ref/` o `.scratch/`.
* Las ramas de trabajo siguen el patrón `<usuario>/<tema>` y se integran en
  `main`.
