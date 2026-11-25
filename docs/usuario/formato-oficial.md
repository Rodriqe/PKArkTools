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

Lo que la fuente no dice no se inventa: las **fechas** se marcan como «sin
confirmar» si no hay una fuente oficial, la **siguiente regulación** sale
como «aún sin anunciar» hasta que Showdown la incluya, y la lista de
**objetos permitidos** no está incluida (consúltala en el juego).

## Se actualiza solo

No hace falta esperar a una versión nueva de PKArkTools para ver la
regulación vigente:

1. Cada día, la GitHub Action
   [`champions-data.yml`](../../.github/workflows/champions-data.yml) descarga
   de Pokémon Showdown los tres archivos de la tabla de abajo, regenera
   [`data/champions/champions.json`](../../data/champions/champions.json) y
   lo valida. **Solo si cambiaron los datos** lo sube a `main` (autor
   `github-actions[bot]`). Si Showdown cambia algo que el generador no
   entiende, el job falla sin subir nada y la app sigue con la última
   versión buena.
2. Al abrir **Formato oficial** (como mucho una vez cada 12 horas), la app
   descarga ese JSON de
   `https://raw.githubusercontent.com/Rodriqe/PKArkTools/main/data/champions/champions.json`,
   comprueba que es válido y lo guarda en el índice local. **Buscar
   actualizaciones** consulta en el momento.
3. Sin conexión, o si la descarga falla o no es válida, usa la última copia
   guardada o la que lleva la app (la más reciente de las dos).

La pantalla indica **«Actualizado el … · fuente: Showdown …»** (fecha de los
datos y commit de Showdown), cuándo termina la regulación y cuál es la
siguiente.

**Privacidad**: es un GET anónimo a GitHub, sin cabeceras propias ni
identificadores (ni siquiera la versión de la app); no se envía nada de tus
partidas.

Si el JSON publicado tiene un `schemaVersion` más nuevo del que entiende tu
versión de la app, se ignora y la pantalla sugiere actualizar PKArkTools.

## De dónde salen los datos

| Dato | Fuente | Dónde vive |
|---|---|---|
| Especies y formas permitidas, Megaevoluciones | Pokémon Showdown, [`data/mods/champions/formats-data.ts`](https://github.com/smogon/pokemon-showdown/blob/master/data/mods/champions/formats-data.ts) (especies sin `isNonstandard`; los campos de National Dex, como `natDexTier`, no cuentan) | `data/champions/champions.json` y su copia integrada `packages/pkcore/lib/src/data/generated/champions_data.dart` (generados) |
| Nombre del formato y reglas | Showdown, `config/formats.ts` (formato `[Gen 9 Champions] VGC … Reg …` con `mod: 'champions'`; *National Dex*, BSS, etc. no cuentan) y `data/rulesets.ts` (*Flat Rules*) | mismos archivos generados |
| Siguiente regulación | Showdown, `config/formats.ts` (un formato VGC con un código posterior, p. ej. Reg M-D) | mismos archivos generados |
| Fechas de cada regulación | A mano, con su fuente (Serebii/Bulbapedia, sin confirmar) | [`tool/champions_regulations.json`](../../tool/champions_regulations.json) |

Los datos guardan el **commit** de Showdown y su fecha; la pantalla los
muestra junto a un enlace a la fuente. Un commit nuevo de Showdown que no
cambia los datos no genera cambios.

## Cómo actualizarla a mano

Normalmente no hace falta (lo hace la Action). Para probar el generador en
local:

```bash
python3 tool/fetch_champions_sources.py .scratch/champions   # imprime commit= y date=
python3 tool/gen_champions_data.py .scratch/champions <commit> <AAAA-MM-DD>
python3 tool/test_gen_champions_data.py
```

Escribe `data/champions/champions.json` y `champions_data.dart`. Cuando se
conozcan las fechas de una regulación, añádelas a
`tool/champions_regulations.json` con su fuente (`confirmed: true` solo si
vienen de Play! Pokémon o del juego) y vuelve a generar. Después pasa
`dart test test/tools_test.dart` en `packages/pkcore` (comprueba, entre
otras cosas, que todos los ids de Showdown se traducen a especie y forma). Si
Showdown cambia el `mod` del formato vigente (por ejemplo `championsregmb`
para la anterior), el generador toma el que tiene `mod: 'champions'`.
