# Generar una Living Dex

En la ficha de una partida (pestaña **Pokémon**, encima de las cajas) el botón
**Generar Living Dex en la partida actual** llena las cajas con un Pokémon de
cada especie y forma que el juego admite, en orden de la Pokédex nacional.

1. Elige **Normal** o **Variocolor**.
2. Lee el aviso: se **sobrescriben todas las cajas** (te dice cuántas y cuántos
   Pokémon hay ahora); el equipo no se toca. La versión anterior queda en el
   **historial del Arca** y puedes volver a ella cuando quieras.
3. **Generar y guardar** crea la Living Dex y la guarda como versión nueva.

Si no cabe entera (Rojo/Azul, Oro/Plata, Leyendas…), se llenan las cajas hasta
donde quepan y el aviso dice hasta qué especie llega.

## De dónde sale cada Pokémon

Cada uno se crea a partir de un **encuentro real de tu versión** (huevo
eclosionado, estático o regalo, o salvaje; nunca un intercambio con un NPC) y,
si es una evolución, evolucionado al nivel mínimo legal. Las evoluciones por
intercambio llevan, como en el juego, el registro del entrenador con el que se
intercambiaron. Los míticos y legendarios que tu juego solo dio por evento
salen de un **evento oficial** (ver [Eventos](eventos.md)).

Todos llevan **tus datos de entrenador** (nombre, ID, género e idioma del save)
y el PID/IV con el método correcto de su encuentro. Los datos salen de PKHeX
(`tool/gen_living_dex_data.sh`) y `tool/check_living_dex_pkhex.sh` comprueba la
Living Dex completa, normal y variocolor, de 16 juegos: **0 inválidos** para
PKHeX.

## Variocolor

Variocolor solo donde el juego lo permite. Quedan normales (y el aviso dice
cuántos):

- los encuentros bloqueados por el juego (legendarios de Espada/Escudo,
  Escarlata/Púrpura, Leyendas, regalos fijos…) y los eventos que nunca son
  variocolor;
- en Gen 2, los Unown que no sean I o V (la letra sale de los DV);
- encuentros cuyo PID depende de una semilla que la app no reproduce
  (algunos salvajes de Gen 3–4, símbolos de Espada/Escudo, Leyendas Z-A).

En Gen 1 el variocolor no existe en el juego: se usan los DV que lo hacen
variocolor al pasarlo a Gen 2 o a Pokémon Bank.

## Qué no se incluye

- **Formas de combate**: megaevoluciones, Gigamax, regresiones primigenias,
  Castform con clima, Cherrim soleado, Darmanitan Daruma, Aegislash filo,
  Meloetta danza, Mimikyu destapado, Wishiwashi banco, Minior sin coraza…
- **Fusiones** (Kyurem blanco/negro, Necrozma melena/alas, Calyrex jinete): la
  fusión consume al otro legendario.
- **Pokémon dominantes** (Sol/Luna) y **nobles** (Leyendas Arceus).
- Especies **sin encuentro propio en tu versión** (exclusivas de la otra
  versión, solo por HOME o por intercambio).

Sí se incluyen las formas regionales (Alola, Galar, Hisui, Paldea) y las
cosméticas que se guardan en una caja: letras de Unown, dibujos de Vivillon
(Gen 6–7 con la región de consola de cada dibujo), Alcremie, flores de
Flabébé, Shellos/Gastrodon, Burmy/Wormadam, estaciones de Deerling, Rotom,
Oricorio, Lycanroc, núcleos de Minior, Toxtricity, Urshifu, Arceus con su
tabla, géneros como forma (Meowstic, Indeedee, Basculegion, Oinkologne)…

## Avisos «Fishy» de PKHeX

PKHeX no da ninguno por inválido, pero marca algunos como sospechosos
(«Fishy») sin que sea un problema: en Espada/Escudo, la falta de recuerdo del
entrenador original (el juego no siempre lo pone); en Gen 1–2, la experiencia
justo en el umbral del nivel; dibujos de Vivillon de otra región; en Leyendas
y Let's Go, evolucionados sin esfuerzo acumulado.
