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

## Daño

`packages/pkcore/lib/src/tools/champions_damage.dart` reproduce
`getDamage` (`sim/battle-actions.ts:1643-1780`) y el `modifyDamage` del mod
(`data/mods/champions/scripts.ts:196-310`). En Champions no hay
teracristalización, así que no hay STAB ×2 de Tera ni el mínimo de 60 de
potencia.

Orden (todo en enteros, como Showdown):

1. Tipo del movimiento (Bola Clima, Normalidad, -ate y Dragonize, Voz Fluida)
   e inmunidades: tabla de tipos, Levitación/Eelevate/Globo Helio para Tierra,
   absorciones (Absorbe Fuego, Absorbe Agua, Pararrayos…), Antibalas,
   Insonorizar, Superguarda y Campo Psíquico contra movimientos con prioridad.
2. Potencia base: las fórmulas propias de cada movimiento (peso, PS, velocidad,
   cambios de estadística…) y luego el evento `BasePower`.
3. Ataque y Defensa con sus cambios (el crítico ignora los que perjudican) y
   los eventos `ModifyAtk`/`ModifySpA`/`ModifyDef`/`ModifySpD`.
4. `⌊⌊⌊2·50/5+2⌋ · potencia · A / D⌋ / 50⌋ + 2`, varios objetivos ×0,75,
   clima, crítico ×1,5, tirada (85–100 %), STAB ×1,5 (Adaptabilidad ×2),
   tipos, quemadura ×0,5 y el evento `ModifyDamage` (Vidasfera, Cinta Experto,
   bayas, Multiescamas, pantallas: ×0,5 en individuales y ×2732/4096 en dobles).

Los modificadores de cada evento se encadenan en base 4096 (`chainModify`,
`sim/battle.ts:2337-2346`) en el orden en que el simulador ejecuta los
manejadores (`comparePriority`, `sim/battle.ts:409-416`): prioridad,
velocidad del Pokémon que lo lleva y tipo de efecto (`resolvePriority`,
`sim/battle.ts:957-1022`). Si atacante y defensor tienen exactamente la misma
velocidad, Showdown sortea el orden y el resultado puede variar en 1 punto de
daño; la calculadora pone primero al atacante.

**Comprobación**: `tool/showdown_ref/damage_ref.js` monta un combate real del
mod para cada caso (dobles con un compañero neutro, o individuales), pone
clima, campo, pantallas, cambios, estado y PS, y llama a `getDamage` forzando
cada una de las 16 tiradas. `packages/pkcore/test/champions_damage_test.dart`
compara las 16 tiradas de 317 casos (16 de bordes y 300 al azar entre las
especies, Megas, habilidades, objetos y movimientos de la regulación vigente):
**317/317 (100 %)**. Una pasada más larga de 2017 casos también dio 100 %.

**No se tiene en cuenta** (la app lo avisa cuando aparece):

* Habilidades: Analítico, Ímpetu Ardiente/Tóxico, Unaware, Compiescolta,
  Cloud Nine/Air Lock, Metal Pesado/Liviano, Paleosíntesis/Carga Cuark,
  Rastro, Impostor, Libero/Mutatipo, Sturdy y las que dependen del turno o de
  aliados (ver `unsupportedAbilities`).
* Objetos: Gema Normal, Metrónomo, Banda Focus/Cinta Focus, Baya Zidra y Restos
  (no cambian el daño de un golpe, pero sí el KO).
* Movimientos con daño que depende de lo que pasó antes (Contraataque, Puño
  Furia, Desquite, Represalia, Último Lugar…), los de KO directo y Premonición.
* Varios golpes: los golpes siguientes ya no tienen la baya ni Multiescamas;
  2–5 golpes se reparten 35/35/15/15 % (`sim/battle-actions.ts`, muestra de
  `multihit`). El KO no cuenta la curación ni el daño residual.
