#!/usr/bin/env python3
"""Genera la tabla del formato oficial vigente de Pokémon Champions.

Fuente (pública y actualizable): Pokémon Showdown
  * data/mods/champions/formats-data.ts  -> especies legales (sin isNonstandard)
  * config/formats.ts                     -> nombre y reglas del formato VGC vigente
  * data/rulesets.ts                      -> qué incluye «Flat Rules»

Uso:
  python3 tool/gen_champions_data.py <dir con los .ts> <commit> <fecha AAAA-MM-DD> \
      packages/pkcore/lib/src/data/generated/champions_data.dart

Descarga (fuera de git, en .scratch/):
  curl -o .scratch/champions/formats-data.ts https://raw.githubusercontent.com/smogon/pokemon-showdown/master/data/mods/champions/formats-data.ts
  curl -o .scratch/champions/formats.ts https://raw.githubusercontent.com/smogon/pokemon-showdown/master/config/formats.ts
  curl -o .scratch/champions/rulesets.ts https://raw.githubusercontent.com/smogon/pokemon-showdown/master/data/rulesets.ts
  # commit de formats-data.ts:
  curl 'https://api.github.com/repos/smogon/pokemon-showdown/commits?path=data/mods/champions/formats-data.ts&per_page=1'

Las fechas de la regulación NO están en Showdown: se escriben a mano en
`packages/pkcore/lib/src/tools/champions.dart` (`ChampionsRegulations`) con su
fuente. Ver docs/usuario/formato-oficial.md.
"""
import re
import sys
from pathlib import Path


def parse_species(text: str):
    legal, megas = [], []
    for m in re.finditer(r"^\t([a-z0-9]+): \{(.*?)^\t\},?", text, re.S | re.M):
        sid, body = m.group(1), m.group(2)
        if 'isNonstandard' in body:
            continue
        tier = re.search(r'tier: "([^"]+)"', body)
        if tier and tier.group(1) == 'Illegal':
            continue
        # «meganium» no es una Mega; «meganiummega» sí.
        if re.search(r'.mega[xyz]?$', sid) and sid != 'meganium':
            megas.append(sid)
            continue
        if sid.endswith('gmax'):
            continue
        legal.append(sid)
    return legal, megas


def parse_format(text: str):
    # Último bloque «[Gen 9 Champions] VGC 2026 Reg X» (sin Bo3): el vigente es el primero que aparece.
    for m in re.finditer(r'name: "\[Gen 9 Champions\] (VGC \d{4} Reg [A-Z0-9-]+)",\s*mod: \'([a-z0-9]+)\',(.*?)\n\t\}', formats := text, re.S):
        name, mod, body = m.group(1), m.group(2), m.group(3)
        if mod != 'champions':
            continue
        rules = re.search(r"ruleset: \[(.*?)\]", body)
        rs = [r.strip().strip("'\"") for r in rules.group(1).split(',')] if rules else []
        return name, rs
    raise SystemExit('No se encontró el formato VGC de Champions con mod: champions')


def parse_flat(text: str):
    m = re.search(r"\tflatrules: \{.*?desc: \"([^\"]+)\".*?ruleset: \[(.*?)\],\s*banlist: \[(.*?)\]", text, re.S)
    if not m:
        raise SystemExit('No se encontró Flat Rules')
    split = lambda s: [x.strip().strip("'\"") for x in s.split(',') if x.strip()]
    return m.group(1), split(m.group(2)), split(m.group(3))


def dart_list(name, items):
    out = [f'const {name} = <String>[']
    line = '  '
    for it in items:
        piece = f"'{it}', "
        if len(line) + len(piece) > 118:
            out.append(line.rstrip())
            line = '  '
        line += piece
    if line.strip():
        out.append(line.rstrip())
    out.append('];')
    return '\n'.join(out)


def main():
    src, commit, date, out = Path(sys.argv[1]), sys.argv[2], sys.argv[3], Path(sys.argv[4])
    legal, megas = parse_species((src / 'formats-data.ts').read_text())
    name, ruleset = parse_format((src / 'formats.ts').read_text())
    desc, flat_rules, flat_ban = parse_flat((src / 'rulesets.ts').read_text())
    esc = lambda s: s.replace("'", "\\'")
    body = f"""// GENERADO por tool/gen_champions_data.py — no editar a mano.
// Fuente: Pokémon Showdown (MIT), commit {commit} ({date}).
// ignore_for_file: lines_longer_than_80_chars

const kChampionsSourceCommit = '{commit}';
const kChampionsSourceDate = '{date}';
const kChampionsFormatName = '{esc(name)}';
const kChampionsRuleset = <String>[{', '.join("'" + esc(r) + "'" for r in ruleset)}];
const kChampionsFlatRulesDesc = '{esc(desc)}';
const kChampionsFlatRules = <String>[{', '.join("'" + esc(r) + "'" for r in flat_rules)}];
const kChampionsFlatBanlist = <String>[{', '.join("'" + esc(r) + "'" for r in flat_ban)}];

/// Especies y formas legales (ids de Showdown), sin Megaevoluciones.
{dart_list('kChampionsAllowed', legal)}

/// Megaevoluciones disponibles (ids de Showdown).
{dart_list('kChampionsMegas', megas)}
"""
    out.write_text(body)
    print(f'{name}: {len(legal)} especies/formas, {len(megas)} megas -> {out}')


if __name__ == '__main__':
    main()
