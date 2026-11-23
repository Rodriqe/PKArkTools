# Changelog

Todos los cambios relevantes del proyecto. El formato sigue
[Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y las versiones
[SemVer](https://semver.org/lang/es/). La primera versión publicada es
PKArkTools 0.1.0 (`0.1.0+1` en `apps/pkarktools/pubspec.yaml`); las secciones
que la siguen son los hitos internos de desarrollo que llevaron a ella.

## [Unreleased]

### Añadido
- **Última versión a la vista**: cada carpeta de entrenador del Arca tiene el
  archivo de la última versión con el nombre que usa el juego (`main` en
  Switch y 3DS, `SaveData.bin` en DBPR, `savedata.bin` en Let's Go,
  `<Juego>.sav`/`.dsv`/`.srm`… en GB, GBA y DS), un `ultima.json` derivado y
  las copias inmutables en `historial/`. El historial es la fuente de verdad:
  el principal se escribe de forma atómica (también por SAF) y se regenera
  desde él. Ver [El Arca › La carpeta por dentro](docs/usuario/arca.md#la-carpeta-por-dentro).
- **Principal cambiado a mano**: se detecta al reindexar (SHA-256 fuera del
  historial), nunca se pisa ni se borra y se ofrece **Guardar como nueva
  copia**.
- **Ficha de la partida**: «Versión actual · fecha» destacada con
  **Exportar** (con el nombre del juego) y **Abrir carpeta**; el historial
  queda plegado debajo. Ajustes del Arca explica la estructura.
- **Carpetas por juego (opcional)**: tras elegir la carpeta se pregunta una
  vez si crearlas (todos, elegir o ahora no); también en **Ajustes › Crear
  carpetas de juegos**, con selector por generación, plataforma o los juegos
  que ya tienes. Cada una lleva un `LEEME.txt` con qué save dejar.
- **Bandeja de entrada**: un save suelto en `PKArkTools/<Juego>/` se valida, se
  guarda como copia nueva de su entrenador (pasa a ser la última versión) y se
  retira tras verificar el hash; lo ilegible o de otro juego se queda con
  aviso y **Mover a <juego>**.
- **Demo video**: vídeo de demostración de 40 s
  ([`docs/media/pkarktools-demo.mp4`](docs/media/pkarktools-demo.mp4)) con
  vista previa animada al principio del README. Se graba en el emulador
  Android headless con partidas sintéticas
  (`integration_test/demo_video_test.dart`, `tool/record_demo_video.sh`) y se
  monta con ffmpeg (`tool/make_demo_video.sh`), también en versiones vertical
  y cuadrada en español para redes.

### Cambiado
- **Restaurar** crea una entrada nueva «Restaurada» en el historial y
  actualiza la última versión (el historial nunca se reescribe); escribir
  también en el archivo original es una opción del mismo diálogo.
- **Migración automática** de las carpetas de 0.1.0: las copias sueltas
  `fecha_hash.*` pasan a `historial/` verificando cada SHA-256 antes de retirar
  la original; idempotente y segura ante cortes. El `README.txt` de la raíz se
  actualiza.
- Las copias de conflicto de la nube del archivo principal (`main (1)`,
  `conflicted copy`) se retiran si su contenido ya está en el historial.
- Índice local (drift) a esquema 4: sin la restricción única
  `(partida, sha256)`.

## [0.1.0] — 2026-11-23

Primera versión publicada. Descargas en
[Releases](https://github.com/Rodriqe/PKArkTools/releases/tag/v0.1.0): APK de
Android, app de macOS (zip sin notarizar), Windows (instalador y zip
portátil, sin firmar) y Linux (tar.gz); iPhone/iPad compilando desde el
código. Las builds de Windows y Linux solo se han validado compilándolas en la
CI.

### Lo que incluye
- **Arca** de copias inmutables y verificadas (SHA-256) en la carpeta que
  elijas, multi-dispositivo mediante la nube, con historial, notas, comparar,
  restaurar, exportar y zip completo; filtros, orden y búsqueda.
- **Importar** archivos o carpetas enteras: emuladores de GB/GBA/DS y Switch
  (y sus ports de Android), volcados de cartucho y Checkpoint/JKSM; detección
  por contenido.
- **Lectura** de todos los juegos principales de Rojo/Azul a Leyendas Z-A.
- **Editor** con borrador y deshacer: Pokémon, cajas, entrenador, inventario,
  Pokédex, eventos, cintas y origen; Pokémon sueltos `.pk1`…`.pa9`.
- **Legalidad** con las reglas y tablas de encuentros de PKHeX y correcciones
  seguras; diagnóstico y reparación de checksums.
- Iconos bajo demanda, colores por versión, temas claro y oscuro, español e
  inglés. Android, iOS/iPadOS, macOS, Windows y Linux.

### Añadido
- Releases desde la CI: en cada tag `v*`, APK de Android (firmado con el
  keystore de los secretos de GitHub o, si no hay, con la clave debug), zip de
  macOS, instalador y zip de Windows y tar.gz de Linux, en un borrador de
  Release con las notas de este CHANGELOG (`tool/release_notes.py`). Windows
  y Linux también se compilan en cada push y pull request.
- Filtros en la pestaña Arca, combinables y con recuento por opción:
  generación, consola, origen (emulador, port Android/iOS, Checkpoint/JKSM,
  cartucho), juego con su color de versión, estado (daño, legalidad, editadas,
  varias copias) y fecha de la última copia; orden por reciente, entrenador,
  juego, horas o copias. Hoja inferior en el teléfono, panel lateral en
  escritorio, chips quitables, estado vacío y selección recordada por
  dispositivo.
- Preparación como código abierto: `CONTRIBUTING.md` (es/en),
  `CODE_OF_CONDUCT.md`, `SECURITY.md`, plantillas de issues y PR, y
  `.github/workflows/ci.yml` (análisis y tests en Ubuntu; en tags `v*`, APK
  release y app de macOS como borrador de Release). README en inglés (`README.md`) y español
  (`README.es.md`) con logo, funcionalidades, juegos, capturas y descargo de
  responsabilidad.
- Documentación completa en `docs/`: guía de usuario, formatos soportados,
  arquitectura, desarrollo, seguridad de datos, licencias y auditoría de
  publicación en tiendas.
- `tool/check_links.py`: verificación de enlaces, anclas e imágenes de los
  `.md` (en `tool/ci.sh`).
- Privacy Manifest de iOS (`PrivacyInfo.xcprivacy`), `CFBundleLocalizations`
  (es, en) en iOS y macOS y `NSPhotoLibraryUsageDescription`.

### Corregido
- Leyendas Z-A: los Pokémon creados con «Crear Pokémon» llevan versión,
  nivel, fecha y lugar de encuentro y nivel de obediencia válidos (antes
  `DateCalendarInvalidMet` y `TransferObedienceLevel` en PKHeX), con avisos y
  corrección para los ya guardados; los huecos vacíos del equipo no se
  reescriben; el tiempo de juego se lee y escribe (antes 0:00:00); mensaje
  claro si el save es de una revisión desconocida.
- Iconos: lo descargado se valida (PNG completo y del tamaño del índice), la
  escritura es atómica, los fallos transitorios tienen una segunda pasada y
  Ajustes muestra cuántos faltan con un botón **Reparar iconos**. Antes podían
  quedar iconos vacíos o truncados sin aviso.
- Iconos con proporciones coherentes: cada sprite se pinta con su lienzo
  original a la escala de su grupo (Pokémon, objetos, Balls, tipos, cintas),
  sin recortar ni estirar; antes un Joltik salía tan grande como un Wailord.
- Leyendas Z-A: los Pokémon creados o editados (nivel, especie, forma o
  movimientos) llevan las flags de movimientos «plus» que tocan por su nivel y
  learnset, como PKHeX (sin `PlusMoveSufficientLevelMissing`), y se quitan las
  imposibles. Nuevo aviso de legalidad con corrección para los ya guardados.
- Android release sin permiso `INTERNET`: los iconos no se descargaban en las
  builds de tienda.
- Sandbox de macOS sin `network.client`: los iconos no se descargaban en la app
  firmada.
- `flutter build appbundle` terminaba en error con rutas con espacios
  (`apkanalyzer`); `tool/android_setup.sh` ahora lo parchea.

### Limitaciones conocidas
- Leyendas Z-A: un Pokémon hecho con **Crear Pokémon** puede no casar con las
  tablas de encuentros de PKHeX (`EncInvalid`) aunque el resto de sus datos
  sean válidos; la app no inventa un encuentro concreto.
- Windows y Linux solo se han validado compilándolos en la CI: nadie los ha
  probado todavía en un PC real.
- iPhone/iPad: sin distribución (ni App Store ni TestFlight); hay que
  compilar la app desde el código con Xcode.

## Cintas, iconos, origen, colores y logo — 2026-11-22
### Añadido
- Cintas y marcas de Gen 3–9 en el editor (grupos, filtro, dar/quitar todas,
  cinta mostrada) con avisos de legalidad al estilo de `RibbonVerifier`.
- Iconos (sprites) bajo demanda desde los recursos de PKHeX en GitHub (commit
  fijo) con caché, límites, reintentos y respaldo sin conexión; Ajustes ›
  Iconos.
- Sección Origen: juego, lugar, nivel y fecha de encuentro, huevo, traspasos y
  Ball, con selectores válidos por juego.
- Colores oficiales por versión en el Arca (un color o la pareja en diagonal);
  versión deducida o fijada a mano.
- Logo nuevo en todas las plataformas, splash nativo y `tool/gen_branding.py`.
- Capturas de escritorio offscreen con `flutter test` (nunca se abre una
  ventana).
### Corregido
- Insignia de variocolor dentro de los límites del avatar.

## Pulido móvil — 2026-11-22
### Añadido
- Diseño de teléfono: pestañas en píldora, filtros como chips, cajas con
  flechas y deslizar, hojas inferiores, editor a pantalla completa, FAB que se
  contrae; tests sin desbordes en 320×568, 360×800 y 430×932 al 100 % y 130 %.
- Capturas de iPhone SE, iPhone 16 Pro y Android.
### Corregido
- Checksums de Sol/Luna y Ultrasol/Ultraluna: firma MemeCrypto del bloque 36.

## Android — 2026-11-22
### Añadido
- Entorno Android dentro del proyecto (`tool/android_setup.sh`,
  `tool/android_env.sh`), compilación opcional en `tool/ci.sh`.
- Prueba de humo en emulador headless (`tool/android_smoke.sh`): selector SAF
  real, permiso persistente, guardado y reindexado por SAF.

## El Arca en una carpeta — 2026-11-22
### Añadido
- El Arca vive en una carpeta elegida por el usuario (save + `.json` por
  copia), multi-dispositivo mediante la nube, índice drift reconstruible,
  reindexado incremental, saves sueltos adoptables y tolerancia a conflictos
  de nube.
- Permisos persistentes: bookmarks en iOS/macOS, SAF en Android.
- Migración del Arca interna anterior y cambio de carpeta con verificación.

## Validación con saves reales — 2026-11-22
### Añadido
- Oráculo diferencial con PKHeX (`tools/pkhex_oracle`,
  `tool/compare_with_pkhex.sh`).
- Pruebas opcionales con saves reales en `.ref/real-saves/`.
### Corregido
- Lectura y legalidad alineadas con PKHeX en saves reales de SoulSilver y
  Espada; legalidad Gen 3/4 sin falsos positivos; huecos vacíos de Gen 4+
  como el juego.

## Fase 4: Pokédex, eventos y legalidad completas — 2026-11-22
### Añadido
- Pokédex de Gen 6–9 con Pokédex regionales, formas, género y variocolor.
- Eventos con nombre en X/Y, ORAS, SM, USUM, Let's Go y DBPR.
- Legalidad de encuentros contra las tablas de PKHeX (Gen 3–9).
- Balls por juego (Hisui incluidas).
- Robustez: exportación verificada, saves dañados en solo lectura, tests de
  mutación de los 22 formatos.

## Fase 3: Pokédex, eventos, legalidad de orígenes y Arca masiva — 2026-11-22
### Añadido
- Pokédex (Gen 1–5) y editor de eventos (Gen 1–5, Gen 8–9).
- Legalidad de orígenes con correcciones seguras.
- Importación en bloque con resumen, Arca en zip con manifiesto y comparación
  de copias.

## Fase 2: escritura y editor — 2026-11-22
### Añadido
- Escritura de saves Gen 1–9 y entidad `Pkm` (PK1–PK9, PB7, PB8, PA8, PA9).
- Editor con borrador y deshacer: Pokémon, cajas, entrenador e inventario;
  legalidad básica.
- Inventario de Leyendas Arceus y Z-A; Oro/Plata coreano.

## Fase 1: el Arca — 2026-11-22
### Añadido
- `pkcore`: detección y lectura de saves Gen 1–9 con SwishCrypto.
- App Flutter: Arca de saves con importación, detalle e historial; SAF en
  Android; CI local.

## Inicio — 2026-11-21
- Commit inicial.
