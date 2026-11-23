# Saves dañados y reparar checksums

Cada vez que se abre una copia, la app recalcula las verificaciones del save
(checksums por bloque, CRC16, firma MemeCrypto, MD5 o SHA-256 según el juego).
Si algo no cuadra, la copia se abre en **solo lectura** con un aviso que
explica qué parte falla.

## Dos niveles

| Nivel | Qué significa | Qué hacer |
|---|---|---|
| **Aviso leve** — «Se lee entero, pero una verificación no coincide» | Todos los datos se leen bien, pero el juego comprueba esas verificaciones y podría no cargar el save o darlo por dañado. | Si el juego carga el save sin problemas, usa **Reparar checksums y exportar**. Si no, vuelve a copiar el save desde la consola o el emulador. |
| **Datos dañados** — «Parte de este save no se puede leer» | Lo que ves puede estar incompleto o ser incorrecto. No es seguro editarlo. | Vuelve a copiar el save original e impórtalo de nuevo. Puedes exportar la copia tal cual con **Exportar**. |

El aviso indica la parte: el archivo completo, el bloque del entrenador, del
equipo, de las cajas, otros bloques (objetos, Pokédex, eventos…), la firma
digital (Sol/Luna, Ultrasol/Ultraluna), el hash del archivo (Switch) o datos
ilegibles. **Detalle técnico** muestra los valores esperados y encontrados.

Suele pasar cuando el archivo se copió a medias, es de otra versión o formato,
u otra herramienta lo editó sin recalcular sus verificaciones.

## Reparar checksums y exportar

Disponible solo en el aviso leve. Recalcula todas las verificaciones, relee el
resultado, comprueba que el contenido (entrenador, equipo, cajas, inventario,
Pokédex, eventos) es idéntico y escribe un archivo nuevo con el sufijo
«reparado». **La copia del Arca no se toca**: si quieres conservar la reparada
en el Arca, impórtala.

Siguiente: [Iconos](iconos.md).
