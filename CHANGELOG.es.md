# Changelog

Todos los cambios relevantes del proyecto. El formato sigue
[Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y las versiones
[SemVer](https://semver.org/lang/es/). La primera versión publicada es
PKArkTools 0.1.0 (`0.1.0+1` en `apps/pkarktools/pubspec.yaml`); las secciones
que la siguen son los hitos internos de desarrollo que llevaron a ella.

Esta es la traducción al español de [CHANGELOG.md](CHANGELOG.md) (en inglés),
que es el que usan las notas de los Releases; se actualizan a la par.

## [Unreleased]

### Añadido

- **Generador de Living Dex.** «Generar Living Dex en la partida actual» en la
  ficha de la partida llena las cajas con un Pokémon de cada especie y forma
  que admite el juego (con formas regionales y cosméticas que se guardan en
  caja; sin formas de combate, fusiones ni dominantes/nobles), en orden de la
  Pokédex nacional, normal o variocolor, con el OT, ID, género e idioma del
  save. Cada uno sale de un encuentro real de esa versión (huevo eclosionado,
  estático o salvaje, evolucionado al nivel mínimo legal) elegido por PKHeX
  (`tool/gen_living_dex_data.sh`, comando `livingdex` del oráculo), o de un
  evento oficial para los míticos/legendarios que solo existieron así.
  Variocolor solo donde el juego lo permite. Avisa de que se sobrescriben las
  cajas (la versión anterior queda en el historial del Arca) y de lo que no
  cabe. `tool/check_living_dex_pkhex.sh` comprueba la Living Dex completa,
  normal y variocolor, de 16 juegos leída del save: 0 inválidos de 16938.
  Incluye los cortes de Furfrou donde se guardan en caja (Sol/Luna, USUL; en
  X/Y y ROZA vuelven a la forma base al dejarlos en la caja, así que se genera
  la base), 18 dibujos de Vivillon (Elegante y Poké Ball son de evento),
  Meowstic hembra en Gen 6–7, las 28 letras de Unown en DBPR y sus
  evoluciones por intercambio (con el entrenador del intercambio como último
  entrenador). Al guardar, un resumen lista todo lo que no se generó agrupado
  por motivo (forma de combate, fusión/dominante, vuelve a la base en la caja,
  solo por evento, necesita otra región, sin encuentro en esta versión,
  variocolor imposible, no cupo). Límites: los encuentros con semilla
  (algunos salvajes de Gen 3–4, símbolos de Espada/Escudo, Z-A) quedan
  normales si se pide variocolor; los míticos de Let's Go no se incluyen.
- **Eventos (Regalo Misterioso).** Toda la base de eventos de PKHeX (2922
  regalos de Pokémon, de Gen 3 a Gen 9: WC3/PCNY/PCJP, PCD/PGT, PGF, WC6, WC7,
  WB7, WC8, WB8, WA8, WC9, WA9), regenerada con `tool/gen_event_data.sh` y con
  carga perezosa.
  - **Explorador de eventos** (Dex → Eventos y desde la ficha de cada
    especie): búsqueda por especie, título de tarjeta, OT o nº de tarjeta y
    filtros por juego, generación, año, región, idioma, variocolor y tipo de
    distribución; la ficha muestra todos los datos fijos (OT/ID, movimientos,
    recordables, Ball, objeto, IV fijos, naturaleza, cintas, fechas) y permite
    exportar la tarjeta.
  - **Crear desde un evento** (hueco vacío → «Desde un evento») en cualquier
    partida compatible: se respetan los datos fijos y se aplican OT, ID, género
    e idioma de quien lo recibe como hace el juego, con variantes PID/IV que
    PKHeX da por válidas (métodos RNG de Gen 3/4, PID variocolor y con
    correlación de ID de Gen 5, semillas de Z-A). `tool/check_events_pkhex.sh`
    comprueba con PKHeX todos los eventos creables con dos entrenadores: 0
    inválidos de 5830.
  - **Importar tarjetas de evento** (.pgt, .pcd/.wc4, .pgf, .wc6/.wc6full,
    .wc7/.wc7full, .wb7, .wc8, .wb8, .wa8, .wc9, .wa9) y recibirlas en un hueco.
  - **Recibir tarjetas en la bandeja del Regalo Misterioso del juego** (X/Y,
    Rubí Omega/Zafiro Alfa, Sol/Luna, Ultrasol/Ultraluna): al importar una
    tarjeta WC6/WC7 se ofrece dejarla como tarjeta recibida para recogerla en
    el juego con el repartidor, como en la distribución original (comprobado
    con el oráculo PKHeX, comando `gifts`). Gen 4/5 guardan las tarjetas
    cifradas con el resto del bloque y Let's Go/Switch no guardan tarjetas
    pendientes: ahí se sigue recibiendo creando el Pokémon en un hueco.
  - **Dex y Ribbon Hunter**: los legendarios/míticos que ningún juego da sin
    un evento se marcan «Solo por evento · distribución terminada»; las
    cintas de evento cuentan como de origen y figuran como no obtenibles hoy.
  - **Legalidad**: reconoce los Pokémon que vienen de un evento (OT/ID, Ball,
    lugar y nivel fijos): sus movimientos especiales, objeto y Ball ya no dan
    avisos y no se aplican las tablas de encuentros.
- **Crear Pokémon oscuros en Colosseum y XD.** Un hueco vacío ofrece
  «Pokémon oscuro»: eliges uno de los encuentros oscuros del juego (PKHeX
  `Encounters3ColoShadow` / `Encounters3XD`, sin los de e-Reader japoneses) y
  se crea como lo capturaría el juego —especie, nivel, movimientos, lugar,
  Ball, tu OT/ID, origen Colosseum/XD, marca de encuentro fatídico en XD, id
  oscuro y medidor de corazón lleno—, oscuro o ya purificado con la Cinta
  Nacional. El PID y los IV salen del RNG de GameCube con semillas que
  respetan los bloqueos del equipo del entrenador, así que PKHeX los acepta.
  El editor también convierte cualquier Pokémon de esos juegos en oscuro,
  cambia su encuentro oscuro, ajusta el medidor y lo purifica o lo vuelve
  oscuro, con confirmación. En XD se rellena la entrada de la tabla de oscuros
  (especie, capturado, medidor) y el Strategy Memo anota la especie.
- Avisos de legalidad de Pokémon oscuros: id oscuro que no existe en el
  juego, especie que nunca es oscura en ese juego, PID/IV que no salen del
  generador CXD y oscuro variocolor en XD.

### Cambiado

- El logo de la barra lateral es mucho más grande (96 px en el rail
  extendido, 72 px en el compacto) con el nombre debajo.
- **La app de macOS ahora está firmada y notarizada.** El release se firma con
  Developer ID y *hardened runtime* y Apple lo notariza, así que se abre con
  doble clic (sin clic derecho → Abrir). También viene como
  `PKArkTools-vX.Y.Z-macos.dmg`; el `-macos.zip` que usa el actualizador de la
  app se mantiene.

### Corregido

- El checksum de los Pokémon de Let's Go (PB7) cubre los 0xE8 bytes que usa PKHeX.
### Añadido — Transferir Pokémon entre partidas («HOME local»)
- **Transferir Pokémon…** (encima del equipo, o ⋮ en la ficha): mueve (por
  defecto) o copia uno o varios Pokémon a otra partida del Arca, aunque sea
  de otra generación. Eliges la partida y el hueco de destino, revisas la
  vista previa (ruta de formatos, movimientos, Ball, objeto, cintas, nombre,
  habilidad, nivel y legalidad en el destino) y confirmas. Las dos partidas
  se guardan como copias nuevas; las originales siguen en el historial.
- `PkTransfer` en pkcore, portado de `EntityConverter` de PKHeX: Cápsula del
  Tiempo (Gen 1 ↔ 2), Consola Virtual → Gen 7, Pal Park, Poké Transfer, Poké
  Transporter, Pokémon Bank y Pokémon HOME entre Gen 7, Let's Go y los juegos
  de Switch. Solo rutas reales: hacia adelante (en ambos sentidos entre los
  de Switch), sin huevos entre formatos, sin Pokémon oscuros sin purificar,
  especie y forma deben existir en el destino, Spinda/Nincada no salen de BDSP.
- Rastreador de HOME: generado localmente (no nulo, único, se conserva en
  saltos posteriores). Un aviso destacado, que se acepta una vez por
  dispositivo, explica que la app solo garantiza la continuidad hasta Alola y
  recomienda no subir esos Pokémon a HOME; la opción «Llevar hasta Alola y
  continuar con Banco/HOME» y una guía paso a paso ofrecen la ruta oficial.
  Copiar un Pokémon con rastreador pide confirmación expresa (sería un clon);
  `HomeTrackerClones` detecta rastreadores repetidos.
- Validación: cada salto de generación se comprueba con el oráculo PKHeX
  (`tool/transfer_oracle.sh`, orígenes sintéticos legales generados con las
  plantillas de encuentro de PKHeX); todos los Pokémon convertidos son legales
  en PKHeX y los saves hacen round-trip con checksums válidos.
### Añadido — Herramientas
- **Pokémon Showdown**: importa uno o varios sets (especie y forma, apodo,
  género, objeto, habilidad, nivel, variocolor, naturaleza, EVs/IVs,
  movimientos, teratipo, felicidad, Gigamax, tipo del Poder Oculto) al equipo
  o a las cajas de la partida abierta, avisando de todo lo que el juego no
  permite y de los avisos graves de legalidad; los datos de origen que
  Showdown no trae se rellenan con las correcciones seguras del comprobador.
  Exporta el equipo o un Pokémon como texto de Showdown (copiar o menú de
  compartir del sistema).
- **Calculadora de stats e IVs** en el editor: estadísticas finales a nivel 50
  y 100, rangos de IVs a partir de las estadísticas que ves en el juego (con
  *Aplicar IVs* si son exactos) y tipo y potencia del Poder Oculto (Gen 2–7).
- **Ordenar cajas** por número de Pokédex, tipo, generación, living dex (cada
  especie en su hueco, repetidos detrás del último número), nivel o
  variocolor primero; todas las cajas o un rango, con vista previa y un solo
  paso de deshacer.
- **Formato oficial**: la regulación vigente de Pokémon Champions (VGC 2026
  Reg M-C) con sus reglas, listas de permitidos y prohibidos con buscador,
  marca de Megaevolución y qué Pokémon de tus partidas son elegibles y por qué
  no lo son los demás. Lista de especies generada desde el mod `champions` de
  Pokémon Showdown (`tool/gen_champions_data.py`, versionada con commit y
  fecha); la app indica las fechas sin confirmar y que falta la lista de
  objetos.
- **Tarjeta para compartir**: una imagen de un Pokémon (logo de la app, icono,
  nombre y forma, nivel, tipos, variocolor, naturaleza, habilidad, objeto,
  teratipo, origen, cintas, IVs/EVs y movimientos), en PNG o por el menú de
  compartir del sistema.
- Guías: `herramientas.md`, `formato-oficial.md` e
  `instalar.md` (con iPhone/iPad mediante AltStore y el refresco cada 7 días).

## [1.1.0] — 2026-11-24

PKArkTools 1.1.0 trae dos grandes novedades: **Ribbon Hunter**, una guía de
cintas por especie validada contra PKHeX (rutas, ranking por niveles, exportar
la guía y tus propios ejemplares), y seis juegos nuevos de GameCube,
Nintendo 64 y Wii: **Pokémon Colosseum**, **Pokémon XD: Tempestad Oscura**,
**Pokémon Stadium** y **Stadium 2**, **Pokémon Box: Rubí y Zafiro**,
**Pokémon Battle Revolution** y **My Pokémon Ranch**.

### Añadido — Ribbon Hunter
- Pestaña **Ribbon Hunter**: una guía de cintas por especie, no por ejemplar.
  Eliges cualquier especie y forma y ves todas las cintas que puede ganar un
  ejemplar, juego a juego de Gen 3 a Gen 9 (la ruta para convertirlo en Ribbon
  Master), con cómo conseguir cada una, su requisito, el origen recomendado (el
  más antiguo posible) y el máximo que se puede conseguir hoy.
- Grafo de transferencias solo hacia adelante con ids de juego estables:
  Colosseum y XD (por intercambio con Rubí/Zafiro/Esmeralda y Rojo Fuego/Verde
  Hoja), Parque Compi, Pokétransfer, Poké Transporter/Banco, Consola Virtual →
  Gen 7, HOME y Let's Go/GO de ida a HOME. Los avisos dicen cuándo transferir,
  cuándo existe por primera vez una forma regional y cuándo un juego solo admite
  la preevolución.
- La Cinta Nacional (purificar un Pokémon oscuro) y la Cinta Tierra (Monte
  Batalla) cuentan como cintas de juego de Colosseum/XD; los Pokémon oscuros son
  orígenes válidos.
- Sección «No disponibles hoy» (cintas de evento y la Torre Batalla Wi-Fi
  cerrada), marcas aparte (las que se ganan ya capturado en Escarlata/Púrpura y
  una marca de encuentro si se captura en Espada/Escudo o Escarlata/Púrpura) y
  los Recuerdos de Concurso/Combate de Gen 3–4.
- **Ranking por niveles**: las especies y formas se agrupan por el máximo de
  cintas que pueden ganar («87 cintas · 33 especies y formas», «86 cintas · 107
  especies y formas»…), con todos los niveles, iconos de muestra y el origen
  común destacado («Pokémon oscuro en Colosseum / XD»). Al entrar en un nivel
  se ve la lista completa, filtrable y en orden de Dex, y cada especie abre su
  guía.
- «Tus ejemplares de esta especie»: las cintas de cada uno y las que aún puede
  ganar desde su juego actual. El índice de la Dex guarda ahora las cintas de
  cada ejemplar (se reconstruye una vez).
- Compartir una guía como texto para foros o guardarla como imagen.
- Botón «Guía Ribbon Hunter» en la ficha de cada especie de la Dex.
- Verificado contra PKHeX: el oráculo construye cada especie/forma desde su
  mejor origen, la transfiere hacia adelante y le aplica todas las cintas
  válidas; las rutas de la app coinciden con 0 contradicciones en 1333 especies
  y formas (`tool/gen_ribbon_master_data.sh`, tabla de test versionada).

### Añadido — Juegos de GameCube, Nintendo 64 y Wii
- **Juegos de almacenamiento y estadio**: Pokémon Stadium y Stadium 2
  (Nintendo 64; internacional, japonés y el Pocket Monsters Stadium original,
  también volcados con el orden de bytes invertido), Pokémon Box: Rubí y
  Zafiro (`.gci`, Memory Card o datos sin cabecera de GameCube), Pokémon
  Battle Revolution y My Pokémon Ranch (Wii, archivos de la NAND de Dolphin).
  Detección por contenido, lectura completa, escritura con sus sumas (sumas
  por caja, sumas por bloque del Box, mitades cifradas con Genius Sonority y
  contadores de bits de Battle Revolution, SHA-1, contador y marcador de fin
  del Rancho), round-trip byte a byte y contenedor original conservado (orden
  de bytes, los otros perfiles de Battle Revolution). Los equipos registrados
  de Stadium se ven en solo lectura; los huecos del Rancho por encima de la
  capacidad de su nivel están bloqueados.
- Pokémon sueltos `.sk2`, `.bk4` y `.rk4`; los BK4 se editan como PK4 sin pérdidas.
- Arca: plataformas Nintendo 64 y Wii, colores de los cinco juegos, nombres de
  archivo principal (`PbrSaveData`, `pokemonranch.bin`, la extensión original
  de N64) y LEEME de las carpetas de juego con cómo sacar cada save; los
  juegos de solo cajas no muestran una sección de equipo vacía.
- **Pokémon Colosseum y Pokémon XD: Tempestad Oscura (GameCube).** Se leen y
  escriben saves en `.gci` (exportados con Dolphin o de su carpeta GCI),
  imágenes completas de Memory Card (`.raw`, `.gcp`, `.mci`) y datos sin
  cabecera, detectando por contenido el código de juego (`GC6x`/`GXXx`) y la
  región (USA, Europa, Japón). Se leen entrenador, equipo, cajas, bolsa
  (incluidos los discos y colonias de XD), Strategy Memo y **Pokémon
  oscuros** (id oscuro, medidor de corazón, capturado y purificado); al
  escribir se rehace el cifrado en cadena con SHA-1 (Colosseum) o el de
  Genius Sonority (XD) y todas las sumas, se verifica la exportación y se
  conserva el contenedor: la cabecera del `.gci`, o la tarjeta con solo los
  bloques del save reescritos (siguiendo la tabla de bloques, sin tocar el
  directorio). Un save sin cambios se escribe idéntico byte a byte.
- Importar y exportar Pokémon sueltos `.ck3`/`.xk3`; un `.pk3` de un save de
  GBA se puede colocar en Colosseum/XD y se convierte con la región del save.
- Editor de Pokémon: sección **Pokémon oscuro** con el estado, el id oscuro y
  el medidor de corazón, y *Marcar como purificado* con confirmación, que
  añade también la Cinta Nacional.
- Arca: carpetas de juego de Colosseum y XD con un LEEME que explica qué
  exportar de Dolphin, colores de versión para los dos juegos y archivo
  principal con el nombre original del `.gci`/`.raw`. Una Memory Card con los
  dos juegos se importa como un `.gci` por juego.
- Legalidad de origen Colosseum/XD: Pokémon oscuros, iniciales, regalos,
  intercambios y Poké Spots de las tablas de PKHeX (con nombres de lugares),
  id oscuro contra la especie, rango del medidor de corazón, la Cinta
  Nacional justo en los oscuros purificados, la marca de encuentro fatídico
  de XD y que un Pokémon oscuro no salga del juego sin purificar. Un Pokémon
  purificado de XD que se mueve a un save de GBA recibe las mismas marcas
  que en un intercambio en el juego.
- Oráculo PKHeX: comando `write`, imágenes de Memory Card y campos oscuros en
  el volcado; `tool/gen_gc_data.py` y `packages/pkcore/tool/write_synthetic.dart`.

### Limitaciones conocidas
- Colosseum/XD: no se comprueba la correlación PID/IV del generador de
  números aleatorios (bloqueos de equipo de los Pokémon oscuros); una Memory
  Card con los dos juegos se importa como dos `.gci` (el `.raw` editado solo
  se reescribe si tiene un único save de Pokémon); no se edita el Purificador
  de XD ni la guardería.
- No se editan los equipos registrados de Stadium, el buzón de Stadium 2, los
  perfiles 2–4 de Battle Revolution (se conservan intactos), sus pases de
  combate y vestuario, ni los Mii y juguetes del Rancho. Las cajas de Stadium
  son listas compactas: al vaciar un hueco los siguientes avanzan. Los huecos
  del Rancho por encima de la capacidad de su nivel están bloqueados.
- Stadium, Stadium 2, Box y el Rancho no tienen entrenador propio; en el Arca
  aparecen como «STADIUM», «STADIUM 2», «BOX» o el dueño del rancho.
- Ribbon Hunter es una guía por especie: las cintas de evento y la Torre
  Batalla Wi-Fi cerrada se listan como no disponibles hoy, y las rutas son las
  que PKHeX acepta, no todos los caminos posibles.

### Corregido
- La marca de encuentro fatídico de los Pokémon de Gen 3 (PK3) ahora se lee y
  se puede cambiar; antes siempre se leía desactivada.

## [1.0.4] — 2026-11-24

### Corregido
- Dex: una forma especial con la variante variocolor desbloqueada muestra el
  icono variocolor también cuando la normal está desbloqueada. En la 1.0.3 la
  tarjeta volvía al icono normal salvo que solo estuviera desbloqueada la
  variocolor, así que un Charizard Gigamax (o cualquier Mega, Primigenio,
  Ultra o Gigamax) con las dos variantes se veía sin variocolor. Afectaba a
  las 134 formas especiales cuando tenían las dos variantes; los archivos de
  iconos, el índice y la caché ya eran correctos.

### Cambiado
- Tarjetas de formas especiales: cada pastilla (Normal, Variocolor) muestra
  el icono de su variante al desbloquearse, y una insignia ✦ marca la tarjeta
  dibujada en variocolor. Si a una forma le faltara el variocolor en la
  fuente, la variante variocolor usaría el icono normal con la insignia ✦ en
  vez de pasar por normal sin avisar.
- Los tests recorren las 134 formas especiales × {normal, variocolor}: iconos
  distintos, en el índice, en «Descargar todos» / «Reparar iconos» y con su
  propio archivo en la caché.
- Capturas nuevas: Charizard Gigamax normal y variocolor lado a lado y Mega
  Charizard X variocolor (escritorio y Android); la guía de iconos lista las
  formas cuyo variocolor oficial apenas cambia respecto al normal.

## [1.0.3] — 2026-11-24

### Añadido
- Las formas especiales tienen icono propio: las 34 Gigamax (una por forma
  en Toxtricity y Urshifu), las 49 Megas de Leyendas Z-A y Mega Dimensión,
  además de las Megas de Gen 6/7, Kyogre/Groudon primigenios y Ultra
  Necrozma, cada una con su variocolor. Salen de otras carpetas del mismo
  commit fijado de `smogon/sprites` (volcado de iconos de caja de HOME,
  iconos de Pokémon Champions y renders de HOME) y siguen descargándose bajo
  demanda. Los tipos de Silvally y las formas Teracristal y Astral de
  Terapagos también tienen el suyo.
- Dex: las tarjetas de formas especiales (y sus siluetas bloqueadas) usan el
  icono de la forma y muestran el variocolor cuando está desbloqueado; en
  «Tus ejemplares», un Pokémon con el factor Gigamax se ve Gigamax. Una forma
  sin icono mantiene el de la especie con una insignia G / MEGA / P / ULTRA.

### Cambiado
- «Descargar todos los iconos» pasa a ~22 MB (~2400 archivos); «Reparar
  iconos» cubre los nuevos. La guía de iconos lista las fuentes y las formas
  sin icono en ninguna fuente fiable (modos de Koraidon/Miraidon, Pichu
  picoreja).
- Capturas de la Dex (escritorio, teléfono, Android e iOS) con los iconos
  nuevos.

## [1.0.2] — 2026-11-23

### Cambiado
- Capturas y demo renovadas: todas las imágenes de los README y de `docs/`
  muestran ya la 1.0 (pestaña Dex, iconos HOME grandes, logo nuevo, versión
  actual e historial plegado en el Arca, NAS y actualizaciones), y el vídeo de
  demostración y su vista previa del README incluyen la Dex con una forma
  Gigamax desbloqueada.

### Corregido
- Desborde de la tarjeta de partida: con el equipo completo, la tarjeta del
  Arca se desbordaba ~4 px en una ventana de 1000×700; ahora los iconos del
  equipo se reducen para caber en tarjetas estrechas.

## [1.0.1] — 2026-11-23

### Cambiado
- Nuevo icono de la app: logo más grande sobre el fondo oscuro de la app. En
  todas las plataformas (icono adaptativo, antiguo y redondo de Android, iOS,
  macOS, Windows y Linux) el logo completo ocupa ~84 % del icono sobre el
  azul noche de la app (`#151927`), sin sombra; en Android es tan grande como
  permite la zona segura de 66 dp, así que ni el círculo ni el squircle lo
  recortan.
- Logo más grande dentro de la app: ahora se recorta a su contenido y se ve
  mayor en la barra lateral (48 px de alto), en la bienvenida (128 px en
  teléfono, 160 px en escritorio) y en Ajustes › Acerca de (88 px).

## [1.0.0] — 2026-11-23

**PKArkTools 1.0: el Arca oficial.** Esta versión añade la **Dex**, una
Pokédex global de todas las partidas del Arca, y cierra la serie 0.1.x.
Respecto a 0.1.x, la 1.0 reúne en una app para Android, iOS, macOS, Windows y
Linux: un Arca de copias inmutables y versionadas en la carpeta que elijas
(varios dispositivos, carpetas de juego como bandeja de entrada, reindexar,
zip); importar desde archivos, carpetas, emuladores y Checkpoint/JKSM; lectura
**y edición** de todas las generaciones, de Rojo/Azul a Escarlata/Púrpura y
Leyendas Z-A (Pokémon, cajas, entrenador, inventario, Pokédex, eventos,
cintas, origen); legalidad con correcciones seguras; detección de saves
dañados y reparación de checksums; formas regionales y alternativas con sus
propios datos; actualizaciones desde la app; y ahora la Dex.

### Añadido
- **Pestaña Dex** (junto a Arca, Actividad y Ajustes): las 1025 especies de la
  Nacional llenas con **todas las partidas**: silueta (sin registrar),
  atenuada (vista), a color (capturada) e insignia ✦ si tienes un variocolor.
- **Progreso**: capturados, vistos, variocolor y formas desbloqueadas, con
  desglose por generación/región y por juego (especies del juego frente a las
  registradas en tus partidas de ese juego).
- **Ficha de especie** solo con datos objetivos (sin textos de la Pokédex ni
  arte oficial): tipos, estadísticas base, habilidades (incluida la oculta),
  ratio de género, la familia evolutiva con sus métodos (de los árboles de
  evolución de PKHeX), formas coleccionables con sus tipos y estadísticas,
  juegos donde aparece, **tus registros** (en qué partidas está vista o
  capturada) y **tus ejemplares** (juego, entrenador, apodo, nivel, variocolor,
  forma, factor Gigamax y hueco), cada uno abre su partida **en su caja con el
  Pokémon resaltado**.
- **Formas especiales desbloqueables**, normal y variocolor por separado, desde
  una tabla de reglas (`SpecialForms`) verificada contra PKHeX: Megas por juego
  (X/Y, ROZA, Sol/Luna, Ultrasol/Ultraluna, Let's Go y Leyendas Z-A, con las
  nuevas de Z-A y Mega Dimensión), Kyogre/Groudon primigenios, Ultra Necrozma
  (Necrozma fusionado en USUL) y Gigamax (un ejemplar con el factor Gigamax del
  PK8 en Espada/Escudo; una por forma en Urshifu y Toxtricity). La piedra u
  orbe en la mochila de esa partida se muestra como indicador. Las bloqueadas
  son siluetas que explican cómo desbloquearlas; Eternamax nunca se
  desbloquea. Reglas: [guía de la Dex](docs/usuario/dex.md).
- **Filtros y búsqueda**: capturados, faltantes, solo vistos, variocolor,
  formas por desbloquear, tipo, generación/región y juego; búsqueda por nombre
  (español o inglés, sin acentos) o número; orden por número o nombre.
- **Living dex** (ajustes de la Dex): una especie cuenta como capturada solo si
  tienes un ejemplar en equipo o cajas, para ver lo que de verdad te falta.

### Rendimiento
- El índice de la Dex se calcula **en segundo plano** al reindexar el Arca o
  importar, una vez por copia (por SHA-256), y se cachea en el índice local
  (drift, esquema 5, `dex_scans`) de forma incremental. Abrir la pestaña solo
  cruza la caché: 50 partidas sintéticas (1500 ejemplares) se construyen,
  agregan y filtran en unos 10 ms; escanear esas 50 partidas lleva unos 0,3 s,
  una sola vez.

### Corregido
- **♂/♀ y otros símbolos ya no salen como un cuadro** (Nidoran♂/♀, el
  selector de género, objetos con ★, atajos con ⌘, ⚠): la app incluye
  subconjuntos de Noto Sans Symbols y Noto Sans Symbols 2 (SIL OFL 1.1) como
  fuente de respaldo, así que se ven igual en Android, iOS, macOS, Windows,
  Linux y en las capturas. Un test comprueba que cada carácter de los nombres
  de especies, formas, movimientos, habilidades, objetos, lugares, cintas y
  eventos (es/en) tiene glifo. El lugar de relleno «－－－» de Gen 5+ ahora se
  muestra como «un lugar desconocido».

### Desarrollo
- pkcore: `GlobalDex`, `SaveDexScan`, `SpecialForms`, `DexForms` y
  `Evolutions`; el oráculo PKHeX vuelca la tabla de Mega/Primigenio/Ultra/
  Gigamax y los árboles de evolución (`tool/gen_dex_tables.sh`).
- Tests de las reglas de desbloqueo (Gigamax con factor en EspEsc, normal y
  variocolor; Megas por juego con piedra; Z-A; nada fuera de juegos válidos;
  huevos), cruce de varias partidas, living dex, filtros, rendimiento y diseño
  en 320×568, 360×800, 430×932 y escritorio.

## [0.1.5] — 2026-11-23

Las formas regionales y alternativas usan sus propios datos en vez de los de
la especie base: Decidueye de Hisui es Planta/Lucha, no Planta/Fantasma. Es
la primera versión que la app puede instalar con su propio botón **Buscar
actualizaciones**.

### Corregido
- **Tipos, estadísticas base y habilidades de las formas** (Alola, Galar,
  Hisui, Paldea, Tauros de Paldea, Rotom, Oricorio, Lycanroc, Urshifu,
  Calyrex, Necrozma, Kyurem, Deoxys, Giratina, Shaymin, los genios, Meloetta,
  Hoopa, Zygarde, Ogerpon, Basculegion, Wormadam, Castform, megas en Let's Go
  y Z-A…): los chips de tipo del equipo, las cajas, la ficha, el editor, la
  Pokédex, la comparación y las tarjetas de partida, las estadísticas
  calculadas y las habilidades salen ahora de los datos de la forma **en el
  juego del save**, incluidos los tipos que cambiaron entre generaciones
  (Gardevoir o Snubbull no son Hada en Gen 3).
- **Legalidad por forma**: los movimientos aprendibles siguen la cadena
  evolutiva de la forma (Sandslash de Alola aprende lo de Sandshrew de Alola),
  los encuentros tienen que coincidir en forma (un Growlithe de Hisui no sale
  de un encuentro de Growlithe de Kanto), las habilidades se comprueban con las
  de la forma y se avisa de una forma que no existe en el juego (Decidueye
  normal en Leyendas Arceus).
- La lista de especies ya no ofrece entradas de formas como especies en
  algunos juegos (p. ej. las «especies» 494+ en Diamante/Perla), y las especies
  que solo existen como forma regional (Growlithe en Leyendas Arceus) están
  disponibles.
- Los Pokémon nuevos reciben el learnset, las habilidades y el género de la
  forma y, en Escarlata y Púrpura, el teratipo del primer tipo de la forma
  (Ogerpon: el de su máscara).

### Añadido
- **Nombres de forma**: «Decidueye (Hisui)», «Rotom (Lavado)», «Tauros
  (Paldea Ardiente)» en la ficha, el equipo, las cajas, los avisos de
  legalidad y la comparación. El selector **Forma** del editor muestra por
  nombre las formas que existen en el juego y al cambiarla actualiza tipos,
  estadísticas, habilidad, género y (Ogerpon) teratipo. La Pokédex nombra las
  formas vistas y muestra cada entrada con su forma.
- Las tarjetas de partida recuerdan las formas del equipo (las entradas
  anteriores muestran la forma base hasta reindexar).

### Desarrollo
- `SpeciesForms` en pkcore: tipos, estadísticas base, habilidades, género,
  presencia, nombres y preevoluciones por (especie, forma, juego).
- El oráculo PKHeX tiene un comando `forms`; `tool/gen_form_data.sh` genera
  los nombres de forma y una tabla versionada de **11 888** combinaciones
  (juego, especie, forma) de todos los juegos de Gen 3–9, que
  `form_data_pkhex_test.dart` compara con pkcore: tipos, estadísticas base,
  habilidades, género, presencia y preevolución, 0 diferencias.

## [0.1.4] — 2026-11-23

PKArkTools puede buscar versiones nuevas y actualizarse: en Android descarga
el APK, comprueba que está firmado con el mismo certificado que la app
instalada y abre el instalador del sistema; en escritorio descarga el archivo
del release donde elijas; en iOS abre la página del release.

### Añadido
- **Buscar actualizaciones** en Ajustes › Acerca de, con la versión
  instalada, y **Buscar actualizaciones automáticamente** (activada por
  defecto): al abrir, como mucho una vez cada 24 horas. La única conexión nueva
  es `api.github.com/repos/Rodriqe/PKArkTools/releases/latest`, sin token y
  con el ETag guardado (una respuesta sin cambios es un 304 y no cuenta para el
  límite de GitHub). La búsqueda automática falla en silencio; el botón explica
  por qué no se pudo comprobar (sin red, límite de GitHub).
- **Aviso de versión nueva**: una tarjeta discreta arriba de Ajustes y un punto
  en el icono de Ajustes, «PKArkTools 0.1.x disponible». Abre una hoja con las
  novedades del release y **Actualizar** y **Omitir esta versión**.
- **Android**: descarga el APK con progreso y cancelable, comprueba su tamaño
  y que su nombre de paquete y sus certificados de firma (SHA-256) coinciden
  con los de la app instalada antes de entregarlo al instalador del sistema;
  si no, no instala nada y lo explica. La primera vez lleva a «Instalar apps
  desconocidas» con una explicación. El APK se borra tras instalar o al
  cancelar. Permiso nuevo: `REQUEST_INSTALL_PACKAGES`.
- **macOS, Windows y Linux**: descarga el zip, el instalador o el tar.gz del
  release con un diálogo «Guardar» que empieza en Descargas y explica el paso
  manual; **Abrir la página del release** está siempre. **iOS** abre la página
  del release.
- Las descargas solo siguen enlaces HTTPS a este repositorio en los dominios
  de GitHub, redirecciones incluidas. Ver
  [Primeros pasos › Actualizar la app](docs/usuario/primeros-pasos.md#7-actualizar-la-app)
  y [Seguridad de datos](docs/seguridad-datos.md).

## [0.1.3] — 2026-11-23

El Arca puede estar en una carpeta de red (NAS): en un Mac con un recurso SMB
(también AFP/NFS/WebDAV) y en Android con un proveedor de documentos SMB. La
app detecta el recurso, avisa claramente cuando no está montado en vez de
tratarlo como un Arca vacía, sondea los cambios de otros dispositivos mientras
está abierta, reintenta los errores pasajeros de red y trata los nombres con
acentos tal como los devuelve SMB en macOS. Probado en un NAS SMB real desde un
Mac; **Android sobre SMB/SAF aún no se ha probado en un dispositivo**.

### Añadido
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
