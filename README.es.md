<p align="center">
  <img src="apps/pkarktools/assets/branding/logo_256.png" width="160" alt="Logo de PKArkTools">
</p>

<h1 align="center">PKArkTools</h1>

<p align="center">
  <b>El Arca de tus partidas guardadas: copias versionadas, lector y editor para todas las generaciones, en todos tus dispositivos.</b>
</p>

<p align="center">
  <a href="docs/media/pkarktools-demo.mp4"><img src="docs/media/pkarktools-demo.webp" width="600" alt="Vista previa animada: el Arca con los colores de cada versión, los filtros y una partida con su equipo y sus cajas"></a><br>
  <sub>▶ <a href="docs/media/pkarktools-demo.mp4">Ver la demostración completa (40 s, MP4, interfaz en inglés)</a> · <a href="#demostración">qué muestra</a></sub>
</p>

<p align="center">
  <a href="https://github.com/Rodriqe/PKArkTools/actions/workflows/ci.yml"><img src="https://github.com/Rodriqe/PKArkTools/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/licencia-GPL--3.0-blue.svg" alt="Licencia: GPL-3.0"></a>
  <img src="https://img.shields.io/badge/plataformas-Android%20%7C%20iOS%20%7C%20macOS%20%7C%20Windows%20%7C%20Linux-lightgrey" alt="Plataformas">
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-3.47-02569B?logo=flutter" alt="Flutter 3.47"></a>
</p>

<p align="center">
  <a href="README.md">English</a> · <b>Español</b>
</p>

> [!IMPORTANT]
> **Descargo de responsabilidad.** PKArkTools es un **proyecto de fans** no
> oficial y sin ánimo de lucro. **No está afiliado, respaldado ni patrocinado
> por Nintendo, Game Freak, Creatures Inc. ni The Pokémon Company**. Pokémon y
> los nombres relacionados son marcas de sus respectivos dueños. Ni la app ni
> este repositorio incluyen **ROMs, BIOS, claves de consola ni sprites** (los
> iconos se descargan opcionalmente bajo demanda, ver
> [Iconos](docs/usuario/iconos.md)). Úsalo **solo con tus propios saves**, de
> juegos que tengas.

<p align="center">
  <img src="docs/screenshots/v2/mac_02_arca_colores.png" width="100%" alt="El Arca en macOS">
</p>

## Qué es

Cada save que importas entra en **el Arca**: una carpeta que eliges **tú**,
donde cada copia se guarda **inmutable y versionada**, junto a un `.json`
legible con su juego, entrenador, fecha y SHA-256. El archivo original no se
toca nunca. Desde ahí ves el historial de cada partida, comparas copias, lees
y editas todo lo que hay dentro de un save y exportas un archivo verificado de
vuelta a tu consola o emulador.

Sin cuentas, sin servidores, sin telemetría: pon el Arca en iCloud Drive,
Google Drive, OneDrive, Dropbox o Syncthing y todos tus dispositivos la
comparten.

## Funcionalidades

**Arca y copias versionadas**
* Una carpeta por partida con la **última versión a la vista**, con el nombre
  que espera el juego (`main`, `SaveData.bin`, `Pokémon Esmeralda.sav`…) y
  lista para copiar, más un `historial/` de copias inmutables
  (`fecha_hora_hash.sav`), sin duplicados (SHA-256) y verificadas en cada
  lectura.
* **Carpetas por juego** opcionales que hacen de bandeja de entrada: deja un
  save en `PKArkTools/<Juego>/` y se archiva solo con su entrenador.
* Historial por partida con origen (archivo, carpeta, editor, ejemplo), notas
  y marca de «más reciente»; restaurar o exportar cualquier copia; actividad.
* **Comparar copias**: qué cambió entre dos copias — entrenador, Pokémon que
  entraron, salieron, cambiaron (campo a campo) o se movieron, inventario y
  Pokédex.
* Exportar / restaurar el Arca completa como **zip** con manifiesto.

**Tu carpeta, multi-dispositivo**
* El Arca vive en la carpeta que eliges (o en la carpeta local de la app), con
  acceso persistente en todas las plataformas (bookmarks en Apple, Storage
  Access Framework en Android).
* Varios dispositivos pueden escribir en la misma carpeta sincronizada:
  nombres únicos, detección de copias en conflicto y archivos de la nube aún
  no descargados, índice reconstruible en cualquier momento (**Reindexar**) y
  adopción de saves copiados a mano.

**Importar desde cualquier sitio**
* Archivos sueltos o carpetas enteras (importación en bloque con resumen
  previo): emuladores de GB/GBA/DS (`.sav`/`.srm` crudos, `.dsv` de DeSmuME,
  pies RTC), emuladores de Switch (Yuzu/Eden/Sudachi/Citron, Ryujinx) y sus
  ports de Android, volcados de cartucho y copias de **Checkpoint / JKSM**
  ([guía de importación](docs/usuario/importar.md)).
* Detección por contenido (tamaño, estructura, checksums), nunca por la
  extensión; ROMs, claves y otros archivos se ignoran sin abrirse.

**Lectura de todas las generaciones**
* Todos los juegos principales de Rojo/Azul a Leyendas Z-A: entrenador,
  equipo, cajas, tiempo de juego, dinero, medallas y estado de los checksums.

**Editor**
* Borrador con deshacer/rehacer; no se escribe nada hasta **Guardar en el
  Arca** (copia nueva) o **Exportar** (se relee y verifica antes de escribir).
* **Pokémon**: especie y forma, apodo, nivel/EXP, naturaleza (y menta),
  habilidad, objeto, movimientos y PP, IVs/EVs (AVs, GVs) con presets,
  variocolor (PID/EC regenerados), género, amistad, Ball, OT/TID/SID, idioma y
  teratipo; estadísticas en vivo.
* **Cajas** con arrastrar y soltar, **entrenador**, **inventario**,
  **Pokédex** (visto / capturado / género / variocolor / formas), **eventos**
  con nombre, **cintas y marcas**, **origen** (juego, lugar, fecha, OT).
* Pokémon sueltos `.pk1` … `.pk9`, `.pb7`, `.pb8`, `.pa8`, `.pa9`.

**Legalidad**
* Avisos portados de las reglas y tablas de encuentros de PKHeX.Core
  (movimientos, estadísticas, habilidades, Balls, variocolor bloqueado, lugar
  y nivel de encuentro), con explicación e «Intentar corregir».

**Saves dañados**
* Diagnóstico de checksums por bloque y **reparar checksums** al exportar
  ([guía](docs/usuario/reparar-checksums.md)).

**Aspecto**
* **Iconos** de especies, objetos, Balls y cintas **descargados bajo demanda**
  (opcional, en caché, reanudable): el único acceso a red de la app.
* Tarjetas con **colores por versión** (las parejas en diagonal), temas claro
  y oscuro, español e inglés.

## Juegos soportados

| Juegos | Plataforma | Lectura | Escritura | Extra |
|---|---|:-:|:-:|---|
| Rojo / Azul / Amarillo (int. y JP) | Game Boy | ✅ | ✅ | Pokédex, mochila + PC, eventos en crudo, `.pk1` |
| Oro / Plata / Cristal (int., JP y coreano) | Game Boy Color | ✅ | ✅ | Pokédex, eventos con nombre, `.pk2` |
| Rubí / Zafiro, Esmeralda, Rojo Fuego / Verde Hoja | GBA | ✅ | ✅ | Pokédex, eventos, cintas, encuentros salvajes, `.pk3` |
| Diamante / Perla, Platino, Oro HeartGold / Plata SoulSilver | DS | ✅ | ✅ | Pokédex + género, eventos, cintas, legalidad de encuentros completa, `.pk4` |
| Negro / Blanco, Negro 2 / Blanco 2 | DS | ✅ | ✅ | Pokédex + género/variocolor, eventos, cintas, encuentros, `.pk5` |
| X / Y, Rubí Omega / Zafiro Alfa | 3DS | ✅ | ✅ | Pokédex con formas, eventos, cintas, encuentros, `.pk6` |
| Sol / Luna, Ultrasol / Ultraluna | 3DS | ✅ | ✅ + MemeCrypto | Pokédex, eventos, cintas, encuentros, `.pk7` |
| Let's Go, Pikachu! / Eevee! | Switch | ✅ | ✅ + AVs | Pokédex, eventos, `.pb7` |
| Espada / Escudo | Switch | ✅ | ✅ | Pokédex de Galar y DLC, bloques con nombre, cintas y marcas, `.pk8` |
| Diamante Brillante / Perla Reluciente | Switch | ✅ | ✅ | Pokédex con formas, eventos, cintas, `.pb8` |
| Leyendas Pokémon: Arceus | Switch | ✅ | ✅ + GVs | Pokédex de Hisui por forma, bloques con nombre, `.pa8` |
| Escarlata / Púrpura | Switch | ✅ | ✅ + teratipo | Pokédex de Paldea, Kitakami y Arándano, `.pk9` |
| Leyendas Pokémon: Z-A | Switch | ✅ | ✅ | Pokédex de Luminalia e Hiperespacio, `.pa9` |

Detalles, contenedores y limitaciones: [docs/formatos.md](docs/formatos.md).

## Demostración

[**Ver el vídeo de demostración**](docs/media/pkarktools-demo.mp4) (40 s,
1080p, sin audio, interfaz en inglés), grabado en un emulador Android con
partidas de ejemplo sintéticas: la bienvenida, el Arca con un color por
versión, los filtros, una partida con su equipo y sus cajas, el editor de
Pokémon (nivel, variocolor, movimientos), origen y cintas, avisos de legalidad
con corrección segura, y guardar una copia nueva en el Arca para compararla
con la anterior. La vista previa animada de arriba son sus primeros 12
segundos.

El vídeo se reconstruye a partir de las grabaciones con
`tool/record_demo_video.sh` y `tool/make_demo_video.sh` (ver
[Desarrollo](docs/desarrollo.md#vídeo-de-demostración)).

## Capturas

| Escritorio | | |
|---|---|---|
| <img src="docs/screenshots/v2/mac_03_arca_colores_pareja.png" alt="Arca con colores por versión"> | <img src="docs/screenshots/v2/mac_04_cajas_iconos.png" alt="Cajas"> | <img src="docs/screenshots/v2/mac_05_ficha_iconos.png" alt="Editor de Pokémon"> |
| <img src="docs/screenshots/v2/mac_07_cintas.png" alt="Cintas"> | <img src="docs/screenshots/20_legalidad_detallada.png" alt="Legalidad"> | <img src="docs/screenshots/22_comparar_copias.png" alt="Comparar copias"> |
| <img src="docs/screenshots/24_pokedex_switch.png" alt="Pokédex"> | <img src="docs/screenshots/21_importacion_masiva.png" alt="Importación en bloque"> | <img src="docs/screenshots/v2/mac_01_onboarding_logo.png" alt="Elige tu carpeta"> |
| <img src="docs/screenshots/v2/mac_09_arca_filtros.png" alt="Filtros del Arca"> | <img src="docs/screenshots/android/v2_09_filtros_hoja.png" alt="Android: hoja de filtros"> | <img src="docs/screenshots/ios/v2_pro_10_arca_filtrada.png" alt="iPhone: Arca filtrada"> |

| iPhone | | | Android | | |
|---|---|---|---|---|---|
| <img src="docs/screenshots/ios/v2_pro_02_arca_colores.png" alt="iPhone: Arca"> | <img src="docs/screenshots/ios/v2_pro_05_ficha_iconos.png" alt="iPhone: Pokémon"> | <img src="docs/screenshots/ios/v2_pro_06_origen.png" alt="iPhone: origen"> | <img src="docs/screenshots/android/v2_02_arca_colores.png" alt="Android: Arca"> | <img src="docs/screenshots/android/v2_04_cajas_iconos.png" alt="Android: cajas"> | <img src="docs/screenshots/android/v2_07_cintas.png" alt="Android: cintas"> |

Todas las capturas usan saves sintéticos.

## Instalar

La versión actual es la **v0.1.1**. Descárgala desde el
[último release](https://github.com/Rodriqe/PKArkTools/releases/latest)
([todos los releases](https://github.com/Rodriqe/PKArkTools/releases),
[CHANGELOG](CHANGELOG.md)).

| Plataforma | Cómo |
|---|---|
| Android | `PKArkTools-v0.1.1.apk`: ábrelo en el teléfono y permite instalar desde ese origen cuando Android lo pida. |
| macOS | `PKArkTools-v0.1.1-macos.zip`: descomprímelo y mueve `PKArkTools.app` a Aplicaciones. No está notarizada: la primera vez, **clic derecho → Abrir → Abrir**. |
| iPhone / iPad | Aún sin build descargable: compílala desde el código con Xcode (abajo). |
| Windows | `PKArkTools-v0.1.1-windows-x64-setup.exe` (instalador) o `PKArkTools-v0.1.1-windows-x64.zip` (portátil: descomprímelo y abre `PKArkTools.exe`). No está firmado: si SmartScreen avisa, pulsa **Más información → Ejecutar de todas formas**. |
| Linux | `PKArkTools-v0.1.1-linux-x64.tar.gz`: extráelo y ejecuta `PKArkTools/pkarktools` (GTK 3; el selector de carpetas necesita `zenity` o `kdialog`). |

> Las builds de Windows y Linux solo se generan y comprueban en la CI: todavía
> nadie las ha probado en un PC real. Se agradecen los avisos en
> [Issues](https://github.com/Rodriqe/PKArkTools/issues).

## Compilar

Requiere Flutter estable (3.47+):

```bash
git clone https://github.com/Rodriqe/PKArkTools.git
cd PKArkTools
flutter pub get
tool/ci.sh                          # análisis, tests y enlaces de la documentación
cd apps/pkarktools
flutter run                         # o: flutter build apk | macos | ios | windows | linux
```

El repositorio es un workspace de Dart: `packages/pkcore` (núcleo en Dart
puro: detección, lectura, escritura, legalidad) y `apps/pkarktools` (app
Flutter). Ver [Arquitectura](docs/arquitectura.md) y
[Desarrollo](docs/desarrollo.md).

## Tus datos

Los saves no salen de tu dispositivo ni de tu carpeta; el archivo original no
se modifica nunca; cada copia y exportación se verifica (SHA-256 / relectura);
nada se sobrescribe. La única petición de red es la descarga opcional de
iconos. Lee [Seguridad de datos y privacidad](docs/seguridad-datos.md).

## Documentación

Toda la documentación está en [`docs/`](docs/README.md):
[guía de usuario](docs/usuario/README.md) ·
[formatos soportados](docs/formatos.md) ·
[seguridad de datos](docs/seguridad-datos.md) ·
[arquitectura](docs/arquitectura.md) ·
[desarrollo](docs/desarrollo.md) ·
[publicación en tiendas](docs/publicacion.md) ·
[licencias](docs/licencias.md) ·
[CHANGELOG](CHANGELOG.md).

## Contribuir

Se agradecen issues y pull requests. Lee [CONTRIBUTING.md](CONTRIBUTING.md#español),
el [Código de conducta](CODE_OF_CONDUCT.md) y, para vulnerabilidades,
[SECURITY.md](SECURITY.md). Nunca adjuntes ROMs, claves ni saves de otras
personas.

## Créditos

* [**PKHeX**](https://github.com/kwsch/PKHeX), de Kaphotics y colaboradores
  (GPL-3.0): formatos de save, cifrado, checksums, reglas de legalidad y datos
  de juego portados de PKHeX.Core; los iconos opcionales se descargan del
  repositorio de PKHeX.
* [**PokeAPI**](https://github.com/PokeAPI/pokeapi) (BSD-3-Clause): nombres de
  especies, tipos, tablas de experiencia y cadenas evolutivas.
* Fuentes **Manrope** y **Bricolage Grotesque** (SIL OFL 1.1).
* Lista completa en [`NOTICE`](NOTICE) y [docs/licencias.md](docs/licencias.md).

## Licencia

[GPL-3.0](LICENSE). Pokémon © Nintendo, Creatures Inc., GAME FREAK inc.;
este proyecto no está afiliado a ellos.
