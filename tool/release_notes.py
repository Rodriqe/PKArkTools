#!/usr/bin/env python3
"""Release notes (in English) from CHANGELOG.md.

Usage: python3 tool/release_notes.py [--any-version] [--macos-status FILE] vX.Y.Z [output.md]

Copies the "## [X.Y.Z] …" section of the English CHANGELOG.md (up to the next
"## ") under a "PKArkTools X.Y.Z" heading and appends the Downloads section and
the fan-project disclaimer. Fails if the tag does not match `version:` in
apps/pkarktools/pubspec.yaml or the CHANGELOG has no section for it, so a
half-done release is never published. `--any-version` skips the pubspec check,
to regenerate the notes of an already published release. `--macos-status`
reads the marker written by tool/macos_sign_notarize.sh (adhoc, signed or
notarized) so the macOS line only promises what the build job really did;
without it (or if it is missing) the text stays neutral.
"""
import os
import re
import sys

REPO = 'https://github.com/Rodriqe/PKArkTools'
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')

FOOTER = """
---

### Downloads

* **Android**: `PKArkTools-{tag}.apk`. Install it from the file (allow
  installing from that source when Android asks).
* **macOS**: {macos}
* **Windows**: `PKArkTools-{tag}-windows-x64-setup.exe` (installer) or
  `PKArkTools-{tag}-windows-x64.zip` (portable: unzip and run
  `PKArkTools.exe`). It is not signed: if SmartScreen warns, choose **More
  info → Run anyway**. Built and checked by CI only; not yet tested on a PC.
* **Linux**: `PKArkTools-{tag}-linux-x64.tar.gz`. Extract it and run
  `PKArkTools/pkarktools` (needs GTK 3; the folder picker uses `zenity` or
  `kdialog`). Built by CI only; not yet tested on a desktop.
* **iPhone / iPad**: no build yet; build it from source (see the README).

Fan project, not affiliated with or endorsed by Nintendo, Game Freak,
Creatures or The Pokémon Company. No ROMs, game files or sprites are
included (icons are downloaded on demand). Use it only with your own saves
and keep backups.
"""


MACOS = {
    'notarized': "`PKArkTools-{tag}-macos.dmg`. Open it and drag PKArkTools to\n"
                 "  Applications (`PKArkTools-{tag}-macos.zip` has the same app). Signed with\n"
                 "  Developer ID and notarized by Apple, so it opens with a double-click.",
    'signed': "`PKArkTools-{tag}-macos.dmg`. Open it and drag PKArkTools to\n"
              "  Applications (`PKArkTools-{tag}-macos.zip` has the same app). Signed with\n"
              "  Developer ID but not notarized: the first time, right-click → **Open**.",
    'adhoc': "`PKArkTools-{tag}-macos.zip`. Unzip it and move PKArkTools to\n"
             "  Applications. It is not notarized: the first time, right-click → **Open**.",
    None: "`PKArkTools-{tag}-macos.dmg` (or the `.zip` with the same app). Open\n"
          "  it and move PKArkTools to Applications; if macOS asks, right-click → **Open**.",
}


def macos_status(path):
    try:
        v = open(path, encoding='utf-8').read().strip()
    except (OSError, TypeError):
        return None
    return v if v in MACOS else None


def main() -> int:
    args = sys.argv[1:]
    any_version = '--any-version' in args
    args = [a for a in args if a != '--any-version']
    status_file = None
    if '--macos-status' in args:
        i = args.index('--macos-status')
        status_file = args[i + 1] if i + 1 < len(args) else None
        del args[i:i + 2]
    if not args:
        print(__doc__)
        return 2
    tag = args[0]
    version = tag[1:] if tag.startswith('v') else tag
    pubspec = open(os.path.join(ROOT, 'apps', 'pkarktools', 'pubspec.yaml'), encoding='utf-8').read()
    m = re.search(r'^version:\s*([0-9A-Za-z.\-]+)(\+\d+)?\s*$', pubspec, re.M)
    if not any_version and (not m or m.group(1) != version):
        print(f'error: tag {tag} does not match pubspec.yaml ({m.group(1) if m else "no version"})', file=sys.stderr)
        return 1
    changelog = open(os.path.join(ROOT, 'CHANGELOG.md'), encoding='utf-8').read()
    sec = re.search(rf'^## \[{re.escape(version)}\][^\n]*\n(.*?)(?=^## |\Z)', changelog, re.M | re.S)
    if not sec or not sec.group(1).strip():
        print(f'error: CHANGELOG.md has no [{version}] section', file=sys.stderr)
        return 1
    # Relative links (docs/…) do not resolve in a Release body: point them at the tag.
    body = re.sub(r'\]\((?!https?:|#|mailto:)([^)]+)\)', lambda l: f']({REPO}/blob/{tag}/{l.group(1)})', sec.group(1).strip())
    notes = f'## PKArkTools {version}\n\n' + body + '\n' + FOOTER.format(tag=tag, macos=MACOS[macos_status(status_file)].format(tag=tag))
    if len(args) > 1:
        open(args[1], 'w', encoding='utf-8').write(notes)
    else:
        sys.stdout.write(notes)
    return 0


if __name__ == '__main__':
    sys.exit(main())
