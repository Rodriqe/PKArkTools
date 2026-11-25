# Mecánicas de Pokémon Champions (fuente: Pokémon Showdown)

Esto es lo que usan la calculadora de estadísticas y la de daño de la pestaña
**Competitivo**. Todo sale del código de **Pokémon Showdown** (MIT),
`smogon/pokemon-showdown`, commit
[`c7fa6f1`](https://github.com/smogon/pokemon-showdown/tree/c7fa6f16503de510c319239b5b2d29d4f7abd8c4),
mod `data/mods/champions/`. Lo que el código no deja claro se dice; no se
inventa nada.

## Estadísticas

| Qué | Cómo | Fuente (archivo:línea) |
|---|---|---|
| Nivel | **50 fijo**: «Adjust Level = 50» (sube o baja a 50; el mod cambia el «Adjust Level Down = 50» de las Flat Rules generales) | `data/mods/champions/rulesets.ts:46` (`flatrules`) y `:6` (`standardag`) |
| IVs | **31 en todo**: el validador rechaza un set con algún IV distinto | `sim/team-validator.ts:1166-1169` |
| Puntos de estadística (SP) | Sustituyen a los EVs (se guardan en `set.evs`): **0–32 por estadística** | `sim/team-validator.ts:1314-1319` |
| Total de SP | **66** como máximo | `sim/dex-formats.ts:328-330` (`evLimit = 66`) |
| PS | `base + SP + 75` | `data/mods/champions/scripts.ts:24-26` |
| Resto | `base + SP + 20`, después la naturaleza | `data/mods/champions/scripts.ts:27` |
| Naturaleza | ×1,1 / ×0,9 truncando: `tr(tr(stat × 110, 16) / 100)` | `data/mods/champions/scripts.ts:30-38` |
| Teracristalización | **No existe** (`canTerastallize` devuelve `null`) | `data/mods/champions/scripts.ts:179-181` |
| Megaevolución | Sí, con su megapiedra (`canMegaEvo`) | `data/mods/champions/scripts.ts:182-193` |

Las fórmulas son las de nivel 50 con IVs 31 de los juegos principales,
reescritas: con `SP` puntos la estadística es la misma que con
`EV = 8·SP − 4` EVs (el primer punto vale 4 EVs y los demás 8; lo dice el
comentario de `scripts.ts:17-18`, que usa esa equivalencia con «Level Clause
Mod»). PKArkTools lo usa para **cargar un Pokémon de una partida**:
`SP = (⌊EV/4⌋ + 1) / 2` da la misma estadística a nivel 50. **No es una regla
oficial de transferencia** (HOME → Champions): la app lo indica.

El modo «Level Clause Mod» (estadísticas que dependen del nivel,
`scripts.ts:14-23`) solo lo usan formatos de Showdown como *Random Battle*;
los formatos oficiales (VGC, BSS) no, así que la calculadora no lo ofrece.

Comprobación: `packages/pkcore/test/champions_stats_test.dart` compara 400
casos (todas las especies y Megas de Champions, naturalezas y repartos al
azar) con lo que calcula el simulador de Showdown
(`tool/showdown_ref/stats_ref.js`), y todos coinciden.

## Datos de combate

`tool/gen_champions_dex.js` genera
`packages/pkcore/lib/src/data/generated/champions_dex.dart` desde el mod:
especies y Megas que existen en Champions (estadísticas base, tipos,
habilidades, peso), sus movimientos aprendibles
(`data/mods/champions/learnsets.ts`), los movimientos con los cambios del mod
(`data/mods/champions/moves.ts`: potencias, PP…), los objetos y las
habilidades. **Qué especies se pueden usar** no sale de aquí, sino de la
regulación vigente (`data/champions/champions.json`, ver
[Formato oficial](usuario/formato-oficial.md)).

Para regenerarlo (todo dentro de `.scratch/`):

```sh
git -C .scratch/sd init ps && cd .scratch/sd/ps   # checkout del commit de arriba
npm_config_cache="$PWD/../../npm-cache" npm install --ignore-scripts esbuild@0.25 ts-chacha20 preact preact-render-to-string sockjs
node node_modules/esbuild/install.js && node build
cd ../../.. && node tool/gen_champions_dex.js .scratch/sd/ps
node tool/showdown_ref/stats_ref.js .scratch/sd/ps > packages/pkcore/test/data/champions_stats_ref.json
```
