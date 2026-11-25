# Formato oficial (Pokémon Champions)

**Dex → 🏆 Formato oficial** (o el botón **Formato oficial** de una partida)
muestra el formato oficial **vigente** de combates de Pokémon, que desde 2026
se juega en **Pokémon Champions**.

* **Regulación**: nombre (p. ej. *VGC 2026 Reg M-C*), fechas, reglas (nivel
  50 con ajuste a la baja, equipo de 6 y se eligen 4 en dobles o 3 en
  individuales, cláusula de especie, cláusula de objeto, legendarios
  restringidos y singulares prohibidos, Megaevolución, hojas de equipo
  abiertas) y la lista de **Pokémon permitidos** (con «M» si tienen
  Megaevolución) y **prohibidos**, con buscador.
* **Tus Pokémon**: revisa la copia más reciente de cada partida del Arca y
  dice cuáles son elegibles y, para los demás, por qué no (huevo, Pokémon
  oscuro, singular, restringido, especie o forma fuera de la lista). Las
  formas solo estéticas (colores, diseños) cuentan como la forma permitida.
  Los Pokémon con avisos graves de legalidad se marcan: Pokémon HOME podría
  rechazarlos. Para usarlos hay que llevarlos a Champions por HOME.

Solo cuenta la regulación **vigente** (la que vale hoy según sus fechas
oficiales): su lista, sus reglas y sus fechas. De la **siguiente** solo se
muestran el nombre y cuándo empieza («Termina el 2 dic 2026. Siguiente: VGC
2026 Reg M-D (desde el 2 dic 2026)»); tus Pokémon no se comparan con ella
hasta que empiece.

Lo que la fuente no dice no se inventa: si la lista oficial de una
regulación todavía no está publicada, no se fabrica (ver más abajo), la
**siguiente regulación** sale como «aún sin anunciar» hasta que el juego la
anuncie, y la lista de **objetos permitidos** no está incluida (consúltala
en el juego).

## Se actualiza solo

No hace falta esperar a una versión nueva de PKArkTools para ver la
regulación vigente ni para que cambie de una a otra:

1. Cada día a las **02:30 UTC** (las regulaciones cambian a las 02:00 UTC),
   la GitHub Action
   [`champions-data.yml`](../../.github/workflows/champions-data.yml)
   descarga las **fuentes oficiales** (tabla de abajo) y, para comprobarlas,
   las de Pokémon Showdown; regenera
   [`data/champions/champions.json`](../../data/champions/champions.json) y
   lo valida. **Solo si cambiaron los datos** lo sube a `main` (autor
   `github-actions[bot]`). El día en que empieza una regulación nueva, la
   ejecución de las 02:30 UTC ya la pone como vigente.
2. Al abrir **Formato oficial** (como mucho una vez cada 12 horas), la app
   descarga ese JSON de
   `https://raw.githubusercontent.com/Rodriqe/PKArkTools/main/data/champions/champions.json`,
   comprueba que es válido y lo guarda en el índice local. **Buscar
   actualizaciones** consulta en el momento.
3. Sin conexión, o si la descarga falla o no es válida, usa la última copia
   guardada o la que lleva la app (la más reciente de las dos).

Si la fuente oficial no responde o cambia algo que el generador no entiende,
el job falla **sin subir nada** y la app sigue con el último JSON bueno
(nunca se publica una lista vacía). Si solo falla Showdown, se reutilizan
las reglas y las Megas del último JSON y se avisa en el log.

La Action hace pocas peticiones por ejecución (el feed, la página de la
regulación vigente y la de la siguiente, y su lista si ya está publicada),
con un User-Agent genérico del proyecto, timeouts y como mucho dos
reintentos.

La pantalla indica **«Actualizado el … · fuente: Showdown …»** (fecha de los
datos y commit de Showdown con el que se comprobaron), cuándo termina la
regulación y cuál es la siguiente. Con fechas oficiales no sale el aviso de
«fechas sin confirmar».

**Privacidad**: la app hace un GET anónimo a GitHub, sin cabeceras propias
ni identificadores (ni siquiera la versión de la app); no se envía nada de
tus partidas. La app no consulta las fuentes oficiales directamente: lo hace
la Action.

Si el JSON publicado tiene un `schemaVersion` más nuevo del que entiende tu
versión de la app, se ignora y la pantalla sugiere actualizar PKArkTools.

## De dónde salen los datos

Primero, las **fuentes oficiales** del juego; Pokémon Showdown (no oficial)
solo para lo que el juego no publica en un formato legible y para comprobar.

| Dato | Fuente | Notas |
|---|---|---|
| Qué regulación está vigente, la siguiente, nombre y **fechas y horas exactas (UTC)** | **Oficial**: noticias del juego, [`list.json`](https://champions-news.pokemon-home.com/en/json/list.json) (las entradas con `infoKind` 12 son regulaciones) y la página de cada una, p. ej. [M-C](https://champions-news.pokemon-home.com/en/page/816.html) y [M-D](https://champions-news.pokemon-home.com/en/page/878.html) (también en `/es/` y `/es-la/`) | `datesConfirmed: true` y `datesSource` = la página oficial |
| **Especies y formas permitidas** de la vigente | **Oficial**: «Eligible Pokémon» enlazado desde la página de la regulación (p. ej. [la de M-C](https://web-view.app.pokemonchampions.jp/battle/pages/events/rs178713870219xeaaio/en/pokemon.html)); lleva la lista como `const pokemons = [["0026-001",1,"Raichu (Alolan Form)"], …]` | Los ids especie-forma del juego se traducen a los de Showdown (ver abajo). Si aún no está publicada: la de Showdown si ya tiene esa regulación (`allowedSource: "showdown"`); si tampoco, error y se mantiene el último JSON |
| Megaevoluciones | Showdown, [`data/mods/champions/formats-data.ts`](https://github.com/smogon/pokemon-showdown/blob/master/data/mods/champions/formats-data.ts), más las Megas nuevas que anuncia la página oficial | El juego no publica la lista completa |
| Reglas (*Flat Rules*: nivel 50, cláusulas, singulares y restringidos prohibidos) | Showdown, `config/formats.ts` y `data/rulesets.ts` | Coinciden con las del juego |
| Comprobación de la lista | Showdown, `formats-data.ts` (especies sin `isNonstandard`) | Las diferencias salen como **aviso** en el log de la Action, no como error |

Todo se guarda en `data/champions/champions.json` y su copia integrada
`packages/pkcore/lib/src/data/generated/champions_data.dart` (generados). El
JSON sigue el esquema v1 que entiende PKArkTools 2.0; los campos nuevos
(`official`, `officialName`, `startsAt`, `endsAt`, `eligibleUrl`,
`allowedSource`, `allowedPublished`) son opcionales y la 2.0 los ignora.
Solo se escriben la regulación vigente y la siguiente.

**Traducción de ids** ([`tool/champions_official.py`](../../tool/champions_official.py)):
la forma `000` es la base (`0083-000 Farfetch’d` → `farfetchd`); las demás
se reconocen por la etiqueta del nombre (`(Alolan Form)` → `alola`,
`(Female)` → `f`, `(Jumbo Variety)` → `super`…). Las entradas sin etiqueta
con otra forma son un icono de la especie con todas sus formas (Vivillon,
Maushold); excepciones: Floette (solo la de la Flor Eterna) y Squawkabilly
(los cuatro plumajes). Una etiqueta desconocida es un error: se añade a
`FORM_LABELS` y se vuelve a generar.

**M-C, oficial frente a Showdown**: 264 ids frente a 267. La oficial incluye
**Meowstic hembra** (Showdown no la tiene en el mod, así que la 2.0 la daba
por «forma no permitida»); Showdown incluye **Castform Sol/Lluvia/Nieve y
Aegislash Filo**, formas que solo existen en combate y que la lista oficial
no pone (no cambian nada: nunca están guardadas en una partida).

### Referencias oficiales

* [Play! Pokémon: reglas y recursos de torneos](https://www.pokemon.com/us/play-pokemon/about/tournaments-rules-and-resources)
* [Manual de torneos VGC (PDF)](https://www.pokemon.com/static-assets/content-assets/cms2/pdf/play-pokemon/rules/play-pokemon-vgc-tournament-handbook-en.pdf)
* [Pokémon Champions: cómo se juega](https://champions.pokemon.com/en-us/gameplay/)
* Noticias: [Regulation Set M-C](https://www.pokemon.com/us/news/get-ready-for-regulation-set-m-c-in-pokemon-champions)
  y [Regulation Set M-D](https://www.pokemon.com/us/news/regulation-set-m-d-is-coming-to-pokemon-champions)

## Cómo actualizarla a mano

Normalmente no hace falta (lo hace la Action). Para probar el generador en
local:

```bash
python3 tool/fetch_champions_official.py .scratch/official
python3 tool/fetch_champions_sources.py .scratch/champions   # imprime commit= y date=
python3 tool/gen_champions_data.py --official .scratch/official \
    --showdown .scratch/champions --commit <commit> --date <AAAA-MM-DD>
python3 tool/test_gen_champions_data.py
```

Escribe `data/champions/champions.json` y `champions_data.dart` (sin
`--showdown`, toma las reglas y las Megas del JSON anterior). `--now
2026-12-02T02:30:00Z` simula otra fecha. Los tests usan copias reales de las
fuentes oficiales en [`tool/fixtures/champions_official/`](../../tool/fixtures/champions_official/).
Después pasa `dart test test/tools_test.dart` en `packages/pkcore` (comprueba,
entre otras cosas, que todos los ids se traducen a especie y forma).
