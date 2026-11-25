# Competitivo (Pokémon Champions)

La pestaña **Competitivo** (🏆 en la barra lateral; **Combate** en la barra
inferior del teléfono) reúne todo lo del juego competitivo oficial, que desde
2026 se juega en **Pokémon Champions**:

* [Formato oficial](formato-oficial.md): la regulación vigente, sus reglas,
  los Pokémon permitidos y cuáles de tus partidas valen.
* **Calculadora de estadísticas** con las reglas de Champions.
* **Calculadora de daño**.
* **Mis equipos**, guardados en tu Arca.
* **Showdown**: comprobar un equipo pegado y exportar el de una partida.

**Siempre la regulación vigente.** No hay selector de regulaciones: todo usa
la que vale hoy (los datos se actualizan solos, ver
[Formato oficial](formato-oficial.md)). Arriba se ve «Regulación M-C · hasta
el … · siguiente: …»; cuando cambia, cambia todo a la vez.

En el teléfono, **Actividad** ya no está en la barra inferior (seis entradas
no caben a 320 puntos de ancho): se abre con el botón 🕘 de la cabecera del
Arca. En la barra lateral del escritorio sigue en su sitio.

## Calculadora de estadísticas

Champions no usa IVs ni EVs como los juegos principales:

* **Nivel 50** fijo e **IVs al máximo** (31) en todo.
* **Puntos de estadística (SP)**: de 0 a 32 por estadística y 66 en total.
* PS = base + SP + 75; el resto = (base + SP + 20) × naturaleza.
* Megaevolución con su megapiedra; **no hay teracristalización**.

Eliges especie (solo las permitidas en la regulación vigente, con buscador),
Mega si la tiene, naturaleza y puntos, y ves las estadísticas finales.
**Cargar de mis Pokémon** toma uno de las partidas del Arca: sus EVs pasan a
los puntos que dan la misma estadística a nivel 50 (no es la conversión
oficial de HOME, la app lo indica). **Pegar de Showdown** acepta un set de
Showdown (en Champions, la línea `EVs:` lleva los puntos; si son EVs clásicos
se convierten). **Clásica** es la calculadora de siempre (IVs, EVs y nivel
libres). Las fórmulas y su fuente exacta en Showdown están en
[Mecánicas de Champions](../champions-mecanicas.md).

## Calculadora de daño

Atacante y defensor (con todo su set: especie, Mega, naturaleza, puntos,
habilidad, objeto), movimiento, y el combate: **dobles o individuales**,
clima, campo, **Reflejo / Pantalla de Luz / Velo Aurora**, **crítico**, ataque
**a varios objetivos** (dobles), **Refuerzo**, cambios de estadística, estado
(quemado, paralizado…) y PS actuales.

El resultado: rango de daño (y % de los PS), las 16 tiradas,
**probabilidad de KO** (OHKO, 2HKO… con su %), golpes del movimiento y el texto
habitual para compartir; por ejemplo, en dobles, Terremoto a los dos rivales
(los números son los puntos, `+`/`-` la naturaleza):

```
32 Atk Life Orb Garchomp Earthquake vs. 32 HP / 0 Def Incineroar: 179-213 (88.6 - 105.4%) -- 37.5% chance to OHKO
```

Se llega también con **Usar en la calculadora de daño** (desde la de
estadísticas o desde un miembro de un equipo) y con **Calcular daño** en el
menú ⋮ del editor de un Pokémon del Arca.

Es exacta: reproduce el simulador de **Pokémon Showdown** con el mod de
Champions, y los tests comparan las 16 tiradas de 317 casos (bordes y al azar)
calculados por el propio Showdown: todas coinciden. Lo que **no** se tiene en
cuenta (algunas habilidades y objetos, movimientos cuyo daño depende de turnos
anteriores, curaciones en el KO…) se avisa debajo del resultado con
«No se tiene en cuenta: …»; la lista completa está en
[Mecánicas de Champions](../champions-mecanicas.md#daño).

## Mis equipos

Equipos de hasta 6 Pokémon: crear, renombrar, duplicar y borrar. Cada
miembro: especie (de la regulación vigente), apodo, naturaleza, puntos (con las
estadísticas finales), 4 movimientos (solo los que aprende en Champions),
objeto, habilidad y Mega. Se comprueban las reglas del formato (cláusula de
especie y de objeto, tamaño del equipo). Si la regulación cambia y un miembro
deja de estar permitido, **se marca, no se borra**.

**Dónde se guardan**: en tu Arca, en la carpeta **`Competitive/Teams/`**
(un `.json` legible por equipo, con el nombre del equipo), así que viajan con
la copia de seguridad, se sincronizan con la nube igual que el resto y se
mueven con el Arca si cambias de carpeta. Esa carpeta no son partidas: el Arca
no la indexa ni la cuenta como archivos sin reconocer. Nunca se envían a
ningún sitio. Si aún no has elegido carpeta del Arca, la pantalla lo explica y
lleva a elegirla.

Para pasar un equipo a mano: **Texto de Showdown** (copiar) y **Exportar
.json**; en el otro dispositivo, **Importar → Pegar de Showdown** o
**Importar un .json** (siempre como equipo nuevo, sin pisar ninguno). Los
miembros se pueden añadir nuevos, **de mis Pokémon** o **pegados de
Showdown**.

## Showdown

Pega un equipo de Showdown para ver, con la regulación vigente, qué Pokémon
valen y si el equipo cumple las cláusulas; o exporta el equipo de una partida
del Arca como texto. Importar Showdown **a una partida** sigue dentro de la
partida (botón **Importar de Showdown** de su sección Pokémon).
