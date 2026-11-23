# Editor

## Borrador, deshacer y guardar

Toda edición vive en un **borrador** con deshacer/rehacer (⌘Z / ⇧⌘Z en Mac,
Ctrl+Z / Ctrl+Shift+Z en Windows y Linux; botones en teléfono). Al terminar:

* **Guardar en el Arca** crea una copia nueva (origen = edición) con una nota
  de cambios. La copia anterior sigue en el historial.
* **Exportar** escribe el archivo listo para el juego o el emulador,
  conservando su contenedor; antes de entregarlo se relee y se verifica.

El archivo original nunca se modifica.

<img src="../screenshots/15_guardar_en_arca.png" width="480" alt="Guardar en el Arca">

## Pokémon

Especie y forma, apodo, nivel/EXP, naturaleza (y menta en Gen 8+), habilidad,
objeto, movimientos y PP, IVs/EVs (AVs en Let's Go, GVs en Leyendas Arceus) con
presets, variocolor (PID/EC regenerados según la generación), género, amistad,
Poké Ball, OT/TID/SID, idioma y teratipo (Escarlata/Púrpura). Los buscadores
tienen autocompletado y las estadísticas se calculan en vivo.

<p>
  <img src="../screenshots/10_editor_pokemon.png" width="420" alt="Editor de Pokémon">
  <img src="../screenshots/11_editor_estadisticas.png" width="420" alt="Estadísticas en vivo">
  <img src="../screenshots/17_editor_movil.png" width="150" alt="Editor en móvil">
</p>

Las Balls de cada juego son las que existían en él (las de Hisui con su nombre
propio); una Ball traída de otro juego se conserva.

## Cajas

* Toca un Pokémon para editarlo.
* **Arrastra** para mover o intercambiar, también entre equipo y cajas o
  soltando sobre el nombre de otra caja. En teléfono, flechas y deslizar para
  cambiar de caja.
* Clonar, borrar y renombrar cajas.
* **Importar .pkX** / **Exportar como .pkX**: Pokémon sueltos del formato del
  juego (un `.pk5` no entra en Espada/Escudo, por ejemplo).

<p>
  <img src="../screenshots/12_cajas_arrastrando.png" width="420" alt="Cajas arrastrando">
  <img src="../screenshots/v2/mac_04_cajas_iconos.png" width="420" alt="Cajas con iconos">
</p>

## Entrenador

Nombre, dinero, TID/SID, tiempo jugado y género donde el juego lo guarda.

<img src="../screenshots/13_entrenador.png" width="420" alt="Entrenador">

## Inventario

Bolsillos del juego con cantidades y, en Gen 1, también el PC. Los objetos
llevan su icono.

<img src="../screenshots/14_inventario.png" width="420" alt="Inventario">

## Pokédex

Visto/capturado por especie y, según el juego, género, variocolor y formas.
Filtros, búsqueda y Pokédex regionales con su numeración (Galar, Isla de la
Armadura, Corona Nieve, Paldea, Kitakami, Arándano, Hisui, Luminalia…).
Mantén pulsado (o clic derecho) para el detalle por especie. **Completar** y
**Limpiar** piden confirmación y respetan las especies y formas que existen en
el juego. En Leyendas Arceus el nivel de investigación es de solo lectura (el
juego lo calcula de las tareas).

<p>
  <img src="../screenshots/24_pokedex_switch.png" width="420" alt="Pokédex de Espada/Escudo">
  <img src="../screenshots/25_pokedex_detalle.png" width="420" alt="Detalle de la Pokédex">
</p>

## Eventos

Flags y constantes del juego con búsqueda por nombre o número, filtro «con
nombre» y lista completa; desplegable cuando la constante tiene valores
conocidos. En Gen 8–9 cada flag es un bloque del save y se muestra con su
nombre si PKHeX lo documenta (si no, con su clave hexadecimal). En Gen 1 la
lista es cruda (no hay tabla fiable de nombres).

> **Aviso:** tocar eventos puede romper la partida. La app lo recuerda antes de
> abrir el editor de eventos. Exporta y prueba siempre en una copia.

<img src="../screenshots/27_eventos_gen7.png" width="480" alt="Eventos de Ultrasol">

## Cintas y marcas

Cintas de Gen 3–9 y marcas (Espada/Escudo, Escarlata/Púrpura, Leyendas Arceus
y Z-A) agrupadas en concursos, batalla, conmemorativas, eventos y marcas, con
icono, nombre y descripción. Filtro «solo las que tiene», **dar todas las
válidas**, **quitar todas** y **cinta mostrada** (Gen 8+). Ver los avisos
asociados en [Legalidad](legalidad.md).

<p>
  <img src="../screenshots/v2/mac_07_cintas.png" width="420" alt="Cintas en escritorio">
  <img src="../screenshots/android/v2_07_cintas.png" width="150" alt="Cintas en Android">
</p>

## Origen

Juego de origen con su color, lugar de captura con su nombre real, nivel y
fecha, huevo (lugar y fecha), entrenador original, traspasos (Parque Compi,
Pokétransfer, Poké Transporter/Banco, HOME) y Ball con su icono. Los selectores
ofrecen solo lugares donde aparece la especie y Balls de ese juego; un
desajuste se marca con los lugares válidos.

<p>
  <img src="../screenshots/v2/mac_06_origen.png" width="420" alt="Origen en escritorio">
  <img src="../screenshots/ios/v2_pro_06_origen.png" width="150" alt="Origen en iPhone">
</p>

## Saves en solo lectura

Si el save tiene datos ilegibles o checksums rotos se abre en **solo lectura**
y el editor no está disponible; ver
[Saves dañados y reparar checksums](reparar-checksums.md).

Siguiente: [Legalidad y avisos](legalidad.md).
