# Licencias

> Este documento describe hechos sobre el origen y la licencia del código y los
> recursos. No es asesoramiento legal.

## Licencia del proyecto

PKArkTools se distribuye bajo la **GNU General Public License v3.0**
([`LICENSE`](../LICENSE)). Los créditos detallados están en
[`NOTICE`](../NOTICE).

El motivo principal es que `packages/pkcore` **porta a Dart lógica de
PKHeX.Core**, que es GPL-3.0; un trabajo derivado de código GPL-3.0 debe
distribuirse también bajo GPL-3.0 (con su código fuente).

## Qué se portó de PKHeX.Core

[PKHeX](https://github.com/kwsch/PKHeX) — © Kaphotics y colaboradores, GPL-3.0.

| Área | Origen en PKHeX.Core | Dónde está en PKArkTools |
|---|---|---|
| Cifrado de saves de Switch | `SwishCrypto`, `SCBlock`, `SCXorShift32` | `packages/pkcore/lib/src/crypto/` |
| Firma de Sol/Luna/USUM | `MemeCrypto` | `packages/pkcore/lib/src/crypto/meme_crypto.dart` |
| Cifrado de entidades PK3–PK9 | `PokeCrypto` | `packages/pkcore/lib/src/crypto/pk_crypto.dart` |
| Detección y offsets | `SaveUtil`, `SAV1`–`SAV9` y sus bloques | `packages/pkcore/lib/src/detect/`, `formats/` |
| Checksums | `Checksums.cs` | `packages/pkcore/lib/src/util/checksums.dart` |
| Estructuras de Pokémon | `PK1`–`PK9`, `PB7`, `PB8`, `PA8`, `PA9` (campos, estadísticas, PID/EC) | `packages/pkcore/lib/src/pkm/` |
| Escritura de saves | `SAV1`–`SAV9` (bloques, bolsillos, entrenador) | `packages/pkcore/lib/src/edit/`, `write/` |
| Pokédex | `Zukan4`…`Zukan9a`, `PokedexSave8a`, `DexFormUtil` | `packages/pkcore/lib/src/edit/pokedex*.dart` |
| Eventos | `EventWork*`, `FlagWork8b`, nombres de bloque de `SaveBlockAccessor*` | `packages/pkcore/lib/src/edit/events.dart` |
| Legalidad | Ideas y tablas de `PKHeX.Core/Legality` (orígenes, Balls, habilidad oculta, variocolor bloqueado, encuentros, `RibbonVerifier`/`MarkRules` simplificados) | `packages/pkcore/lib/src/legal/` |
| Cadenas | `StringConverter*` (Gen 1–4 y coreano), `SpeciesConverter`, `ItemConverter` | `packages/pkcore/lib/src/strings/`, `data/` |
| Tablas generadas | `PKHeX.Core/Resources` (movimientos, objetos, habilidades, datos personales, learnsets, encuentros, lugares, cintas, etiquetas de eventos) | `packages/pkcore/lib/src/data/generated/` (con los scripts de `tool/`) |
| Nombres de iconos | `SpriteName` | `apps/pkarktools/lib/data/sprites/` |

Además, `tools/pkhex_oracle/` es un pequeño programa .NET que **enlaza**
PKHeX.Core (clonado aparte en `.ref/PKHeX`, no incluido en el repositorio) solo
para comparar resultados en desarrollo. No forma parte de la app.

## Otros componentes

| Componente | Licencia | Uso |
|---|---|---|
| [PokeAPI](https://github.com/PokeAPI/pokeapi) | BSD-3-Clause | Nombres de especies (es/en/ja), tipos, tablas de experiencia y cadenas evolutivas, generados con `tool/gen_species_data.py` y `tool/gen_encounter_data.py` |
| Flutter y paquetes de Dart (riverpod, go_router, drift, file_picker, path_provider, archive, crypto…) | BSD-3-Clause / MIT | Dependencias de la app; sus licencias se muestran en **Ajustes › Acerca de › Licencias** (generado por Flutter) |
| SQLite (vía `sqlite3`/`drift_flutter`) | Dominio público | Índice local |
| Fuentes Manrope y Bricolage Grotesque | SIL Open Font License 1.1 | `apps/pkarktools/assets/fonts/OFL-*.txt` |

## Sprites

Los sprites de Pokémon, objetos, Balls, tipos y cintas son **© Nintendo /
Game Freak / The Pokémon Company**. **No se empaquetan** con la app ni están en
este repositorio: la app los descarga bajo demanda del repositorio de PKHeX en
GitHub (commit fijo, índice en
`apps/pkarktools/lib/data/sprites/sprite_manifest.g.dart`) y los guarda en su
caché. Ver [Iconos](usuario/iconos.md).

## Marcas

Pokémon y los nombres de personajes son marcas de Nintendo, Creatures Inc. y
GAME FREAK inc. Este proyecto no está afiliado a ellos y no distribuye ROMs,
claves, sprites ni otro contenido de los juegos. Los nombres de juegos,
especies, movimientos y objetos se usan para identificar los datos de los
saves.

## Logo

El logo (`apps/pkarktools/assets/branding/` y los iconos de la app de cada
plataforma) es **propiedad del autor del proyecto**; los derivados se generan
con `tool/gen_branding.py` desde el original (en `.ref/branding/`, fuera del
repositorio). El repositorio no indica hoy bajo qué licencia se puede
reutilizar el logo por separado; ver la nota correspondiente en
[Publicación](publicacion.md#licencia-gpl-3-y-tiendas).

## GPL-3.0 y las tiendas de apps

Hay un conflicto conocido y documentado públicamente entre la GPL y los
términos de uso de la App Store de Apple. Los hechos técnicos relevantes para
este proyecto están en [Publicación › Licencia GPL-3 y
tiendas](publicacion.md#licencia-gpl-3-y-tiendas).
