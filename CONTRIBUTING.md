# Contributing to PKArkTools

[English](#english) · [Español](#español)

## English

Thanks for your interest! PKArkTools is a GPL-3.0 fan project; contributions of
code, docs, translations, bug reports and save-format research are welcome.

### Ground rules

* **Never** add ROMs, BIOS files, console keys, sprites or other copyrighted
  assets, and never commit real saves or screenshots with real personal data
  (trainer names, IDs). Tests use synthetic saves from
  `package:pkcore/testing.dart`; tests against real saves read them from the
  untracked `.ref/real-saves/` folder and are skipped when it is absent.
* Logic ported from [PKHeX.Core](https://github.com/kwsch/PKHeX) (GPL-3.0) must
  keep its credit in the file header and in [`NOTICE`](NOTICE).
* By contributing you agree that your work is licensed under GPL-3.0
  ([`LICENSE`](LICENSE)).
* Be kind: see the [Code of Conduct](CODE_OF_CONDUCT.md). Security issues go
  through [SECURITY.md](SECURITY.md), not public issues.

### Workflow

1. Open an issue first for anything larger than a small fix, so we can agree on
   the approach.
2. Fork, create a branch (`<user>/<topic>`) and set up the environment as in
   [docs/desarrollo.md](docs/desarrollo.md) (Flutter stable, `flutter pub get`).
3. Keep commits small and focused (core, app, tests, docs separately). Commit
   messages in English or Spanish, one descriptive line saying what changes
   and where (`pkcore: …` for core-only changes).
4. Run `tool/ci.sh` (analysis with `--fatal-infos`, tests of `pkcore` and the
   app, doc links). It must be green; GitHub Actions runs the same checks.
5. User-facing strings go in **both** `apps/pkarktools/lib/l10n/app_es.arb`
   and `app_en.arb` (`tool/l10n_add.py` helps).
6. Open a pull request using the template.

To add support for a new game or save format, follow
[“Cómo añadir un juego o formato”](docs/desarrollo.md#cómo-añadir-un-juego-o-formato)
and document it in [docs/formatos.md](docs/formatos.md).

## Español

¡Gracias por tu interés! PKArkTools es un proyecto de fans con licencia
GPL-3.0; se agradecen contribuciones de código, documentación, traducciones,
informes de errores e investigación de formatos de save.

### Reglas básicas

* **Nunca** añadas ROMs, BIOS, claves de consola, sprites ni otro material con
  copyright, ni subas saves reales o capturas con datos personales reales
  (nombres de entrenador, IDs). Los tests usan saves sintéticos de
  `package:pkcore/testing.dart`; los que usan saves reales los leen de
  `.ref/real-saves/` (fuera de git) y se omiten si no existe.
* La lógica portada de [PKHeX.Core](https://github.com/kwsch/PKHeX) (GPL-3.0)
  conserva su crédito en la cabecera del archivo y en [`NOTICE`](NOTICE).
* Al contribuir aceptas que tu trabajo se publique bajo GPL-3.0
  ([`LICENSE`](LICENSE)).
* Trato respetuoso: ver el [Código de conducta](CODE_OF_CONDUCT.md). Los
  problemas de seguridad van por [SECURITY.md](SECURITY.md), no por issues
  públicos.

### Flujo de trabajo

1. Para algo más que un arreglo pequeño, abre antes un issue y acordamos el
   enfoque.
2. Haz un fork, crea una rama (`<usuario>/<tema>`) y prepara el entorno según
   [docs/desarrollo.md](docs/desarrollo.md) (Flutter estable,
   `flutter pub get`).
3. Commits pequeños y por bloque (núcleo, app, tests, docs). Mensajes en
   español o inglés, en una línea que diga qué cambia y dónde (`pkcore: …`
   para cambios solo del núcleo).
4. Ejecuta `tool/ci.sh` (análisis con `--fatal-infos`, tests de `pkcore` y de
   la app, enlaces de la documentación). Debe quedar en verde; GitHub Actions
   ejecuta lo mismo.
5. Los textos visibles van en `app_es.arb` **y** `app_en.arb`
   (`apps/pkarktools/lib/l10n/`; ayuda: `tool/l10n_add.py`).
6. Abre el pull request con la plantilla.

Para soportar un juego o formato nuevo sigue
[«Cómo añadir un juego o formato»](docs/desarrollo.md#cómo-añadir-un-juego-o-formato)
y documéntalo en [docs/formatos.md](docs/formatos.md).
