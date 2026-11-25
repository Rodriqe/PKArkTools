# Emuladores

**Ajustes → Emuladores** vincula la carpeta de saves de tu emulador para
respaldarla en el Arca con un toque. PKArkTools **solo lee** esa carpeta:
nunca escribe en ella.

1. **Vincular carpeta de un emulador**: eliges el emulador, se explica qué
   se va a leer (y la ruta habitual en tu sistema) y, si das permiso, se abre
   el selector de carpetas del sistema. En Android es el selector SAF; en
   iOS, Archivos; en macOS, el selector (la app está aislada y no puede leer
   rutas por su cuenta).
2. **Buscar carpetas conocidas** (Windows y Linux): comprueba las rutas
   habituales de cada emulador y te ofrece vincular las que existen, también
   con permiso.
3. **Respaldar** (icono de nube): lee los saves de la carpeta y los guarda en
   el Arca como copias nuevas, igual que al importar (se colocan en la
   carpeta de su juego y entrenador). Los que el Arca ya tiene no se repiten;
   ROMs, imágenes y archivos que no son saves se ignoran.

## Abrir el juego

En una partida, **Abrir en …** aparece solo si hay un emulador de esa consola
que se pueda abrir desde la app:

* **Android**: se abre el emulador instalado (RetroArch, melonDS,
  Azahar/Lime3DS, Dolphin, Eden/Citron/Sudachi/Yuzu).
* **iOS**: Delta, con su esquema de URL `delta://`.
* **macOS, Windows y Linux**: no hay una forma fiable de abrir el emulador
  con la partida, así que el botón no aparece.

Se abre el emulador, no el juego concreto: elige la ROM dentro de él.

> «Enviar al emulador» (escribir la versión actual en la carpeta del
> emulador) no está disponible por ahora: usa **Exportar** de la partida y
> copia el archivo a mano.

## Compatibilidad

| Emulador | Consolas | Carpeta de saves | Respaldo | Abrir |
|---|---|---|---|---|
| RetroArch | GB, GBC, GBA, DS, N64, GC, Wii | Windows `%APPDATA%\RetroArch\saves`; Linux `~/.config/retroarch/saves` (Flatpak: `~/.var/app/org.libretro.RetroArch/…`); macOS `~/Library/Application Support/RetroArch/saves`; Android `RetroArch/saves`; iOS «En mi iPhone › RetroArch › saves» | ✅ | Android |
| mGBA | GB, GBC, GBA | Junto a la ROM: vincula la carpeta de ROMs | ✅ | — |
| melonDS | DS | Junto a la ROM o la carpeta elegida en sus ajustes | ✅ | Android |
| Azahar / Lime3DS | 3DS | `sdmc/Nintendo 3DS/<id>/<id>/title/00040000/<juego>/data/00000001/main` dentro de `%APPDATA%\Azahar`, `~/.local/share/azahar-emu`, `~/Library/Application Support/Azahar` o la carpeta de usuario elegida en Android | ✅ | Android |
| Dolphin | GameCube, Wii | `GC/<región>/Card A` (.gci) o la Memory Card `.raw`; `Wii/title/00010000/<juego>/data` dentro de `%APPDATA%\Dolphin Emulator`, `~/.local/share/dolphin-emu` o `~/Library/Application Support/Dolphin` | ✅ (Android 11+: exporta primero) | Android |
| Delta (iOS) | GB, GBC, GBA, DS | No expone su carpeta: exporta el save desde el menú del juego e impórtalo, o vincula su carpeta de sincronización de Dropbox/Google Drive | Con export o carpeta sincronizada | iOS |
| Eden / Citron / Sudachi / Yuzu (Android) | Switch | `Android/data/<paquete>/files/nand/user/save/0000000000000000/<usuario>/<juego>/` | Android 11+ no deja elegir `Android/data`: exporta los datos desde el emulador a una carpeta normal y vincula esa | Android |

Las rutas de Android y de Azahar dependen de la versión del emulador: si la
habitual no existe, busca la carpeta en el selector. Los nombres de paquete de
Android se comprueban en el dispositivo; si un emulador no se encuentra, el
botón simplemente no aparece.
