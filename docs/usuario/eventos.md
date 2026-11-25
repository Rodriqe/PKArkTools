# Eventos (Regalo Misterioso)

PKArkTools incluye la base de eventos de PKHeX: los 2922 regalos de Pokémon
repartidos oficialmente de Gen 3 a Gen 9 (eventos de Gen 3, Pokémon Center,
tarjetas de DS, 3DS y Switch, y regalos de Pokémon HOME). Todas esas
distribuciones han terminado.

## Explorador

Abre **Dex → Eventos** (icono de regalo) o, en la ficha de una especie, el
botón «N eventos oficiales». Puedes buscar por especie, título de la tarjeta,
OT o número de tarjeta, y filtrar por juego, generación, año, región, idioma,
variocolor y tipo de distribución. Toca un evento para ver todos sus datos
fijos (OT e ID —o «el de quien lo recibe»—, nivel, Ball, lugar, movimientos,
recordables, objeto, IV y naturaleza fijos, cintas, fechas e idiomas) y, si
tiene archivo de tarjeta, **exportarla** (`.pcd`, `.pgf`, `.wc6`… como en
PKHeX). Gen 3 no tiene formato de tarjeta.

## Se actualiza sola

La base no espera a una versión nueva de PKArkTools:

1. Cada día, la GitHub Action
   [`events-data.yml`](../../.github/workflows/events-data.yml) clona el
   último commit de [PKHeX](https://github.com/kwsch/PKHeX) en la carpeta
   temporal del runner (nunca en el repositorio), regenera
   [`data/events/events.json`](../../data/events/events.json) con
   `tool/gen_event_data.sh` y lo valida: el esquema,
   `tool/check_events_pkhex.sh` (crea cada evento para dos entrenadores y
   PKHeX los analiza; **un solo inválido** hace fallar el job) y los tests de
   eventos de pkcore. Si el total baja más de un 10 %, también falla. **Solo
   si cambiaron los eventos** lo sube a `main` (autor `github-actions[bot]`).
   Si algo falla no se sube nada y la app sigue con la última versión buena.
2. Al abrir el explorador (como mucho una vez cada 24 horas) la app descarga
   ese JSON, comprueba que es válido y lo guarda en su carpeta de datos.
   **Buscar eventos nuevos** consulta en el momento.
3. Sin conexión, o si la descarga falla o no es válida, usa la copia guardada
   o la que lleva la app (la más reciente de las dos).

La pantalla indica **«N eventos · actualizados el … · PKHeX …»** (fecha de
los datos y commit de PKHeX) y marca con **Nuevo** los eventos que no estaban
la última vez que abriste el explorador.

**Privacidad**: es un GET anónimo a GitHub, sin cabeceras propias ni
identificadores; no se envía nada de tus partidas.

Si el JSON publicado tiene un `schemaVersion` más nuevo del que entiende tu
versión de la app, se ignora y se sugiere actualizar PKArkTools.

**Por qué los eventos sin cambios conservan su entrada**: PKHeX genera las
plantillas con números al azar y la fecha del día, así que dos ejecuciones
nunca dan el mismo archivo. Cada evento cuya huella estable (tarjeta,
especie, forma, nivel, variocolor, método, fechas de distribución) ya estaba
reutiliza su entrada anterior, y el JSON solo cambia cuando cambian los
eventos. `check_events_pkhex.sh` los vuelve a comprobar igualmente con el
PKHeX nuevo. Para generarlo todo de nuevo: `EVENTS_FRESH=1
tool/gen_event_data.sh` (o la opción *fresh* al lanzar la Action a mano).

En local, con otra copia de PKHeX:

```bash
git clone --depth 1 https://github.com/kwsch/PKHeX .scratch/PKHeX
PKHEX_DIR=$PWD/.scratch/PKHeX tool/gen_event_data.sh
PKHEX_DIR=$PWD/.scratch/PKHeX tool/check_events_pkhex.sh
```

## Crear un Pokémon de evento

En una caja, toca un hueco vacío y elige **Desde un evento**. Solo aparecen los
eventos que se pueden crear en esa partida (mismo formato). Elige el idioma del
Pokémon (si el evento se repartió en varios) y, si el evento lo permite,
variocolor. Se crea como lo entregaría el juego: se respetan los datos fijos de
la tarjeta y se aplican tu OT, ID, género e idioma cuando el evento los toma de
quien lo recibe. PID e IV salen de variantes que PKHeX da por legales (incluidos
los métodos RNG de Gen 3/4). Si el evento era de otro juego de la misma
generación, se crea con ese juego de origen, como si llegara por intercambio.

**Importar tarjeta de evento** (mismo menú) lee un archivo `.pgt`, `.pcd`,
`.wc4`, `.pgf`, `.wc6`, `.wc6full`, `.wc7`, `.wc7full`, `.wb7`, `.wc8`, `.wb8`,
`.wa8`, `.wc9` o `.wa9`, lo reconoce en la base y lo recibe en ese hueco.

Unos pocos eventos solo se pueden consultar: los que PKHeX no puede generar
legales y dos huevos japoneses de Gen 3 cuyo PID variocolor depende de tu ID.

## Legalidad

Al validar, PKArkTools reconoce los Pokémon que vienen de un evento (por su OT,
ID, Ball, lugar y nivel fijos): sus movimientos especiales, objeto y Ball no
generan avisos. Ver [Legalidad y avisos](legalidad.md).

## Recibir una tarjeta en la bandeja del juego

En X/Y, Rubí Omega/Zafiro Alfa, Sol/Luna y Ultrasol/Ultraluna, al **importar
una tarjeta** (.wc6/.wc6full, .wc7/.wc7full) la app pregunta cómo recibirla:

- **En la bandeja del juego**: queda como tarjeta recibida (sin recoger) y la
  recoges en el juego con el repartidor del Centro Pokémon, como en la
  distribución original. Si ya está o la bandeja está llena, se avisa.
- **Crear el Pokémon en este hueco**: como antes.

En Gen 4 y Gen 5 las tarjetas se guardan cifradas con el resto del bloque y en
Let's Go y la Switch el juego no guarda tarjetas pendientes (el regalo se
recibe al momento): ahí la tarjeta se recibe creando el Pokémon en un hueco.

## Distribución terminada

En la Dex, los legendarios y míticos que ningún juego da sin un evento (Mew,
Celebi, Jirachi, Deoxys, Manaphy, Shaymin, Arceus, Magearna, Zarude…)
muestran «Solo por evento · distribución terminada». En Ribbon Hunter, las
cintas de evento cuentan como cintas de origen y aparecen en «No disponibles
hoy».
