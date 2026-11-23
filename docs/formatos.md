# Formatos soportados

Todos los juegos principales de Gen 1 a Gen 9. La detección se hace por
contenido (tamaño, estructura y checksums), nunca por la extensión.

## Por juego

Leyenda: ✅ completo · ◐ parcial (ver notas) · — no aplica.

| Juego(s) | Plataforma | Lectura | Escritura | Pokédex | Eventos | Inventario | Cintas | Legalidad de encuentros | Pokémon suelto |
|---|---|---|---|---|---|---|---|---|---|
| Rojo / Azul / Amarillo (int. y JP) | Game Boy | ✅ 12 cajas (8 JP) | ✅ | ✅ 151 | ◐ lista cruda | ✅ mochila + PC | — | — | `.pk1` |
| Oro / Plata / Cristal (int., JP y coreano) | Game Boy Color | ✅ 14 cajas (9 JP) | ✅ | ✅ 251 | ✅ con nombre | ✅ | — | — | `.pk2` |
| Rubí / Zafiro, Esmeralda, Rojo Fuego / Verde Hoja | GBA | ✅ 14 cajas | ✅ | ✅ 386 | ✅ con nombre | ✅ | ✅ 12 + 5 contadores | ◐ salvajes (estáticos pendientes) | `.pk3` |
| Diamante / Perla, Platino, Oro HeartGold / Plata SoulSilver | DS | ✅ 18 cajas | ✅ | ✅ 493 + género | ✅ con nombre | ✅ | ✅ 80 | ✅ salvajes, estáticos, regalos, intercambios | `.pk4` |
| Negro / Blanco, Negro 2 / Blanco 2 | DS | ✅ 24 cajas | ✅ | ✅ 649 + género y variocolor | ✅ con nombre | ✅ | ✅ 80 | ✅ salvajes, estáticos, regalos, intercambios | `.pk5` |
| X / Y, Rubí Omega / Zafiro Alfa | 3DS | ✅ 31 cajas | ✅ | ✅ 721: género, variocolor, formas | ✅ con nombre | ✅ | ✅ 46 | ✅ (aviso fuerte) | `.pk6` |
| Sol / Luna, Ultrasol / Ultraluna | 3DS | ✅ 32 cajas | ✅ (+ firma MemeCrypto) | ✅ 802 / 807 | ✅ con nombre | ✅ | ✅ 50 | ✅ (aviso fuerte) | `.pk7` |
| Let's Go, Pikachu! / Eevee! | Switch | ✅ 1000 huecos | ✅ (+ AVs) | ✅ Kanto + Meltan/Melmetal | ✅ con nombre | ✅ | ✅ 50 | ✅ (aviso fuerte) | `.pb7` |
| Espada / Escudo | Switch | ✅ 32 cajas | ✅ | ✅ Galar, Isla de la Armadura, Corona Nieve | ✅ bloques con nombre | ✅ | ✅ 111 + marcas | ◐ sin incursiones (informativo) | `.pk8` |
| Diamante Brillante / Perla Reluciente | Switch | ✅ 40 cajas | ✅ | ✅ 493: estado, género, variocolor, formas | ✅ con nombre | ✅ | ✅ 111 | ◐ sin Subsuelo | `.pb8` |
| Leyendas Pokémon: Arceus | Switch | ✅ 32 cajas | ✅ (+ GVs) | ✅ Hisui por forma; investigación solo lectura | ✅ bloques con nombre | ✅ | ✅ 111 + marcas | ◐ salvajes (estáticos pendientes) | `.pa8` |
| Escarlata / Púrpura | Switch | ✅ 32 cajas | ✅ (+ teratipo) | ✅ Paldea, Kitakami, Arándano (bloque antiguo y 2.0.1+) | ✅ bloques con nombre | ✅ | ✅ 111 + marcas | ◐ sin teraincursiones ni brotes | `.pk9` |
| Leyendas Pokémon: Z-A | Switch | ✅ cajas | ✅ | ✅ Luminalia e Hiperespacio | ✅ bloques con nombre | ✅ | ✅ 111 + marcas | ◐ salvajes (estáticos pendientes) | `.pa9` |

En todos los formatos se editan además el entrenador (nombre, dinero, TID/SID,
tiempo jugado y género donde exista) y los Pokémon de equipo y cajas. La
**legalidad básica** (movimientos, estadísticas, habilidad, objeto, Ball,
variocolor bloqueado, origen) se aplica a todas las generaciones; la columna
«Legalidad de encuentros» se refiere solo a la comprobación contra las tablas
de encuentros.

## Verificaciones por familia

| Familia | Cifrado / verificación |
|---|---|
| Gen 1–2 | Checksum de 8/16 bits por bloque |
| Gen 3 | 14 sectores rotados con checksum por sector y doble ranura |
| Gen 4–5 | CRC16-CCITT por bloque y pie con contador |
| Gen 6–7 (3DS) | CRC16 «BEEF» por bloque; Sol/Luna y USUM con firma MemeCrypto del bloque 36 |
| Let's Go | Bloques con CRC BEEF |
| DBPR | MD5 del archivo |
| Espada/Escudo, Leyendas Arceus, Escarlata/Púrpura, Z-A | SwishCrypto: bloques SCBlock cifrados con XorShift32 y SHA-256 del archivo |
| Pokémon (PK3–PK9, PB7, PB8, PA8, PA9) | Cifrado y barajado por PID/EC con checksum de 16 bits |

## Contenedores reconocidos

| Contenedor | Ejemplo | Al exportar |
|---|---|---|
| Save crudo | `.sav`, `.srm`, `.dat` de cartucho o emulador | Igual |
| DeSmuME | `.dsv` (save + pie de metadatos) | Se conserva el pie |
| Pie RTC de emuladores GB/GBA | `.sav` con un pie de reloj de 7 a 48 bytes al final | Se conserva el pie |
| Checkpoint / JKSM (3DS y Switch) | Archivos de las carpetas de backup (`main` en Switch, save del juego en 3DS) | Igual |
| Carpeta de save de emuladores de Switch | Archivo `main` en `nand/user/save/…` o `bis/user/save/…` | Igual |
| Pokémon suelto | `.pk1` … `.pk9`, `.pb7`, `.pb8`, `.pa8`, `.pa9` | Mismo formato que el juego |

Se ignoran sin abrirse: ROMs (`.gb`, `.gbc`, `.gba`, `.nds`, `.3ds`, `.cia`,
`.nsp`, `.xci`, `.nca`…), claves (`.keys`, `.prod`, `.title`), comprimidos,
imágenes, vídeos y otros archivos que no son saves.

## Limitaciones conocidas

* **Encuentros pendientes**: estáticos de Gen 3, Leyendas Arceus y Z-A;
  incursiones de Espada/Escudo; Subsuelo de DBPR; teraincursiones y brotes de
  Escarlata/Púrpura; eventos de distribución. En esos casos el aviso es
  informativo.
* **Gen 1**: los eventos se muestran como lista cruda (PKHeX no tiene tabla
  fiable de nombres). Gen 1–2 no guardan lugar de encuentro.
* **Leyendas Arceus**: el nivel de investigación de la Pokédex es de solo
  lectura.
* **Hacks y saves modificados** con estructuras distintas pueden no
  reconocerse o abrirse en solo lectura.
* **Saves de Gen 8–9 de versiones de juego muy nuevas** pueden traer bloques
  aún sin nombre: se muestran con su clave hexadecimal.
* No se editan: Mundo Misterioso / regalos pendientes, Pokémon de HOME,
  datos de combate en línea, fotos, ni el contenido descargable fuera de su
  Pokédex.
* La legalidad no sustituye a PKHeX (ver [Legalidad](usuario/legalidad.md#límites)).
