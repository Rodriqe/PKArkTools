#!/usr/bin/env python3
"""Notas de un release a partir de CHANGELOG.md.

Uso: python3 tool/release_notes.py v0.1.0 [salida.md]

Copia la sección «## [0.1.0] …» del CHANGELOG (hasta la siguiente «## ») y
añade el aviso de builds y de proyecto de fans. Falla si la versión del tag
no coincide con `version:` de apps/pkarktools/pubspec.yaml o si el CHANGELOG
no tiene su sección, para no publicar un release a medias.
"""
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')

FOOTER = """
---

**Downloads**

* **Android**: `PKArkTools-{tag}.apk`. Install it from the file (allow
  installing from that source when Android asks).
* **macOS**: `PKArkTools-{tag}-macos.zip`. Unzip it and move the app to
  Applications. It is not notarized: the first time, right-click the app →
  **Open** → **Open**.
* **Windows**: `PKArkTools-{tag}-windows-x64-setup.exe` (installer) or
  `PKArkTools-{tag}-windows-x64.zip` (portable: unzip and run
  `PKArkTools.exe`). It is not signed: if SmartScreen warns, choose **More
  info → Run anyway**. Built and checked by CI only; not yet tested on a PC.
* **Linux**: `PKArkTools-{tag}-linux-x64.tar.gz`. Extract it and run
  `PKArkTools/pkarktools` (needs GTK 3; the folder picker uses `zenity` or
  `kdialog`). Built by CI only; not yet tested on a desktop.
* **iPhone / iPad**: no build yet; compile it from source (see the README).

Fan project, not affiliated with Nintendo, Game Freak, Creatures or The
Pokémon Company. Use it only with your own saves and keep backups.
"""


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    tag = sys.argv[1]
    version = tag[1:] if tag.startswith('v') else tag
    pubspec = open(os.path.join(ROOT, 'apps', 'pkarktools', 'pubspec.yaml'), encoding='utf-8').read()
    m = re.search(r'^version:\s*([0-9A-Za-z.\-]+)(\+\d+)?\s*$', pubspec, re.M)
    if not m or m.group(1) != version:
        print(f'error: el tag {tag} no coincide con pubspec.yaml ({m.group(1) if m else "sin versión"})', file=sys.stderr)
        return 1
    changelog = open(os.path.join(ROOT, 'CHANGELOG.md'), encoding='utf-8').read()
    sec = re.search(rf'^## \[{re.escape(version)}\][^\n]*\n(.*?)(?=^## |\Z)', changelog, re.M | re.S)
    if not sec or not sec.group(1).strip():
        print(f'error: CHANGELOG.md no tiene la sección [{version}]', file=sys.stderr)
        return 1
    notes = f'## PKArkTools {version}\n\n' + sec.group(1).strip() + '\n' + FOOTER.format(tag=tag)
    if len(sys.argv) > 2:
        open(sys.argv[2], 'w', encoding='utf-8').write(notes)
    else:
        sys.stdout.write(notes)
    return 0


if __name__ == '__main__':
    sys.exit(main())
