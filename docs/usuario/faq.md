# Preguntas frecuentes y solución de problemas

## Preguntas frecuentes

**¿Necesito una cuenta?**
No. No hay cuentas, servidores propios ni telemetría. El Arca es una carpeta
tuya. Ver [Seguridad de datos y privacidad](../seguridad-datos.md).

**¿Puede la app estropear mi save?**
El archivo original nunca se modifica: se importa una copia. Las ediciones se
guardan como copias nuevas y cada exportación se relee y verifica antes de
entregarse. **Restaurar** sí escribe en la ubicación original, pero guarda
antes en el Arca lo que había ahí.

**¿Qué juegos soporta?**
De Rojo/Azul a Leyendas Z-A. Ver [Formatos soportados](../formatos.md).

**¿Incluye ROMs, claves o sprites?**
No. La app solo lee saves; los sprites se descargan bajo demanda
([Iconos](iconos.md)).

**¿Puedo usar el Arca en el móvil y en el ordenador a la vez?**
Sí, si la carpeta está en un servicio que sincroniza. Ver
[Primeros pasos](primeros-pasos.md#3-varios-dispositivos).

**¿Un Pokémon sin avisos es legal?**
No necesariamente; la legalidad es una ayuda. Ver
[Legalidad](legalidad.md#límites).

**¿Cómo cambio el idioma o el tema?**
En **Ajustes**: idioma (español, inglés o el del sistema) y tema (oscuro,
claro o el del sistema).

## Solución de problemas

**«No se reconoce el archivo»**
El mensaje explica la causa (tamaño, sectores, hash). Comprueba que sea el save
y no la ROM, que la copia esté completa y que el juego esté en la
[lista](../formatos.md). Saves de *hacks* con estructuras modificadas pueden no
reconocerse.

**El save se abre en solo lectura**
Tiene checksums que no cuadran o datos ilegibles. Ver
[Saves dañados](reparar-checksums.md).

**El juego no carga el save exportado**
Asegúrate de exportar desde el juego correcto y de reemplazar el archivo
exacto que usa el emulador (mismo nombre y carpeta; algunos emuladores
necesitan cerrarse antes). En emuladores de GB/GBA con reloj, exporta desde la
copia importada de ese mismo emulador para conservar el pie RTC.

**En Android no puedo elegir `Android/data`**
Es una restricción del sistema desde Android 11. Ver
[Importar › Android](importar.md#android).

**«Se perdió el acceso a la carpeta»**
El sistema retiró el permiso. Pulsa **Reintentar** o vuelve a elegir la misma
carpeta: las copias siguen ahí.

**Faltan copias que hice en otro dispositivo**
Espera a que el servicio de nube termine de sincronizar y pulsa **Ajustes ›
Reindexar**. En iOS/macOS los archivos aún no descargados de iCloud se piden
automáticamente.

**Aparecen «problemas» en Ajustes (json sin save, save sin json…)**
Suele ser una sincronización a medias. Si persiste, revisa esos archivos en la
carpeta; los saves sueltos se pueden **Adoptar**.

**Los iconos no aparecen**
Necesitan conexión la primera vez. Comprueba la red y, si persiste, **Ajustes ›
Iconos › Borrar caché** y vuelve a intentarlo.
