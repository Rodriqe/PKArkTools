# Seguridad de datos y privacidad

## Principios

1. **El original nunca se toca.** Importar solo *lee* el archivo; el Arca
   guarda una copia byte a byte. La única operación que escribe fuera del Arca
   por iniciativa tuya es **Restaurar**, y antes de escribir guarda en el Arca
   lo que hubiera en ese sitio. **Exportar** siempre escribe un archivo nuevo
   donde tú elijas.
2. **Copias inmutables.** Cada copia del `historial/` es un archivo con nombre
   único (`<fecha>_<hora>_<8 hex del SHA-256>.<ext>`) más su `.json` de
   metadatos. El archivo de la última versión (`main`, `<Juego>.sav`…) y
   `ultima.json` son derivados: se regeneran desde el historial y la app solo
   los reescribe si su contenido ya está en el historial (uno cambiado a mano
   se conserva hasta que lo guardes como copia nueva).
   Nada se sobrescribe: si el nombre está ocupado por otro contenido se añade
   un sufijo. Editar y guardar crea otra copia; la anterior queda en el
   historial. Lo único que borra copias es **Eliminar del Arca**, siempre con
   confirmación explícita (primero el `.json` y luego el save, para que otro
   dispositivo nunca indexe una copia a medias).
3. **Escritura atómica.** Cada archivo se escribe en un temporal oculto
   (`.…tmp`) y se renombra; el `.json` se escribe después del save. Una copia a
   medias nunca parece completa.
4. **Integridad comprobada.** El `.json` guarda el SHA-256 completo y se
   comprueba cada vez que se lee la copia. Mover o copiar el Arca, migrar la
   versión antigua, pasar al diseño con `historial/`, recoger la bandeja de
   entrada, adoptar saves sueltos y restaurar un zip verifican el
   SHA-256 en el destino antes de dar nada por hecho (y, al mover, antes de
   retirar el origen).
5. **Verificación post-exportación.** Al exportar o guardar en el Arca, el
   archivo generado se relee con el mismo lector, se recalculan sus checksums y
   se compara con el borrador: entrenador, equipo, cajas, inventario, Pokédex y
   eventos. Si algo no coincide, no se entrega.
6. **Saves dañados en solo lectura.** Un save con checksums rotos o datos
   ilegibles no se puede editar; solo exportar tal cual o, si el daño es leve,
   *reparar checksums y exportar* a un archivo nuevo (ver
   [Reparar checksums](usuario/reparar-checksums.md)).
7. **Robustez.** Los 22 formatos tienen tests de ida y vuelta (leer → escribir
   sin cambios = bytes idénticos), de edición (editar → escribir → releer) y de
   mutación (truncados, checksums rotos, bytes aleatorios, valores fuera de
   rango): ningún caso termina en un error sin controlar.

## Privacidad

* **Todo es local.** No hay cuentas, servidores propios, analítica,
  publicidad ni telemetría. Ningún dato de tus partidas sale del dispositivo
  salvo que tú pongas la carpeta del Arca en un servicio de nube (en cuyo caso
  lo sincroniza ese servicio, no la app).
* **Conexiones a internet: los iconos y la búsqueda de actualizaciones.**
  * **Iconos.** La app descarga sprites de
    `https://raw.githubusercontent.com/kwsch/PKHeX/<commit fijo>/…` por HTTPS.
    La petición solo contiene la ruta del icono (p. ej. el número de especie);
    GitHub ve, como cualquier servidor web, tu dirección IP y la hora. Los
    iconos se guardan en la caché de la app. Sin red, la app funciona igual con
    avatares de iniciales.
  * **Actualizaciones** (la única conexión nueva). Al abrir, como mucho una vez
    cada 24 h, y al pulsar **Buscar actualizaciones**, la app pide
    `https://api.github.com/repos/Rodriqe/PKArkTools/releases/latest`, sin
    token ni cuenta, con el `User-Agent` `PKArkTools/<versión>` y el `ETag`
    de la respuesta anterior (si no ha cambiado, GitHub contesta 304). No se
    envía nada tuyo. La respuesta, el `ETag`, la fecha de la consulta, la
    versión omitida y la opción **Buscar actualizaciones automáticamente**
    (desactivable) se guardan en los ajustes del índice local.
  * Solo al pulsar **Actualizar** / **Descargar** se baja el archivo del
    release, y solo por HTTPS desde el repositorio `Rodriqe/PKArkTools` en
    los dominios de GitHub (`github.com` y su redirección a
    `*.githubusercontent.com`, comprobada en cada salto); si llegan más bytes
    de los anunciados o falta alguno, se descarta. La app **no ejecuta nada
    descargado**: en Android entrega el APK al instalador del sistema solo si
    tiene el mismo nombre de paquete y los mismos certificados de firma
    (SHA-256) que la app instalada, y lo borra al terminar o cancelar; en
    escritorio lo guarda donde elijas y lo instalas tú; en iOS solo abre la
    página del release.
* **Permisos.**
  * Android: `INTERNET` (iconos y actualizaciones) y
    `REQUEST_INSTALL_PACKAGES` (entregar la actualización al instalador del
    sistema; Android además pide permitir «Instalar apps desconocidas» y
    confirmar cada instalación). **Ningún** permiso de almacenamiento: las
    carpetas y archivos se abren con el selector del sistema (SAF) y solo
    sobre lo que eliges.
  * iOS: ningún permiso con diálogo; acceso a archivos por el selector del
    sistema y *bookmarks*.
  * macOS: sandbox con acceso solo a archivos elegidos por ti
    (`files.user-selected.read-write`), *bookmarks* con *security scope* y
    conexiones salientes (`network.client`, iconos y actualizaciones).
* **Dónde vive cada cosa.**

  | Dato | Ubicación |
  |---|---|
  | Copias y metadatos | Carpeta del Arca (la que tú elegiste) |
  | Índice local (SQLite/drift) | Directorio de soporte de la app; se reconstruye desde la carpeta |
  | Iconos | Directorio de caché de la app |
  | Última respuesta de GitHub (actualizaciones) | Ajustes del índice local |
  | APK de una actualización (Android) | Caché de la app, solo mientras se instala |
  | Ajustes y permiso de la carpeta | Almacenamiento privado de la app |

* El `.json` de cada copia incluye el nombre del entrenador, TID/SID, horas
  jugadas y un nombre de dispositivo, porque vienen del propio save o ayudan a
  saber de dónde salió la copia. Tenlo en cuenta si compartes la carpeta o el
  zip del Arca.
* Las herramientas de desarrollo (oráculo PKHeX, tests con saves reales)
  escriben sus salidas en `.scratch/`, ignorada por git, porque pueden contener
  datos personales.
