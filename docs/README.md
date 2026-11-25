# Documentación de PKArkTools

PKArkTools es el **Arca** de tus partidas de Pokémon: guarda copias
versionadas de saves de todas las generaciones (Game Boy a Switch), las
identifica, las lee, te deja editarlas con avisos de legalidad y exportarlas o
restaurarlas sin tocar nunca el archivo original. Funciona en Android, iOS,
macOS, Windows y Linux, sin cuentas ni telemetría.

## Índice

### Para usuarios

| Documento | Contenido |
|---|---|
| [Guía de usuario](usuario/README.md) | Índice de la guía |
| [Primeros pasos](usuario/primeros-pasos.md) | Bienvenida, carpeta del Arca, varios dispositivos, partidas de ejemplo |
| [Importar saves](usuario/importar.md) | Archivo, carpeta, emuladores de consola y de Switch en Android/iOS, Checkpoint/JKSM |
| [El Arca](usuario/arca.md) | Historial, comparar copias, exportar y restaurar, zip del Arca, saves sueltos |
| [Editor](usuario/editor.md) | Pokémon, cajas, entrenador, inventario, Pokédex, eventos, cintas y origen |
| [Dex](usuario/dex.md) | Pokédex global de todas las partidas, formas especiales (Mega, Gigamax…) y sus reglas, living dex |
| [Competitivo](usuario/competitivo.md) | Pokémon Champions: formato oficial, calculadoras de estadísticas y de daño, equipos en el Arca |
| [Legalidad y avisos](usuario/legalidad.md) | Qué se comprueba, «Intentar corregir», límites |
| [Saves dañados y reparar checksums](usuario/reparar-checksums.md) | Solo lectura, avisos leves y graves, reparar y exportar |
| [Iconos](usuario/iconos.md) | Descarga bajo demanda, caché, sin conexión |
| [Preguntas frecuentes y problemas](usuario/faq.md) | FAQ y solución de problemas |
| [Formatos soportados](formatos.md) | Tabla por juego y plataforma, contenedores, limitaciones |
| [Seguridad de datos y privacidad](seguridad-datos.md) | El original nunca se toca, snapshots inmutables, qué sale a internet |

### Para desarrolladores

| Documento | Contenido |
|---|---|
| [Arquitectura](arquitectura.md) | Monorepo, `pkcore`, app Flutter, flujo de datos (con diagramas) |
| [Desarrollo](desarrollo.md) | Entorno, CI, generadores, oráculo PKHeX, capturas, añadir un formato, commits |
| [Mecánicas de Champions](champions-mecanicas.md) | Estadísticas y daño de Champions con su fuente exacta en Showdown y cómo se comprueban |
| [Publicación en tiendas](publicacion.md) | Auditoría técnica para App Store, Mac App Store y Google Play |
| [Licencias](licencias.md) | GPL-3.0, código portado de PKHeX.Core, PokeAPI, sprites y logo |
| [CHANGELOG](../CHANGELOG.es.md) | Fases y versiones (en inglés: [CHANGELOG.md](../CHANGELOG.md)) |

Las capturas viven en [`screenshots/`](screenshots/) y se generan siempre con
**datos sintéticos** (nunca con saves reales): escritorio en `screenshots/` y
`screenshots/v2/`, Android en `screenshots/android/` e iOS en
`screenshots/ios/`.

Los enlaces y las rutas de imágenes de toda la documentación se comprueban con
`python3 tool/check_links.py` (lo ejecuta `tool/ci.sh`).
