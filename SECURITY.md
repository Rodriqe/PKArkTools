# Security policy / Política de seguridad

## Supported versions / Versiones soportadas

Only the latest release and `main` receive fixes. / Solo la última versión
publicada y `main` reciben arreglos.

## Reporting a vulnerability / Informar de una vulnerabilidad

**Please do not open a public issue.** Report it privately through GitHub:
**Security → Report a vulnerability** in this repository (private security
advisory). Include the platform, app version, steps to reproduce and, if
relevant, a crafted file that triggers it (never a real save with personal
data unless you agree to share it privately).

**No abras un issue público.** Infórmalo en privado desde GitHub:
**Security → Report a vulnerability** en este repositorio. Indica plataforma,
versión, pasos para reproducirlo y, si aplica, un archivo preparado que lo
provoque (nunca un save real con datos personales salvo que aceptes
compartirlo en privado).

We aim to acknowledge reports within 7 days. / Intentamos responder en 7 días.

## Scope / Alcance

Relevant examples / Ejemplos relevantes:

* Crashes, hangs or memory blow-ups from a malicious save, `.pk*` file or Arca
  zip (all input files are untrusted). / Cierres, bloqueos o consumo excesivo
  con un save, `.pk*` o zip del Arca malicioso.
* Path traversal or writes outside the chosen folder when importing, restoring
  a zip or reindexing. / Escrituras fuera de la carpeta elegida al importar,
  restaurar un zip o reindexar.
* Any path where the app could modify or delete an original save or an Arca
  copy without the user asking. / Cualquier caso en que la app modifique o
  borre un save original o una copia del Arca sin que el usuario lo pida.
* Network access other than the optional sprite download described in
  [docs/seguridad-datos.md](docs/seguridad-datos.md). / Accesos a red distintos
  de la descarga opcional de iconos.

Out of scope / Fuera de alcance: legality-check false positives/negatives (open
a normal issue) and anything requiring a modified build of the app.
