# Transferir Pokémon entre partidas

PKArkTools puede llevar Pokémon de una partida del Arca a otra, aunque sean
de juegos o generaciones distintos: un «HOME local» que sigue las reglas de
los servicios reales (Cápsula del Tiempo, Pal Park, Poké Transfer, Poké
Transporter, Pokémon Bank y Pokémon HOME).

## Cómo se usa

1. Abre la partida de origen (su copia más reciente, sin cambios pendientes).
2. Pulsa **Transferir Pokémon…** encima del equipo, o en la ficha de un
   Pokémon: menú ⋮ → **Transferir a otra partida…**.
3. Elige uno o varios Pokémon, la **partida de destino** y dónde dejarlos
   (primer hueco libre o desde una caja concreta).
4. Revisa la **vista previa**: la ruta de formatos (p. ej. `PK3 → PK4 → … →
   PK9`), qué cambia (movimientos, Ball, objeto, cintas, nombre, habilidad,
   nivel) y los avisos de legalidad en el juego de destino.
5. Elige el modo y confirma:
   - **Mover** (por defecto, como HOME): el Pokémon sale de la partida de origen.
   - **Copiar**: el original se queda. Si el Pokémon ya tiene rastreador de
     HOME, la copia tendría el mismo y PKHeX la vería como un clon; hay que
     confirmarlo expresamente.

Las dos partidas se guardan como **copias nuevas** en el Arca; las anteriores
siguen en el historial, así que siempre puedes volver atrás.

Los Pokémon de **evento** y los de la **Living Dex** se transfieren igual que
los demás y siguen siendo legales en el destino (comprobado con PKHeX). En
Espada/Escudo, quien recibe el Pokémon pasa a ser su último entrenador con el
recuerdo de intercambio, como en el juego.

## Detector de clones de HOME

**Ajustes → Clones de HOME → Buscar clones en el Arca** revisa la última copia
de cada partida y lista los Pokémon que comparten rastreador de HOME (son
copias del mismo Pokémon), con la partida y la caja de cada uno. HOME puede
rechazarlos o marcarlos: conserva solo uno.

## Reglas que se respetan

| Paso | Qué hace |
|---|---|
| Gen 1 ↔ Gen 2 | Cápsula del Tiempo: solo especies, movimientos y objetos de Gen 1; japonés e internacional no se mezclan. |
| Gen 1/2 → Gen 7 | Consola Virtual + Poké Transporter: Ball Poké, 3 IV perfectos (5 Mew y Celebi), naturaleza por experiencia, habilidad oculta cuando toca. |
| Gen 3 → Gen 4 | Pal Park: se borran las MO de Gen 3, el objeto se convierte, los rangos de concurso pasan a cintas, lugar «Parque Compi». |
| Gen 4 → Gen 5 | Poké Transfer: se borran las MO de Gen 4, Arceus pierde la tabla, solo objetos que existen en Teselia. |
| Gen 5 → Gen 6 | Poké Transporter: nueva regla de variocolor, cintas de concurso y combate resumidas en cintas de recuerdo, quien transfiere pasa a ser el último entrenador. |
| Gen 6 → Gen 7 | Pokémon Bank. |
| Gen 7, Let's Go, Switch → Switch | Pokémon HOME: sin objeto, Arceus y Silvally en su forma base, movimientos reiniciados a los del nivel si el juego es otro, rastreador de HOME. |

Siempre hacia adelante: un Pokémon no vuelve a una generación anterior,
excepto entre los juegos de Switch (Espada/Escudo, Diamante Brillante/Perla
Reluciente, Leyendas Arceus, Escarlata/Púrpura y Leyendas Z-A), que se
comunican por HOME en cualquier sentido. No se transfieren: huevos (salvo
entre juegos del mismo formato), Pokémon oscuros sin purificar, especies o
formas que no existen en el destino, Spinda y Nincada de BDSP, ni Pokémon de
otros juegos a Let's Go. De Leyendas Z-A no sale nada hacia otros juegos
(PKHeX no lo da por legal).

Cada salto de generación se comprueba contra PKHeX: un Pokémon legal sigue
siendo legal en el destino.

## Hasta Alola: lo que la app puede garantizar

La app solo puede garantizar la continuidad de un Pokémon **hasta Alola**
(Gen 7: Sol/Luna, Ultrasol/Ultraluna y Pokémon Bank). Para llegar a un juego
de Switch hace falta un **rastreador de HOME**, y ese número lo genera la app
en tu dispositivo, no los servidores de HOME. PKHeX lo acepta (no puede
comprobar si es auténtico; solo marca dos Pokémon con el mismo rastreador
como clones), pero **no podemos garantizar cómo lo trataría el HOME real**:
te recomendamos no subir a HOME los Pokémon transferidos así.

Por eso, cuando el destino requiere HOME, la vista previa muestra un aviso
que hay que aceptar con **Entiendo** la primera vez (se recuerda en cada
dispositivo) y ofrece la opción **Llevar hasta Alola y continuar con
Banco/HOME**.

### Ruta recomendada a Switch

1. Transfiere con la app a tu partida de **Sol/Luna o Ultrasol/Ultraluna**
   (si no tienes ninguna en el Arca, la app te lo indica).
2. Exporta esa partida y ponla en tu 3DS.
3. En la 3DS, deposita el Pokémon en **Pokémon Bank**.
4. En **Pokémon HOME** (móvil o Switch), usa «Pokémon Bank» para pasar la
   caja a HOME: así HOME le asigna su propio rastreador.
5. Desde HOME, llévalo al juego de Switch.

Pokémon Bank solo funciona en una 3DS que ya lo tenga instalado (la eShop de
3DS cerró en 2023). Let's Go no usa Bank: va a HOME directamente desde su
propio juego.
