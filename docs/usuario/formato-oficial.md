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
confirmar» si no hay una fuente oficial, y la lista de **objetos permitidos**
no está incluida (consúltala en el juego).

## De dónde salen los datos

| Dato | Fuente | Dónde vive |
|---|---|---|
| Especies y formas permitidas, Megaevoluciones | Pokémon Showdown, [`data/mods/champions/formats-data.ts`](https://github.com/smogon/pokemon-showdown/blob/master/data/mods/champions/formats-data.ts) (especies sin `isNonstandard`) | `packages/pkcore/lib/src/data/generated/champions_data.dart` (generado) |
| Nombre del formato y reglas | Showdown, `config/formats.ts` (formato `[Gen 9 Champions] VGC …` con `mod: 'champions'`) y `data/rulesets.ts` (*Flat Rules*) | mismo archivo generado |
| Fechas de la regulación | A mano, con su fuente (ahora Bulbapedia, sin confirmar) | `ChampionsFormat.regulation` en `packages/pkcore/lib/src/tools/champions.dart` |

El archivo generado guarda el **commit** de Showdown y su fecha; la pantalla
los muestra junto a un enlace a la fuente.

## Cómo actualizarla cuando cambie la regulación

```bash
mkdir -p .scratch/champions
base=https://raw.githubusercontent.com/smogon/pokemon-showdown/master
curl -o .scratch/champions/formats-data.ts $base/data/mods/champions/formats-data.ts
curl -o .scratch/champions/formats.ts $base/config/formats.ts
curl -o .scratch/champions/rulesets.ts $base/data/rulesets.ts
curl -s 'https://api.github.com/repos/smogon/pokemon-showdown/commits?path=data/mods/champions/formats-data.ts&per_page=1' \
  | python3 -c "import sys,json;d=json.load(sys.stdin)[0];print(d['sha'],d['commit']['committer']['date'][:10])"
python3 tool/gen_champions_data.py .scratch/champions <sha> <AAAA-MM-DD> \
  packages/pkcore/lib/src/data/generated/champions_data.dart
```

Después, en `champions.dart`, actualiza `ChampionsFormat.regulation` (código,
fechas, `datesSource` y `datesConfirmed: true` solo si las fechas vienen de
Play! Pokémon o del juego) y pasa `dart test test/tools_test.dart` en
`packages/pkcore` (comprueba que todos los ids de Showdown se traducen a
especie y forma). Si Showdown cambia el `mod` del formato vigente (por
ejemplo `championsregmb` para la anterior), el generador toma el primero con
`mod: 'champions'`.
