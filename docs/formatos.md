# Formatos soportados

Todos los juegos principales de Gen 1 a Gen 9, Pokémon Colosseum y
Pokémon XD: Tempestad Oscura (GameCube), y los juegos de almacenamiento y
estadio: Pokémon Stadium y Stadium 2 (N64), Pokémon Box: Rubí y Zafiro
(GameCube), Pokémon Battle Revolution y My Pokémon Ranch (Wii). La detección se hace por contenido
(tamaño, estructura y checksums), nunca por la extensión.

## Por juego

Leyenda: ✅ completo · ◐ parcial (ver notas) · — no aplica.

| Juego(s) | Plataforma | Lectura | Escritura | Pokédex | Eventos | Inventario | Cintas | Legalidad de encuentros | Pokémon suelto |
|---|---|---|---|---|---|---|---|---|---|
| Rojo / Azul / Amarillo (int. y JP) | Game Boy | ✅ 12 cajas (8 JP) | ✅ | ✅ 151 | ◐ lista cruda | ✅ mochila + PC | — | — | `.pk1` |
| Oro / Plata / Cristal (int., JP y coreano) | Game Boy Color | ✅ 14 cajas (9 JP) | ✅ | ✅ 251 | ✅ con nombre | ✅ | — | — | `.pk2` |
| Rubí / Zafiro, Esmeralda, Rojo Fuego / Verde Hoja | GBA | ✅ 14 cajas | ✅ | ✅ 386 | ✅ con nombre | ✅ | ✅ 12 + 5 contadores | ◐ salvajes (estáticos pendientes) | `.pk3` |
| Pokémon Colosseum | GameCube | ✅ 3 cajas, Pokémon oscuros | ✅ | ◐ Strategy Memo (vistos/capturados) | — | ✅ 6 bolsillos | ✅ 12 + 5 contadores | ✅ oscuros, iniciales, regalos | `.ck3` (y `.pk3`) |
| Pokémon XD: Tempestad Oscura | GameCube | ✅ 8 cajas, Pokémon oscuros | ✅ | ◐ Strategy Memo (vistos) | — | ✅ 7 bolsillos (con discos) | ✅ 12 + 5 contadores | ✅ oscuros, regalos, intercambios, Poké Spots | `.xk3` (y `.pk3`) |
| Pokémon Stadium (int. y JP) y Pocket Monsters Stadium (JP) | N64 | ✅ 12 cajas de 20 (8×30 JP, 4×30 el original) + equipos registrados (solo lectura) | ✅ | — | — | — | — | — | `.pk1` |
| Pokémon Stadium 2 (int. y JP) | N64 | ✅ 14 cajas de 20 (9×30 JP) + equipos registrados (solo lectura) | ✅ | — | — | — | — | — | `.sk2` (y `.pk2`) |
| Pokémon Box: Rubí y Zafiro | GameCube | ✅ 25 cajas de 60 (50 medias cajas) | ✅ | — | — | — | ✅ | ✅ (las de los juegos de GBA) | `.pk3` |
| Diamante / Perla, Platino, Oro HeartGold / Plata SoulSilver | DS | ✅ 18 cajas | ✅ | ✅ 493 + género | ✅ con nombre | ✅ | ✅ 80 | ✅ salvajes, estáticos, regalos, intercambios | `.pk4` |
| Pokémon Battle Revolution | Wii | ✅ equipo + 18 cajas del primer perfil con datos | ✅ | — | — | — | ✅ | ✅ (las de DS) | `.bk4` (y `.pk4`) |
| My Pokémon Ranch (DP y Platino) | Wii | ✅ hasta 1000 huecos según el nivel del rancho | ✅ | — | — | — | ✅ | ✅ (las de DS) | `.rk4` (y `.pk4`) |
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
| Colosseum | 3 ranuras de 0x1E000; cada una cifrada con XOR en bloques de 20 bytes encadenados con SHA-1 (la clave es el SHA-1 de los datos, guardado al final) y suma de cabecera |
| XD | 2 ranuras de 0x28000 cifradas con el algoritmo de Genius Sonority (4 claves de 16 bits que se transforman cada 4 palabras), 4 sumas de 32 bits y suma de cabecera |
| Pokémon Stadium / Stadium 2 | Cajas en listas con firma `POKE`/`P3v0`, contador y suma de bytes de 16 bits por caja; copia de seguridad de las cajas en Stadium |
| Pokémon Box | 58 bloques de 0x2000 (dos copias de 23 + 12 extra) con suma de 16 bits y su complemento |
| Battle Revolution | Dos mitades cifradas con Genius Sonority; 16 contadores de bits por mitad y por cabecera |
| My Pokémon Ranch | SHA-1 del archivo, contador de Pokémon y marcador de fin |
| Memory Card de GameCube | Suma y suma inversa de 16 bits de la cabecera, el directorio y la tabla de bloques (con copia de seguridad de cada uno) |
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
| GCI de GameCube | `.gci` exportado con Dolphin (o de su carpeta GCI): cabecera de 0x40 bytes + datos | Se conserva la cabecera |
| Memory Card de GameCube | Imagen completa `.raw` (Dolphin), `.gcp`, `.mci`, de 512 KB a 16 MB | Se reescriben solo los bloques del save, siguiendo la tabla de bloques (aunque no sean contiguos); directorio y sumas de la tarjeta intactos |
| Save de N64 | `.fla`/`.sra`/`.sav` de Mupen64Plus, Project64, simple64, RetroArch (`.srm`) o de un lector, también con las palabras de 32 bits invertidas | Igual (mismo orden de bytes) |
| Save de Wii (NAND de Dolphin) | `PbrSaveData` (Battle Revolution), `pokemonranch.bin` (Rancho) | Igual |
| Save de GameCube sin cabecera | Datos de 0x60000 (Colosseum) o 0x56000 (XD) | Igual |
| Pokémon suelto | `.pk1` … `.pk9`, `.pb7`, `.pb8`, `.pa8`, `.pa9`, `.ck3`, `.xk3` | Mismo formato que el juego |

Se ignoran sin abrirse: ROMs (`.gb`, `.gbc`, `.gba`, `.nds`, `.3ds`, `.cia`,
`.nsp`, `.xci`, `.nca`…), claves (`.keys`, `.prod`, `.title`), comprimidos,
imágenes, vídeos y otros archivos que no son saves.

## Pokémon Colosseum y XD

* **Detección**: por el código de juego de la cabecera (`GC6E`/`GC6P`/`GC6J`
  Colosseum, `GXXE`/`GXXP`/`GXXJ` XD; la última letra es la región: USA,
  Europa, Japón) o, sin cabecera, por el tamaño y la firma de cada ranura. Se
  abre la ranura con el contador de guardado más alto, como el juego.
* **Pokémon**: CK3 (312 bytes) y XK3 (196 bytes), big endian y sin cifrar. El
  editor los trata como PK3 (mismas reglas que Gen 3) y conserva aparte lo
  propio de GameCube: al escribir solo cambian los campos editados, así que
  los datos de combate, el «apodo mostrado» y los glifos regionales quedan
  intactos byte a byte.
* **Pokémon oscuros**: Colosseum guarda el id oscuro y el medidor de corazón
  en cada CK3 (`-100` = purificado); XD guarda el id en el XK3 y el estado
  (medidor, capturado, purificado) en la tabla de Pokémon oscuros del save.
* **Strategy Memo**: se expone como Pokédex. En Colosseum registra vistos y
  capturados; en XD solo vistos (como en PKHeX).
* **Región**: los Pokémon que llegan de GBA (`.pk3`) o de otro save se
  escriben con la región y el idioma de este save.
* **Validado contra PKHeX** con saves sintéticos (`.gci`, sin cabecera y
  Memory Card): misma lectura campo a campo (incluido el estado oscuro),
  mismas sumas, y un save cargado y guardado sin cambios por PKHeX es
  idéntico byte a byte al original y al que escribe PKArkTools. Diferencia
  deliberada: en una Memory Card PKHeX actualiza la fecha de la entrada del
  directorio sin recalcular la suma del directorio; PKArkTools no toca el
  directorio, así que Dolphin no ve la tarjeta dañada.

## Juegos de almacenamiento y estadio

* **Sin entrenador propio**: Stadium, Stadium 2, Box y el Rancho solo guardan
  Pokémon (el Rancho guarda el nombre de su dueño y el tiempo de juego). En
  el Arca aparecen como «STADIUM», «STADIUM 2», «BOX» o el nombre del dueño
  del rancho.
* **Stadium**: las cajas son listas compactas (el juego solo lee los primeros
  N Pokémon): al vaciar un hueco los siguientes avanzan uno. Los equipos
  registrados de cada copa se leen pero no se editan. Se detectan las tres
  distribuciones (internacional, japonesa y el Pocket Monsters Stadium
  original) por las firmas de las listas, también en volcados con el orden de
  bytes invertido, que se conserva al exportar.
* **Battle Revolution**: el save tiene 4 perfiles; se abre el primero con
  datos y el resto se conserva intacto (aviso con sus nombres). Los BK4 se
  editan como PK4 sin pérdidas.
* **Rancho**: la capacidad depende del nivel del rancho; los huecos por encima
  están bloqueados. Un Pokémon nuevo entra a cargo de Hayley (sin dueño, el
  juego lo borraría al cargar).
* **Validado contra PKHeX** con saves sintéticos de las cinco: misma lectura
  (salvo el nombre de entrenador que PKHeX inventa para los juegos sin él),
  mismas sumas, y PKHeX reescribe cada archivo sin cambios idéntico byte a
  byte. Los archivos editados por PKArkTools los abre PKHeX con las sumas
  correctas. La legalidad no da avisos sin respaldo de PKHeX.

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
* **Colosseum/XD**: no se comprueba la correlación PID/IV del generador de
  números aleatorios (bloqueos de equipo de los Pokémon oscuros); una Memory
  Card con los dos juegos se importa como dos `.gci` (el `.raw` editado solo
  se reescribe si tiene un único save de Pokémon). No se edita el Purificador
  de XD ni la guardería.
* **Juegos de almacenamiento**: no se editan los equipos registrados de
  Stadium, el buzón de Stadium 2, los perfiles 2–4 de Battle Revolution, sus
  pases de combate y vestuario, ni los Mii y juguetes del Rancho.
* No se editan: Mundo Misterioso / regalos pendientes, Pokémon de HOME,
  datos de combate en línea, fotos, ni el contenido descargable fuera de su
  Pokédex.
* La legalidad no sustituye a PKHeX (ver [Legalidad](usuario/legalidad.md#límites)).
