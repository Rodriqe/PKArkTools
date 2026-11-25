# Herramientas: Showdown, ordenar cajas y tarjeta

Todas trabajan sobre el **borrador** de la partida: nada se escribe en el Arca
hasta que pulsas **Guardar en el Arca**, y cualquier cambio se puede deshacer.

En el detalle de una partida, sección **Pokémon**, hay una fila de botones:
**Transferir Pokémon…**, **Importar de Showdown**, **Equipo a Showdown**,
**Ordenar cajas** y **Formato oficial** (este último abre la pestaña
[Competitivo](competitivo.md), donde están también las calculadoras de
estadísticas y de daño de Pokémon Champions y los equipos).

## Pokémon Showdown

**Importar**: pega uno o varios Pokémon en el formato de texto de
[Pokémon Showdown](https://pokemonshowdown.com/) (nombres en inglés, separados
por una línea en blanco; las cabeceras `=== … ===` se ignoran) y pulsa
**Analizar**. Se leen especie y forma (`Rotom-Wash`, `Tauros-Paldea-Blaze`,
`Indeedee-F`…), apodo, género, objeto, habilidad, nivel, variocolor,
naturaleza, EVs, IVs, movimientos, teratipo, felicidad, Gigamax y el tipo del
Poder Oculto (si no hay IVs, se ajustan los mínimos para conseguirlo).

Cada Pokémon se crea para el juego de la partida, con tu entrenador como
entrenador original, y se avisa de todo lo que no encaja en ese juego: especie
o forma que no existe, objeto que no se puede llevar, habilidad que la especie
no tiene, movimiento que no aprende, teratipo o EVs fuera de Gen 9… y los
avisos graves del [comprobador de legalidad](legalidad.md). Los datos de
origen que Showdown no trae (lugar y nivel de encuentro, fecha) se rellenan
con las correcciones seguras del comprobador. Elige **Equipo** (huecos libres
del equipo y después las cajas) o **Cajas** y pulsa **Añadir**.

> Lo que se crea es un Pokémon «hecho a mano»: aunque PKArkTools no avise,
> PKHeX puede marcar detalles más finos (por ejemplo el método de PID de Gen 3
> o la región de la consola en Gen 6–7).

**Exportar**: **Equipo a Showdown** muestra el texto del equipo con
**Copiar** y **Compartir**; en el editor de un Pokémon, menú ⋮ → **Texto de
Showdown** hace lo mismo con uno solo.

## Calculadora de estadísticas

La calculadora está en la pestaña **Competitivo → Calculadora de
estadísticas**, con las reglas de Pokémon Champions (nivel 50, puntos de
estadística, Megas): ver [Competitivo](competitivo.md#calculadora-de-estadísticas).
El editor de un Pokémon sigue mostrando sus estadísticas al nivel actual
mientras cambias IVs, EVs y naturaleza.

## Ordenar cajas

**Ordenar cajas** ordena por **Nº de Pokédex**, **tipo**, **generación**,
**living dex** (cada especie en su hueco: Bulbasaur en el primero, Ivysaur en
el segundo…; los repetidos van detrás del último número), **nivel** o
**variocolor primero**. Elige el alcance (**todas las cajas** o un rango «de …
a …»), revisa la **vista previa** de las cajas y pulsa **Aplicar orden**. El
equipo y los huecos bloqueados no se tocan. Es un solo paso de deshacer
(botón **Deshacer** del aviso o de la barra del borrador).

## Tarjeta para compartir

En el editor, menú ⋮ → **Tarjeta para compartir**: una imagen con el logo de
la app, el icono, nombre y forma, nivel, tipos, variocolor, naturaleza,
habilidad, objeto, teratipo, origen, cintas, IVs/EVs y movimientos.
**Guardar PNG** la guarda (1620×2160) y **Compartir** abre el menú del sistema
(en Windows y Linux, si no hay menú de compartir, usa Guardar PNG).
