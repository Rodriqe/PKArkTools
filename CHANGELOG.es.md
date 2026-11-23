# Changelog

Todos los cambios relevantes del proyecto. El formato sigue
[Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y las versiones
[SemVer](https://semver.org/lang/es/). La primera versión publicada es
PKArkTools 0.1.0 (`0.1.0+1` en `apps/pkarktools/pubspec.yaml`); las secciones
que la siguen son los hitos internos de desarrollo que llevaron a ella.

Esta es la traducción al español de [CHANGELOG.md](CHANGELOG.md) (en inglés),
que es el que usan las notas de los Releases; se actualizan a la par.

## [Unreleased]

## [0.1.3] — 2026-11-23

El Arca puede estar en una carpeta de red (NAS): en un Mac con un recurso SMB
(también AFP/NFS/WebDAV) y en Android con un proveedor de documentos SMB. La
app detecta el recurso, avisa claramente cuando no está montado en vez de
tratarlo como un Arca vacía, sondea los cambios de otros dispositivos mientras
está abierta, reintenta los errores pasajeros de red y trata los nombres con
acentos tal como los devuelve SMB en macOS. Probado en un NAS SMB real desde un
Mac; **Android sobre SMB/SAF aún no se ha probado en un dispositivo**.

### Añadido
- **Buscar actualizaciones** en Ajustes: muestra el último release de GitHub
  y sus novedades. En Android descarga el APK dentro de la app y lo entrega al
  instalador del sistema (una confirmación; datos y ajustes se conservan),
  pidiendo una vez «Instalar apps desconocidas». En escritorio abre la página
  de descarga. Ver [Primeros pasos › Actualizar la app](docs/usuario/primeros-pasos.md#7-actualizar-la-app).
- **Arca en una carpeta de red (NAS)** en macOS (SMB, también AFP/NFS/WebDAV)
  y Android (SAF con un proveedor de documentos SMB). La carpeta se detecta
  como de red (tabla de montajes con `getfsstat`, sin bloquearse nunca en un
  servidor que no responde) y Ajustes muestra «Carpeta de red (NAS) ·
  NAS/Recurso» con un icono de red. Ver
  [Primeros pasos › En un NAS](docs/usuario/primeros-pasos.md#en-un-nas-carpeta-de-red).
- Pantalla **«Carpeta de red no disponible»** con **Reintentar** y **Elegir
  otra** cuando el recurso no está montado; se reintenta sola al volver a la
  app.
- Las carpetas de red se reindexan cada 60 s mientras la app está en primer
  plano (FSEvents no ve los cambios de otros equipos en SMB), sin solaparse y
  espaciándose si la red va lenta.
- Diálogo de progreso («Importando N de M») en las importaciones grandes.

### Corregido
- Ajustes › Acerca de mostraba la versión 0.1.0 en vez de la instalada.
- Los nombres de carpeta que macOS devuelve descompuestos (NFD) en volúmenes
  SMB/AFP («Pokémon») ya no hacen que cada reindexado quite y vuelva a añadir
  todas las copias y reescriba los archivos principales.
- En recursos SMB de macOS, un archivo con acentos («Pokémon») se encuentra
  aunque el recurso solo responda a su forma descompuesta (visto en un NAS real
  tras listar una carpeta): ya no se da por desaparecido y volver a crearlo ya
  no puede reemplazar la copia existente.
- La app nunca escribe en un recurso desmontado: detecta la carpeta local
  `/Volumes/<recurso>` que puede quedar en su lugar y nunca crea la carpeta
  raíz.
- Elegir una carpeta que ya contiene `PKArkTools/` (o la propia carpeta
  `PKArkTools`, aunque no tenga README) nunca anida otra `PKArkTools/`.

### Cambiado
- Carpetas de red: los errores pasajeros (EAGAIN, ETIMEDOUT, ESTALE, un ENOENT
  momentáneo…) se reintentan con espera creciente y cada operación tiene un
  tiempo máximo; reemplazar un archivo principal aparta el anterior y
  renombra si el servidor no reemplaza al renombrar.
- Los archivos de sistema del NAS y del SO (`._*` AppleDouble, `.DS_Store`,
  `@eaDir`, `#recycle`, `@Recycle`, `.snapshot`, `$RECYCLE.BIN`,
  `Thumbs.db`…) se ignoran y esas carpetas ni se recorren; el listado consulta
  los archivos en paralelo.
- Las carpetas existentes se reutilizan sin distinguir mayúsculas (SMB no las
  distingue), también en Android.

## [0.1.2] — 2026-11-23

Los problemas de la carpeta del Arca se pliegan en una línea en Ajustes y se
pueden arreglar o ignorar desde ahí. Las Arcas creadas con el nombre anterior de
la app se vuelven a leer bien.

### Añadido
- **Problemas del Arca en Ajustes, plegados en una línea**: «3 problemas en
  el Arca» con un icono de gravedad, plegado por defecto. Desplegado, se
  agrupan por tipo con su recuento, una explicación corta en lenguaje claro y
  la ruta relativa de cada archivo. La pestaña Arca muestra como mucho un
  aviso de una línea que lleva a Ajustes; sin problemas, solo un check
  discreto. Ver [El Arca › Problemas del Arca](docs/usuario/arca.md#problemas-del-arca).
- **Arreglar** por archivo, por grupo o **Arreglar todo** (con confirmación
  propia, progreso y resultado «2 arreglados, 1 en cuarentena»): regenera un
  `.json` dañado o que falta desde su save, reconstruye el archivo principal
  y `ultima.json` desde el historial, adopta saves sueltos y copias de
  conflicto de la nube, retira las copias cuyo contenido exacto ya está en el
  historial y guarda como copia nueva un principal cambiado a mano. Nada se
  borra: lo irreparable se mueve a `PKArkTools/_cuarentena/` con una nota,
  tras comprobarlo por su SHA-256.
- **Copias duplicadas en el historial** (mismo SHA-256 en la misma carpeta
  de entrenador, por ejemplo tras importar una carpeta que contenía el
  Arca): Arreglar conserva la más antigua y mueve las demás, con su `.json`,
  a `PKArkTools/_cuarentena/duplicados/` con una nota. Las restauraciones no
  cuentan: repiten contenido a propósito.
- **Ignorar** por archivo o por grupo: se oculta del resumen hasta que el
  archivo cambie (ruta + tamaño + fecha) y se guarda solo en los ajustes de
  este dispositivo; **Mostrar ignorados (N)** los lista para deshacerlo.

### Corregido
- Arcas creadas cuando la app aún tenía su nombre anterior: todos sus `.json`
  (esquema `<nombre anterior>-snapshot`) salían como dañados y el paso a
  `historial/` fallaba en cada reindexado. Ahora se leen como propios y se
  reescriben con el esquema actual al migrar.
- Importar una carpeta que contiene el propio Arca (por ejemplo `ROMs/Saves`)
  ya no reimporta cada copia del historial como copia nueva con la fecha de
  hoy.
- Las copias de conflicto de la nube de copias del historial (`… (1).sav`)
  se ignoraban en silencio; ahora se listan para retirarlas o adoptarlas. Una
  copia cuyo SHA-256 no coincide al leerla ahora se avisa al reindexar.

### Cambiado
- Ajustes ya no muestra las listas largas y siempre desplegadas de problemas,
  bandeja de entrada, principales cambiados a mano y saves sueltos: están en
  el resumen plegado.

## [0.1.1] — 2026-11-23

La carpeta del Arca deja a la vista la última versión de cada partida con el
nombre que usa el juego, con las copias en `historial/`; las carpetas de 0.1.0
se migran solas. Iconos de Pokémon HOME para las 1025 especies, más grandes.

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
- **Iconos de Gen 9 y Leyendas Z-A**: los Pokémon usan ahora los iconos de
  caja de Pokémon HOME del repositorio de sprites de Smogon / Pokémon Showdown
  (`smogon/sprites`, commit fijo): las **1025 especies** y 330 formas
  (regionales, Paldea, Ogerpon, Urshifu, Alcremie, Vivillon…) con un mapeo
  explícito especie-forma → archivo. Antes, de la 906 en adelante salían
  iniciales. Objetos, Balls, tipos y cintas siguen saliendo de PKHeX.

### Cambiado
- **Iconos más grandes**: la escala de cada grupo se calcula a partir del
  contenido no transparente de todo el set (percentil 92) para que llene el
  88 % del hueco, igual para todos los iconos del grupo, sin recortes ni
  deformación; antes se escalaba el lienzo entero y el Pokémon ocupaba ~40 %.
  Arte de píxeles con escala entera o vecino más próximo. Ver
  [antes/después](docs/screenshots/iconos_antes_despues.png).
- Variocolor: la nueva fuente no tiene iconos variocolor, así que se mantiene
  la insignia y el borde dorado.
- «Descargar todos los iconos» pasa a ~16 MB (2168 archivos); la caché de la
  versión anterior se borra sola. Ajustes › Acerca de indica ambas fuentes.
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

### Limitaciones conocidas
- Formas sin icono propio en HOME (megas nuevas de Leyendas Z-A, Teraforma de
  Terapagos, tipos de Silvally, modos de Koraidon/Miraidon…) usan el icono de
  la especie.
- Sin iconos variocolor: el Pokémon variocolor se marca con el borde dorado y
  la insignia ✦.
- Las de 0.1.0 siguen vigentes (Leyendas Z-A y Crear Pokémon, Windows/Linux
  validados solo en la CI, iPhone/iPad compilando desde el código).

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
