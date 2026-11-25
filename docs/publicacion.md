# Publicación en tiendas: auditoría técnica

Revisión del proyecto (noviembre de 2026)
para **App Store (iOS/iPadOS)**, **Mac App Store** y **Google Play**. Lista lo
que falta o choca técnicamente, con el archivo y la corrección propuesta.

> No es asesoramiento legal. Los requisitos de las tiendas cambian: confirma
> en App Store Connect y Play Console las fechas y tamaños vigentes antes de
> enviar.

Gravedad: 🔴 **bloqueante** (la subida o la revisión fallan, o la app no
funciona) · 🟠 **importante** (hace falta antes de publicar, pero no rompe el
build) · 🟢 **menor**.

## Resumen

| Tienda | Bloqueantes abiertos | Ya corregido en esta revisión |
|---|---|---|
| Google Play | Firma de subida, ficha (capturas, gráfico, icono), Data safety, cuenta | Permiso `INTERNET` en release; `apkanalyzer` con rutas con espacios |
| App Store (iOS) | Cuenta/firma, capturas de 6,9" e iPad, export compliance | Privacy Manifest, `CFBundleLocalizations`, `NSPhotoLibraryUsageDescription` |
| Mac App Store | Cuenta/firma (equipo en el target macOS), categoría | `network.client` en el sandbox, `CFBundleLocalizations` |

## Builds de comprobación

| Build | Comando | Resultado |
|---|---|---|
| Android AAB | `flutter build appbundle --release` (con `tool/android_env.sh`) | ✅ `app-release.aab`, 82,1 MB (tres ABI + símbolos nativos). Firmado con la **clave debug** (no válido para Play). Descarga estimada en arm64: ~15 MB comprimidos (31,5 MB instalados). |
| iOS sin firma | `flutter build ios --config-only --release --no-codesign` + `xcodebuild … -sdk iphoneos archive CODE_SIGNING_ALLOWED=NO -derivedDataPath .scratch/…` | ✅ `Runner.xcarchive` (`Runner.app` 29 MB) con `PrivacyInfo.xcprivacy` de la app, de Flutter y de file_picker. |
| macOS | `flutter build macos --release` | ✅ `PKArkTools.app` 68,1 MB, firma *ad hoc* con `app-sandbox`, `network.client`, `files.user-selected.read-write`, `files.bookmarks.app-scope`. |

Sobre `flutter build ipa --no-codesign`: genera el mismo `.xcarchive` pero
**no puede producir un `.ipa`** sin firma (la exportación del archivo requiere
un certificado y un perfil de distribución). El `.ipa` sin firmar para
AltStore de cada release lo empaqueta el job `ios-ipa` de
`.github/workflows/ci.yml` a mano: `flutter build ios --release --no-codesign`
y `Payload/Runner.app` comprimido como `PKArkTools-vX.Y.Z-ios-unsigned.ipa`
(AltStore lo firma con el Apple ID del usuario). Se usó el `xcodebuild archive`
equivalente para fijar `-derivedDataPath` dentro de `.scratch/` y no escribir
en `~/Library`. Con cuenta de desarrollador: `flutter build ipa --release
--export-method app-store`.

Comprobaciones del AAB: `minSdk 24`, `targetSdk 36`, `compileSdk 36`; ABI
`arm64-v8a`, `armeabi-v7a`, `x86_64` (64 bits ✅); todas las `.so`
(`libapp`, `libflutter`, `libsqlite3`, `libdartjni`) con segmentos `LOAD`
alineados a ≥ 16 KB ✅ (requisito de Play para apps con `targetSdk` ≥ 35);
R8 activo con `proguard.map` y símbolos nativos dentro del bundle ✅.

## Identificadores, versión y nombre

| Plataforma | Identificador | Versión / build | Nombre visible | Archivo |
|---|---|---|---|---|
| Android | `applicationId` y `namespace` `dev.pkarktools.app` | `0.1.0` / `versionCode 1` (de `pubspec.yaml`) | `PKArkTools` | `apps/pkarktools/android/app/build.gradle.kts`, `AndroidManifest.xml` |
| iOS | `dev.pkarktools.app` (equipo `3HCX57BN86`) | `0.1.0` / `1` | `PKArkTools` (`CFBundleDisplayName`); `CFBundleName` = `pkarktools` | `ios/Runner.xcodeproj/project.pbxproj`, `ios/Runner/Info.plist` |
| macOS | `dev.pkarktools.app` (sin equipo) | `0.1.0` / `1` | `PKArkTools` | `macos/Runner/Configs/AppInfo.xcconfig` |

| # | Gravedad | Hallazgo | Corrección propuesta |
|---|---|---|---|
| ID-1 | 🟠 | El identificador sigue el valor de la plantilla (`dev.pkarktools.app`, con un `TODO` en `build.gradle.kts`). Es **permanente** una vez publicado en cada tienda. | Decisión del owner. No se cambió. Elegir un identificador definitivo de un dominio que controle (p. ej. `io.github.<usuario>.<app>`) antes de la primera subida. |
| ID-2 | 🟠 | Una marca de terceros en el nombre o en el identificador puede chocar con las políticas de propiedad intelectual de ambas tiendas (uso de marcas de terceros en el nombre de la app). | Decisión del owner: nombre sin marcas de terceros. |
| ID-3 | 🟢 | Versión `0.1.0+1`. Ambas tiendas exigen que el número de build aumente en cada subida. | Subir `version:` en `apps/pkarktools/pubspec.yaml` (p. ej. `1.0.0+1`) y aumentar el `+N` en cada envío. |
| ID-4 | 🟢 | `CFBundleName` = `pkarktools` (minúsculas) en `ios/Runner/Info.plist`. Se ve en algunos lugares del sistema. | Cambiar a `$(PRODUCT_NAME)` o al nombre final. |

## Google Play

| # | Gravedad | Hallazgo | Archivo | Corrección |
|---|---|---|---|---|
| GP-1 | 🔴 ✅ corregido | El manifest **release** no pedía `INTERNET` (solo el de `debug`): en las builds de tienda la descarga de iconos fallaba siempre. | `android/app/src/main/AndroidManifest.xml` | Añadido `<uses-permission android:name="android.permission.INTERNET"/>`. Verificado en el manifest fusionado del AAB. |
| GP-2 | 🔴 preparado | La build release se firmaba siempre con la **clave debug**. Play rechaza bundles firmados con la clave de depuración. | `android/app/build.gradle.kts`, `.github/workflows/ci.yml` | `build.gradle.kts` ya lee un keystore de release desde variables de entorno (secretos de GitHub `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `ANDROID_STORE_PASSWORD`) o desde `android/key.properties`, con la clave debug como respaldo ([Firma de Android](desarrollo.md#firma-de-android)). Falta que el owner cree la clave de subida, la guarde fuera del repo, cargue los secretos y active **Play App Signing**. |
| GP-3 | 🔴 | Cuenta de Play Console (pago único). Las **cuentas personales nuevas** deben pasar una prueba cerrada con al menos 12 testers durante 14 días antes de poder publicar en producción. | — | Owner: crear la cuenta, completar la verificación de identidad y planificar la prueba cerrada. |
| GP-4 | 🔴 | **Data safety** (formulario obligatorio). | Play Console | Declarar: **no se recogen ni se comparten datos**; no hay cuentas; los datos viajan cifrados (HTTPS) en la única conexión (iconos desde `raw.githubusercontent.com`, sin datos del usuario); la eliminación de datos no aplica (todo es local). La copia de seguridad automática de Android no cuenta como recogida del desarrollador. |
| GP-5 | 🔴 | **Ficha de la tienda**: faltan el icono de 512×512, el gráfico de funciones de 1024×500 y capturas válidas. Las capturas Android actuales (`docs/screenshots/android/v2_*`, 1080×2400) **superan la proporción 2:1** que admite Play (2400/1080 = 2,22). | `docs/screenshots/android/` | Generar capturas de teléfono con proporción ≤ 2:1 (p. ej. 1080×1920 o 1080×2160; mínimo 2, recomendado 4–8) y, como hay diseño de tablet, capturas de tablet de 7" y 10". Icono 512×512 desde el logo con `tool/gen_branding.py`. |
| GP-6 | 🟠 | Cuestionario de **clasificación de contenido** (IARC), **público objetivo** (no dirigida a menores) y **declaración de anuncios** (no tiene). | Play Console | Owner. |
| GP-7 | ✅ | `targetSdk 36` / `compileSdk 36` (valores de Flutter 3.47). Cumple el requisito de API objetivo vigente de Play. | `build.gradle.kts` (`flutter.targetSdkVersion`) | Ninguna. Revisar cada año en agosto, cuando Play sube el mínimo. |
| GP-8 | ✅ | **Almacenamiento**: no se usa `MANAGE_EXTERNAL_STORAGE` ni `READ/WRITE_EXTERNAL_STORAGE`; todo va por **SAF** (`ACTION_OPEN_DOCUMENT_TREE` + `takePersistableUriPermission`, `DocumentsContract`) en `MainActivity.kt` y `file_picker`. Es lo que Play espera; `MANAGE_EXTERNAL_STORAGE` exige una declaración especial que esta app no justificaría. | `MainActivity.kt`, manifest fusionado | Ninguna. No añadir ese permiso. |
| GP-9 | 🟠 | **`Android/data` de otras apps** (ports de emuladores de Switch que guardan en `Android/data/<paquete>/files/…`): desde Android 11 el selector SAF **no permite** elegir `Android/data` ni sus subcarpetas, y en Android 13+ se cerraron los atajos que había. `MANAGE_EXTERNAL_STORAGE` tampoco da acceso a `Android/data`. | `docs/usuario/importar.md` | Documentado para el usuario. Alternativas válidas: (1) el emulador expone su carpeta con su propio `DocumentsProvider` (aparece en la barra lateral del selector), (2) la función de exportar/importar saves del emulador hacia una carpeta normal, (3) copiar por USB/PC. Opcional en la app: un intent «Compartir/Abrir con» (`ACTION_SEND`/`ACTION_VIEW` de archivos) para recibir saves exportados por otras apps. Shizuku o accesos root quedan fuera de las políticas. |
| GP-10 | ✅ | **64 bits** y **páginas de 16 KB**: ver «Builds de comprobación». | — | Ninguna. |
| GP-11 | 🟢 | **Tamaño**: AAB 82 MB (incluye 3 ABI y símbolos de depuración); Play entrega APK por ABI (~15 MB de descarga en arm64). | — | Opcional: `flutter build appbundle --obfuscate --split-debug-info=…` reduce `libapp.so` y guarda los símbolos de Dart aparte. |
| GP-12 | 🟢 | **Copia de seguridad automática** activa por defecto (`allowBackup` no se fija): el índice drift, la caché de iconos (si cabe) y una carpeta local del Arca podrían ir a la copia de Google. | `AndroidManifest.xml` | Añadir `android:dataExtractionRules`/`android:fullBackupContent` excluyendo caché e índice (se reconstruyen), o desactivar la copia. Decidir qué hacer con el Arca local de la app. |
| GP-13 | 🟢 | Sin `android:localeConfig` (idioma por app de Android 13+). | `AndroidManifest.xml`, `res/xml/locales_config.xml` | Añadir `locales_config.xml` con `es` y `en`. |
| GP-14 | 🟢 | Red: solo HTTPS a `raw.githubusercontent.com`; no hay tráfico en claro, así que no hace falta `networkSecurityConfig`. | `lib/data/sprites/sprite_cache.dart` | Ninguna. |
| GP-15 | 🟢 | **Verificación de desarrolladores de Android** (Google la está extendiendo a apps instaladas fuera de Play en dispositivos certificados). Afecta a distribuir el APK por otros canales (p. ej. releases de GitHub). | — | Owner: registrar el identificador y la clave en la consola de desarrollador cuando aplique en sus países. |

## App Store (iOS / iPadOS)

| # | Gravedad | Hallazgo | Archivo | Corrección |
|---|---|---|---|---|
| IOS-1 | 🔴 | **Cuenta y firma**: hace falta el Apple Developer Program (cuota anual), un registro de la app en App Store Connect con el *bundle id*, certificado de distribución y perfil (la firma automática los crea). El target ya tiene `DEVELOPMENT_TEAM = 3HCX57BN86` y `CODE_SIGN_STYLE = Automatic`. | `ios/Runner.xcodeproj/project.pbxproj` | Owner: confirmar que el equipo es el de la cuenta de pago y crear el registro. Después `flutter build ipa --release`. |
| IOS-2 | 🔴 ✅ corregido | **Privacy Manifest**: la app no tenía `PrivacyInfo.xcprivacy`. El código Dart usa `stat` (fechas de modificación de la carpeta del Arca y de la caché de iconos) y SQLite (índice), API de «motivo obligatorio» de la categoría *File timestamp*. | `ios/Runner/PrivacyInfo.xcprivacy` (añadido al target en el `.pbxproj`) | Añadido: sin seguimiento, sin datos recogidos, `NSPrivacyAccessedAPICategoryFileTimestamp` con `C617.1` (contenedor de la app) y `3B52.1` (archivos elegidos por el usuario). Flutter.framework y file_picker_darwin traen el suyo (verificado en el archivo). `sqlite3.framework` y `objective_c.framework` (frameworks de *native assets*) no traen manifiesto propio; su uso queda cubierto por el de la app. Al subir, revisar el informe de privacidad de Xcode (*Generate Privacy Report*). |
| IOS-3 | 🔴 ✅ corregido | El binario enlaza **Photos/PhotosUI** y referencia `PHPhotoLibrary` (por `file_picker`, aunque la app nunca elige fotos). App Store Connect rechaza binarios que referencian API protegidas sin su texto de uso (ITMS-90683). | `ios/Runner/Info.plist` | Añadido `NSPhotoLibraryUsageDescription` explicando que no se accede a las fotos. Alternativa futura: un selector de documentos propio sin Photos. |
| IOS-4 | 🟠 ✅ corregido | Sin `CFBundleLocalizations`: iOS y la tienda consideraban la app solo en inglés (`knownRegions = en`), aunque la UI está en español e inglés. | `ios/Runner/Info.plist` | Añadido `es` y `en`. Opcional: `InfoPlist.strings` por idioma para traducir los textos de uso. |
| IOS-5 | 🟠 | **Export compliance**: no hay `ITSAppUsesNonExemptEncryption`, así que App Store Connect preguntará en cada build. Hechos: la red usa HTTPS (TLS de BoringSSL incluido en el runtime de Dart); los saves usan SHA-256, SHA-1, MD5 y CRC (hash/integridad); `MemeCrypto` (`packages/pkcore/lib/src/crypto/meme_crypto.dart`) implementa **AES y RSA** solo para verificar y volver a firmar la firma del formato de save de Sol/Luna/USUM; `SwishCrypto` es un XOR con XorShift32 (ofuscación del formato). Nada de esto protege comunicaciones ni datos del usuario. | `ios/Runner/Info.plist` | Decisión del owner con esa información: si concluye que el uso está exento, añadir `ITSAppUsesNonExemptEncryption` = `false`. |
| IOS-6 | 🔴 | **Capturas de la tienda**: obligatorias las de iPhone de 6,9" (1320×2868 o 1290×2796) y, como la app es universal (`TARGETED_DEVICE_FAMILY = "1,2"`), las de iPad de 13" (2064×2752 o 2048×2732). Las existentes son de iPhone 16 Pro (1206×2622, 6,3") e iPhone SE (750×1334); no hay de iPad. | `docs/screenshots/ios/` | Generar con el arnés `integration_test/phone_screenshots_test.dart` en simuladores iPhone 16/17 Pro Max e iPad Pro 13" (headless). O limitar la app a iPhone (decisión del owner: hoy el diseño de tablet existe). |
| IOS-7 | ✅ | **Iconos** sin canal alfa (todos los PNG de `AppIcon.appiconset`, incluido el de 1024×1024). | `ios/Runner/Assets.xcassets/AppIcon.appiconset/` | Ninguna. |
| IOS-8 | ✅ | `UIFileSharingEnabled` y `LSSupportsOpeningDocumentsInPlace` = `true`: la carpeta Documentos (Arca local de la app y la migración antigua) se ve en Archivos. El índice está en *Application Support* (no visible). No se declaran tipos de documento propios (`CFBundleDocumentTypes`/UTI): la app no abre archivos desde otras apps. | `ios/Runner/Info.plist` | Opcional: declarar UTI importados (`.sav`, `.pk*`…) si se quiere «Abrir con PKArkTools» desde Archivos. |
| IOS-9 | ✅ | *Deployment target* iOS 15.0. | `project.pbxproj` | Ninguna. |
| IOS-10 | 🟠 | **Revisión**: la app permite modificar partidas de juegos de terceros y usa nombres de marcas de terceros; es motivo frecuente de preguntas en revisión (guía 5.2 de propiedad intelectual). | Ficha y nombre | Owner: nombre y capturas sin marcas de terceros, descripción clara de «herramienta de copias de seguridad de tus propias partidas», sin sprites en el icono. |
| IOS-11 | 🟢 | Sin `ITSAppUsesNonExemptEncryption` ni `NSPrivacyCollectedDataTypes` de terceros: la **etiqueta de privacidad** de App Store Connect debe ser «Datos no recogidos». | App Store Connect | Owner. |

## Mac App Store

| # | Gravedad | Hallazgo | Archivo | Corrección |
|---|---|---|---|---|
| MAC-1 | 🔴 ✅ corregido | El sandbox de release no tenía `com.apple.security.network.client`: en la app firmada la descarga de iconos fallaba siempre (y tampoco en `DebugProfile`, que solo tenía `network.server`). | `macos/Runner/Release.entitlements`, `DebugProfile.entitlements` | Añadido `network.client` a ambos. Verificado en la firma de `flutter build macos`. |
| MAC-2 | ✅ | Sandbox, `files.user-selected.read-write` y `files.bookmarks.app-scope` (bookmarks con *security scope*) ya existen. | Entitlements | Ninguna. |
| MAC-3 | 🔴 | El target macOS **no tiene equipo** (`DEVELOPMENT_TEAM`) y la firma de la build local es *ad hoc* con `get-task-allow`. | `macos/Runner.xcodeproj/project.pbxproj` | Owner: asignar el equipo en Xcode (Signing & Capabilities) y archivar con firma de distribución (*Apple Distribution* + perfil Mac App Store), que quita `get-task-allow`. |
| MAC-4 | 🟠 | Falta `LSApplicationCategoryType` (categoría), que App Store Connect pide para apps de Mac. | `macos/Runner/Info.plist` | Decisión del owner (p. ej. `public.app-category.utilities`). |
| MAC-5 | 🟢 | Sin `PrivacyInfo.xcprivacy` en el target macOS (Apple lo exige en iOS; en macOS se recomienda). | `macos/Runner/` | Copiar el de iOS y añadirlo al target. |
| MAC-6 | 🟢 ✅ en CI | Sin *hardened runtime* explícito. No hace falta para la Mac App Store (basta el sandbox), sí para distribuir fuera con notarización. | `project.pbxproj` | El job `macos` del tag vuelve a firmar la app con Developer ID y *hardened runtime* y la notariza ([Firma y notarización de macOS](#firma-y-notarización-de-macos)). Falta que el owner cargue los secretos. |
| MAC-7 | ✅ | Capturas de 2880×1800 (`docs/screenshots/v2/mac_*`) válidas para la Mac App Store (16:10). Iconos con alfa: correcto en macOS. *Deployment target* 12.0; binario universal (arm64 + x86_64). | — | Ninguna. |

## Accesibilidad y localización

| # | Gravedad | Hallazgo | Corrección |
|---|---|---|---|
| A11Y-1 | 🟠 | Semántica parcial: 8 `Semantics`, 14 `tooltip`, 10 `semanticLabel` para ~10 `IconButton` y muchos iconos/sprites; los sprites de avatar tienen etiqueta, pero no todos los iconos de tipo, Ball o cinta. | Recorrido con TalkBack/VoiceOver y añadir `tooltip`/`semanticLabel` donde falten; tests con `meetsGuideline(labeledTapTargetGuideline)`, `androidTapTargetGuideline`, `iOSTapTargetGuideline` y `textContrastGuideline` en `test/`. |
| A11Y-2 | ✅ | Tamaño de texto: `test/phone_layout_test.dart` comprueba que no hay desbordes al 100 % y 130 % en 320×568, 360×800 y 430×932. | Ampliar a 200 % (mínimo recomendado por las guías de Android e iOS). |
| A11Y-3 | 🟢 | El color de versión del Arca no es la única señal (el nombre del juego va en texto). | Ninguna. |
| L10N-1 | ✅ | Español (plantilla) e inglés completos: 522 claves en cada `.arb`. | — |
| L10N-2 | 🟠 | Fichas de tienda (título, descripción, capturas) en es y en. | Owner. |

## Capturas de tienda: qué hay y qué falta

| Tienda | Requerido | Existe | Falta |
|---|---|---|---|
| App Store iPhone | 6,9": 1320×2868 o 1290×2796 (3–10) | 6,3" 1206×2622 y 4,7" 750×1334 | 🔴 6,9" |
| App Store iPad | 13": 2064×2752 o 2048×2732 (si la app es universal) | — | 🔴 todas |
| Mac App Store | 1280×800, 1440×900, 2560×1600 o 2880×1800 | 2880×1800 (`v2/mac_*`) | — |
| Google Play teléfono | 2–8, lado 320–3840 px, proporción ≤ 2:1 | 1080×2400 (2,22:1) | 🔴 recortar o regenerar |
| Google Play tablet 7"/10" | Recomendadas | — | 🟠 |
| Google Play gráficos | Icono 512×512, gráfico de funciones 1024×500 | — | 🔴 ambos |

Todas deben hacerse con **datos sintéticos** (como las actuales) y, por la
nota de propiedad intelectual, conviene que muestren lo menos posible de
sprites y logotipos de terceros.

## Licencia GPL-3 y tiendas

Hechos técnicos (sin opinión legal):

* Todo el proyecto se distribuye bajo **GPL-3.0** (`LICENSE`).
* `packages/pkcore` contiene **lógica portada de PKHeX.Core** (GPL-3.0,
  © Kaphotics y colaboradores): cifrados de saves y de Pokémon, detección y
  offsets, checksums, estructuras PK1–PA9, escritura de saves, Pokédex,
  eventos, legalidad y tablas generadas desde `PKHeX.Core/Resources`. Detalle
  en [`NOTICE`](../NOTICE) y [Licencias](licencias.md). Es la razón por la que
  el proyecto es GPL-3.0 y no puede relicenciarse sin el permiso de los
  autores de PKHeX.
* El resto de dependencias son BSD-3-Clause, MIT, dominio público (SQLite) u
  OFL (fuentes), compatibles con la GPL.
* Existe un **conflicto conocido y documentado públicamente** entre la GPL y
  los términos de uso de la App Store de Apple (restricciones de uso y
  redistribución que la GPL no permite añadir). Por ese motivo, apps GPL se han
  retirado de la App Store en el pasado cuando un titular de derechos lo
  pidió. Para Google Play no se conoce un conflicto equivalente; la GPL exige
  ofrecer el código fuente correspondiente a cada binario publicado.
* El **logo** es propiedad del autor y el repositorio no indica su licencia
  por separado; las tiendas no exigen nada al respecto, pero conviene dejarlo
  explícito en `NOTICE` si el código se publica.
* Los **sprites** no se empaquetan (se descargan de GitHub en tiempo de
  ejecución); el binario no contiene arte de Nintendo/Game Freak/TPC.

## Qué se corrigió en esta revisión

| Cambio | Archivos |
|---|---|
| Permiso `INTERNET` en el manifest principal (iconos en release) | `apps/pkarktools/android/app/src/main/AndroidManifest.xml` |
| `network.client` en el sandbox de macOS | `apps/pkarktools/macos/Runner/Release.entitlements`, `DebugProfile.entitlements` |
| Privacy Manifest de iOS añadido al target | `apps/pkarktools/ios/Runner/PrivacyInfo.xcprivacy`, `project.pbxproj` |
| `CFBundleLocalizations` (es, en) en iOS y macOS | `ios/Runner/Info.plist`, `macos/Runner/Info.plist` |
| `NSPhotoLibraryUsageDescription` (Photos enlazado por file_picker) | `ios/Runner/Info.plist` |
| Parche de `apkanalyzer` para rutas con espacios (sin él, `flutter build appbundle` acababa en error) | `tool/android_setup.sh` |

## Firma y notarización de macOS

Fuera de la Mac App Store, Gatekeeper solo abre con doble clic una app
firmada con **Developer ID Application**, con *hardened runtime* y
**notarizada** por Apple. El job `macos` del workflow (solo en tags `v*` y
lanzamientos manuales) lo hace con `tool/macos_sign_notarize.sh`:

1. Importa el `.p12` en un llavero temporal del runner (se borra al terminar).
2. Firma de dentro hacia fuera: cada `.dylib` y `.framework` de
   `Contents/Frameworks` y después `PKArkTools.app` con
   `apps/pkarktools/macos/Runner/Release.entitlements` (sandbox,
   `network.client`, `files.user-selected.read-write`,
   `files.bookmarks.app-scope`), `--options runtime` y sello de tiempo.
3. `xcrun notarytool submit --wait` con la clave de la API y
   `xcrun stapler staple` de la app.
4. Sube `PKArkTools-vX.Y.Z-macos.zip` (el que descarga el actualizador de la
   app) y `PKArkTools-vX.Y.Z-macos.dmg`, firmado, notarizado y grapado.
5. Comprueba con `spctl --assess` la app y el DMG.

Sin `MACOS_CERT_P12_BASE64` el job hace lo de antes (zip con firma *ad hoc*)
y lo avisa; sin la clave de la API firma pero no notariza. Ningún secreto
que falte hace fallar el CI.

### Qué tiene que hacer el owner (una vez)

Hace falta estar en el **Apple Developer Program** (de pago).

1. **Solicitud de certificado (CSR).** En el Mac: *Acceso a Llaveros →
   Asistente para certificados → Solicitar un certificado de una autoridad
   de certificación…*, con tu correo y nombre, «Guardado en el disco».
2. **Certificado Developer ID Application.** En
   [developer.apple.com](https://developer.apple.com/account/resources/certificates/list)
   → *Certificates* → **+** → *Developer ID Application* (perfil G2 Sub-CA),
   sube el CSR, descarga el `.cer` y ábrelo con doble clic (queda en el
   llavero *Inicio de sesión*, junto a su clave privada).
3. **Exportar como `.p12`.** En *Acceso a Llaveros → Mis certificados*, clic
   derecho en «Developer ID Application: … (EQUIPO)» → *Exportar…* →
   formato `.p12`, con una contraseña fuerte.
4. **Clave de la API de App Store Connect.** En
   [App Store Connect](https://appstoreconnect.apple.com/access/integrations/api)
   → *Usuarios y acceso → Integraciones → App Store Connect API* → **+**, con
   el rol **Developer**. Descarga el `.p8` (solo se puede descargar una vez) y
   apunta el **Key ID** y el **Issuer ID** que aparecen en esa página.
5. **Team ID**: en [developer.apple.com → Membership](https://developer.apple.com/account#MembershipDetailsCard)
   (10 caracteres; también sale entre paréntesis en el nombre del certificado).
6. **Cargar los 6 secretos** (desde la carpeta donde estén los archivos):

   ```bash
   base64 -i DeveloperID.p12 | gh secret set MACOS_CERT_P12_BASE64 -R Rodriqe/PKArkTools
   gh secret set MACOS_CERT_PASSWORD -R Rodriqe/PKArkTools        # pide la contraseña del .p12
   base64 -i AuthKey_XXXXXXXXXX.p8 | gh secret set APPLE_API_KEY_P8_BASE64 -R Rodriqe/PKArkTools
   gh secret set APPLE_API_KEY_ID -R Rodriqe/PKArkTools           # Key ID
   gh secret set APPLE_API_ISSUER_ID -R Rodriqe/PKArkTools        # Issuer ID
   gh secret set APPLE_TEAM_ID -R Rodriqe/PKArkTools              # Team ID
   ```

   Si guardas un valor en un archivo de texto, también vale
   `gh secret set NOMBRE -R Rodriqe/PKArkTools < archivo`.
7. **Prueba**: *Actions → CI → Run workflow* sobre `main`. El log del paso
   *Sign, notarize and package* debe mostrar `Notarization of …: Accepted` dos
   veces y terminar con `spctl (app): accepted` y `spctl (DMG): accepted`. El
   log es público: el script no imprime el nombre del certificado, el Team
   ID, el Key ID ni el Issuer ID.

**El `.p12`, el `.p8` y sus contraseñas nunca van al repo.** Guárdalos en
`RESPALDO-PKArkTools` (excluida de git) y en tu gestor de contraseñas. Si se
pierde el `.p8` se crea otra clave y se revoca la vieja; si se filtra el
`.p12`, revoca el certificado en developer.apple.com.

## Qué requiere decisión o cuentas del owner

1. Nombre definitivo y **identificadores** (bundle id / applicationId) antes
   de la primera subida (ID-1, ID-2).
2. **Cuentas**: Apple Developer Program (equipo para iOS y macOS) y Google
   Play Console (verificación y prueba cerrada de 14 días con 12 testers si la
   cuenta es personal y nueva).
3. **Clave de subida** de Android y dónde custodiarla; activar Play App
   Signing (GP-2).
4. **Export compliance** de Apple (IOS-5).
5. Categoría de la Mac App Store (MAC-4); iPad sí/no (IOS-6).
6. Copia de seguridad automática de Android (GP-12).
7. Postura sobre la **GPL y la App Store** y licencia del logo.
8. Fichas de tienda, capturas (ver tabla), clasificación de contenido,
   etiquetas de privacidad (Datos no recogidos) y Data safety.
