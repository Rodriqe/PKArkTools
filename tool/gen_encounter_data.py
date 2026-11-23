#!/usr/bin/env python3
"""Genera las tablas de encuentros de pkcore a partir de PKHeX.Core (GPL-3.0) y PokeAPI (BSD-3).

Uso:
    python3 tool/gen_encounter_data.py <ruta a PKHeX.Core> <pokemon_species.csv de PokeAPI> \
        packages/pkcore/lib/src/data/generated/encounter_data.dart

Produce `encounter_data.dart` con:
  * kEncounters: por versión de origen (ids de PKHeX `GameVersion`), registros
    de 8 bytes en base64: u16 lugar, u16 especie, u8 forma, u8 nivel mín.,
    u8 nivel máx., u8 tipo (0 salvaje, 1 estático, 2 regalo, 3 intercambio).
    - Salvajes: Resources/legality/wild/Gen3–Gen9/*.pkl (formatos de
      EncounterArea3/4/5/6XY/6AO/7/7b/8/8a/8b/9/9a).
    - Estáticos, regalos e intercambios: inicializadores `new(...) { Species = …,
      Level = …, Location = … }` de Legality/Encounters/Data/Gen4–Gen9/*.cs.
      Los intercambios con NPC se guardan con lugar 0xFFFF (cualquiera).
  * kEvolvesFrom: especie → preevolución (PokeAPI `evolves_from_species_id`).
  * kLocationNames: nombres de lugares (es/en) por generación, solo los usados.
"""
import base64
import csv
import os
import re
import struct
import sys
from collections import defaultdict

PK, SPECIES_CSV, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
WILD = os.path.join(PK, 'Resources', 'legality', 'wild')
DATA = os.path.join(PK, 'Legality', 'Encounters', 'Data')
LOC = os.path.join(PK, 'Resources', 'text', 'locations')

WILD_T, STATIC_T, GIFT_T, TRADE_T, RAID_T = 0, 1, 2, 3, 4
ANY_LOCATION = 0xFFFF
# Incursión Dinamax en cualquier guarida (Zona Silvestre, Isla de la Armadura,
# Corona Nevada o el nido compartido 162), PKHeX `EncounterStatic8N/ND.IsMatchLocation`.
ANY_DEN = 0xFFFE

# PKHeX `EncounterArea8.GetAreasCanWanderTo`: los símbolos de un área pueden
# encontrarse en las zonas vecinas.
WANDER8 = {
    28: [20], 122: [124, 128, 130], 124: [122, 126], 126: [124, 130], 128: [122, 130, 132, 138],
    130: [122, 126, 128, 132], 132: [128, 130], 134: [136, 138], 136: [134, 138], 138: [134, 136],
    140: [142], 142: [140, 144], 144: [142, 146, 148, 152], 146: [144, 148, 150], 148: [144, 146, 148],
    150: [146, 148, 152], 152: [144, 150], 170: [166, 176], 174: [172], 176: [178], 182: [180, 184],
    186: [164], 188: [170], 190: [192], 192: [194], 208: [206], 212: [210], 224: [222], 230: [232],
}


def is_wild_area8(loc):
    """PKHeX `EncounterArea8.IsWildArea` (Zona Silvestre, Isla de la Armadura y Corona Nevada)."""
    return 122 <= loc <= 154 or 164 <= loc <= 194 or (204 <= loc <= 234 and loc != 206)

V = {  # PKHeX GameVersion
    'S': 1, 'R': 2, 'E': 3, 'FR': 4, 'LG': 5, 'HG': 7, 'SS': 8, 'D': 10, 'P': 11, 'Pt': 12,
    'W': 20, 'B': 21, 'W2': 22, 'B2': 23, 'X': 24, 'Y': 25, 'AS': 26, 'OR': 27,
    'SN': 30, 'MN': 31, 'US': 32, 'UM': 33, 'GP': 42, 'GE': 43, 'SW': 44, 'SH': 45,
    'PLA': 47, 'BD': 48, 'SP': 49, 'SL': 50, 'VL': 51, 'ZA': 52,
}
GROUPS = {
    'RS': ['R', 'S'], 'RSE': ['R', 'S', 'E'], 'FRLG': ['FR', 'LG'], 'DP': ['D', 'P'], 'DPPt': ['D', 'P', 'Pt'],
    'HGSS': ['HG', 'SS'], 'BW': ['B', 'W'], 'B2W2': ['B2', 'W2'], 'XY': ['X', 'Y'], 'ORAS': ['OR', 'AS'],
    'SM': ['SN', 'MN'], 'USUM': ['US', 'UM'], 'GG': ['GP', 'GE'], 'SWSH': ['SW', 'SH'], 'BDSP': ['BD', 'SP'],
    'SV': ['SL', 'VL'], 'LA': ['PLA'], 'PLA': ['PLA'], 'ZA': ['ZA'],
}


def versions(token):
    if token in V:
        return [V[token]]
    if token in GROUPS:
        return [V[t] for t in GROUPS[token]]
    return None


def binlinker(path, wide=True):
    d = open(path, 'rb').read()
    n = struct.unpack_from('<H', d, 2)[0]
    out = []
    for i in range(n):
        if wide:
            s, e = struct.unpack_from('<II', d, 4 + i * 4)
        else:
            s, e = struct.unpack_from('<HH', d, 4 + i * 2)
        out.append(d[s:e])
    return out


def packed(sp):
    return sp & 0x3FF, sp >> 11


records = defaultdict(set)  # version -> {(loc, species, form, min, max, type)}


def add(vers, loc, species, form, lo, hi, typ=WILD_T):
    if species == 0 or species > 1025:
        return
    for v in vers:
        records[v].add((loc & 0xFFFF, species, form & 0xFF, max(1, lo) & 0xFF, max(lo, hi, 1) & 0xFF, typ))


def wild_gen34(path, vers, header):
    for a in binlinker(path):
        loc = a[0]
        for i in range(header, len(a) - 9, 10):
            sp = struct.unpack_from('<H', a, i)[0]
            add(vers, loc, sp, a[i + 2], a[i + 4], a[i + 5])


def wild_packed4(path, vers, loc_u16=True, header=4):
    for a in binlinker(path):
        loc = struct.unpack_from('<H', a, 0)[0] if loc_u16 else a[0]
        for i in range(header, len(a) - 3, 4):
            sp, form = packed(struct.unpack_from('<H', a, i)[0])
            add(vers, loc, sp, form, a[i + 2], a[i + 3])


def wild_7b(path, vers):
    """Let's Go (PKHeX `EncounterArea7b`/`EncounterSlot7b`): el combo de captura
    sube el nivel máximo en 1 y cada especie puede cruzar a las zonas vecinas
    `ToArea1`/`ToArea2` según sus bits de `CrossoverFlags`."""
    for a in binlinker(path):
        loc, to1, to2 = a[0], a[2], a[3]
        for i in range(4, len(a) - 3, 4):
            sp, flags, lo, hi = a[i], a[i + 1], a[i + 2], a[i + 3] + 1
            add(vers, loc, sp, 0, lo, hi)
            for bit, to in ((1, to1), (2, to2)):
                if to and flags & bit:
                    add(vers, to, sp, 0, lo, hi)


def wild_8(path, vers):
    for a in binlinker(path):
        loc, count = a[0], a[1]
        ofs, ctr = 2, 0
        while ctr < count and ofs + 6 <= len(a):
            lo, hi, n = a[ofs + 2], a[ofs + 3], a[ofs + 4]
            ofs += 6
            for _ in range(n):
                sp, form = packed(struct.unpack_from('<H', a, ofs)[0])
                for l in [loc] + WANDER8.get(loc, []):
                    add(vers, l, sp, form, lo, hi)
                    # Con 8 medallas, los salvajes de las zonas silvestres suben a nivel 60 (PKHeX `BoostLevel`).
                    if is_wild_area8(l):
                        add(vers, l, sp, form, 60, 60)
                ofs += 2
                ctr += 1


RAID_LEVEL_CAPS = [15, 20, 25, 30, 35, 40, 45, 50, 55, 60]  # PKHeX EncounterStatic8N.LevelCaps


def raids_8():
    """Incursiones Dinamax de Espada/Escudo (PKHeX `Encounters8Nest`): nidos fijos,
    distribuciones, Aventura Dinamax y cristales de los Pokémon Dinamax.

    El nivel de encuentro puede bajar al compartir la incursión (PKHeX
    `IsDownLeveled`), así que se acepta desde 15 hasta el máximo del nido."""
    g8 = os.path.join(WILD, 'Gen8')
    for f, v in (('sw_nest', 'SW'), ('sh_nest', 'SH')):
        d = open(os.path.join(g8, f'encounter_{f}.pkl'), 'rb').read()
        for i in range(0, len(d) - 9, 10):
            sp, form, max_rank = struct.unpack_from('<H', d, i)[0], d[i + 2], d[i + 8]
            add(versions(v), ANY_DEN, sp, form, 15, RAID_LEVEL_CAPS[max_rank * 2 + 1], RAID_T)
    for f, v in (('sw_dist', 'SW'), ('sh_dist', 'SH')):
        d = open(os.path.join(g8, f'encounter_{f}.pkl'), 'rb').read()
        for i in range(0, len(d) - 15, 16):
            sp, form, lvl = struct.unpack_from('<H', d, i)[0], d[i + 2], d[i + 12]
            add(versions(v), ANY_DEN, sp, form, 15, lvl, RAID_T)
    d = open(os.path.join(g8, 'encounter_swsh_underground.pkl'), 'rb').read()
    for i in range(0, len(d) - 13, 14):
        sp, form, lvl = struct.unpack_from('<H', d, i)[0], d[i + 2], d[i + 3]
        add(versions('SWSH'), 244, sp, form, lvl, lvl, STATIC_T)  # Supernido Dinamax
    code = open(os.path.join(DATA, 'Gen8', 'Encounters8Nest.cs'), encoding='utf-8-sig').read()
    crystal = code[code.index('Crystal_SWSH'):]
    crystal = crystal[:crystal.index('];')]
    for m in INIT.finditer(crystal):
        vers = next((versions(t) for t in re.split(r'[\s,]+', m.group(1)) if versions(t)), versions('SWSH'))
        sp, lvl = field(m.group(2), 'Species'), field(m.group(2), 'Level')
        for loc in (162, 126):  # nido compartido o Ruinas de la Atalaya
            add(vers, loc, sp, field(m.group(2), 'Form') or 0, 20 if loc == 162 else lvl, lvl, RAID_T)


def wild_8a(path, vers):
    for a in binlinker(path):
        nloc = a[0]
        locs = list(a[1:1 + nloc])
        align = nloc + 1
        align += align & 1
        b = a[align:]
        count = b[1]
        for i in range(count):
            e = b[2 + i * 8: 2 + i * 8 + 8]
            sp = struct.unpack_from('<H', e, 0)[0]
            for loc in locs:
                add(vers, loc, sp, e[2], e[4], e[5])


def wild_8slot(path, vers, loc_u16, wide=True):
    for a in binlinker(path, wide):
        loc = struct.unpack_from('<H', a, 0)[0] if loc_u16 else a[0]
        for i in range(4, len(a) - 7, 8):
            sp = struct.unpack_from('<H', a, i)[0]
            add(vers, loc, sp, a[i + 2], a[i + 4], a[i + 5])


def load_wild():
    w = lambda g, f: os.path.join(WILD, g, f'encounter_{f}.pkl')
    for f, v in (('r', 'R'), ('s', 'S'), ('e', 'E'), ('fr', 'FR'), ('lg', 'LG')):
        wild_gen34(w('Gen3', f), versions(v), 4)
    for f, v in (('d', 'D'), ('p', 'P'), ('pt', 'Pt'), ('hg', 'HG'), ('ss', 'SS')):
        wild_gen34(w('Gen4', f), versions(v), 6)
    for f, v in (('b', 'B'), ('w', 'W'), ('b2', 'B2'), ('w2', 'W2')):
        wild_packed4(w('Gen5', f), versions(v))
    for f, v in (('x', 'X'), ('y', 'Y'), ('or', 'OR'), ('as', 'AS')):
        wild_packed4(w('Gen6', f), versions(v))
    for f, v in (('sn', 'SN'), ('mn', 'MN'), ('us', 'US'), ('um', 'UM')):
        wild_packed4(w('Gen7', f), versions(v))
    for f, v in (('gp', 'GP'), ('ge', 'GE')):
        wild_7b(w('Gen7', f), versions(v))
    for f, v in (('sw_symbol', 'SW'), ('sw_hidden', 'SW'), ('sh_symbol', 'SH'), ('sh_hidden', 'SH')):
        wild_8(w('Gen8', f), versions(v))
    for f, v in (('bd', 'BD'), ('sp', 'SP')):
        wild_packed4(w('Gen8', f), versions(v))
    wild_8a(w('Gen8', 'la'), versions('PLA'))
    wild_8slot(w('Gen9', 'wild_paldea'), versions('SV'), loc_u16=False)
    wild_8slot(w('Gen9', 'za'), versions('ZA'), loc_u16=True, wide=False)
    wild_8slot(w('Gen9', 'hyperspace_za'), versions('ZA'), loc_u16=True, wide=False)


STATIC_FILES = {
    'Gen4/Encounters4DPPt.cs': 'DPPt', 'Gen4/Encounters4HGSS.cs': 'HGSS',
    'Gen5/Encounters5BW.cs': 'BW', 'Gen5/Encounters5B2W2.cs': 'B2W2',
    'Gen6/Encounters6XY.cs': 'XY', 'Gen6/Encounters6AO.cs': 'ORAS',
    'Gen7/Encounters7SM.cs': 'SM', 'Gen7/Encounters7USUM.cs': 'USUM', 'Gen7/Encounters7GG.cs': 'GG',
    'Gen8/Encounters8.cs': 'SWSH', 'Gen8/Encounters8b.cs': 'BDSP', 'Gen9/Encounters9.cs': 'SV',
}

INIT = re.compile(r'new\(([^()]*(?:\([^()]*\)[^()]*)*)\)\s*\{([^{}]*)\}')
DECL = re.compile(r'static readonly (Encounter\w+)\[\]')


def field(body, name):
    m = re.search(r'\b' + name + r'\s*=\s*(\d+)', body)
    return int(m.group(1)) if m else None


def load_static():
    stats = defaultdict(int)
    for rel, default in STATIC_FILES.items():
        code = open(os.path.join(DATA, rel), encoding='utf-8-sig').read()
        decls = [(m.start(), m.group(1)) for m in DECL.finditer(code)]
        for m in INIT.finditer(code):
            args, body = m.group(1), m.group(2)
            sp = field(body, 'Species')
            if sp is None:
                continue
            kind = next((k for pos, k in reversed(decls) if pos < m.start()), 'EncounterStatic')
            vers = None
            for tok in re.split(r'[\s,]+', args):
                vers = versions(tok.strip())
                if vers:
                    break
            vers = vers or versions(default)
            lvl = field(body, 'Level')
            lo, hi = field(body, 'LevelMin'), field(body, 'LevelMax')
            if lvl is not None:
                lo = hi = lvl
            if lo is None:
                continue
            hi = hi or lo
            form = field(body, 'Form') or 0
            if 'Trade' in kind:
                add(vers, ANY_LOCATION, sp, form, lo, hi, TRADE_T)
                stats['trade'] += 1
                continue
            loc = field(body, 'Location')
            if loc is None:
                continue
            gift = 'FixedBall' in body or 'Gift = true' in body
            # Estáticos que deambulan por varias zonas (aves de Galar): PKHeX `Crossover`.
            cross = re.search(r'Crossover\s*=\s*new\(([^)]*)\)', body)
            extra = [int(x) for x in cross.group(1).split(',')] if cross else []
            for l in [loc] + extra:
                add(vers, l, sp, form, lo, hi, GIFT_T if gift else STATIC_T)
            stats['gift' if gift else 'static'] += 1
    return stats


LOC_FILES = {  # generación -> (carpeta, prefijo)
    3: ('gen3', 'rsefrlg'), 4: ('gen4', 'hgss'), 5: ('gen5', 'bw2'), 6: ('gen6', 'xy'), 7: ('gen7', 'sm'),
    'lgpe': ('gen7', 'gg'), 8: ('gen8', 'swsh'), 'la': ('gen8a', 'la'), 'bdsp': ('gen8b', 'bdsp'), 9: ('gen9', 'sv'),
}


def loc_key(v):
    if v in (42, 43):
        return 'lgpe'
    if v == 47:
        return 'la'
    if v in (48, 49):
        return 'bdsp'
    if v == 52:
        return 9
    return {1: 3, 2: 3, 3: 3, 4: 3, 5: 3, 7: 4, 8: 4, 10: 4, 11: 4, 12: 4, 20: 5, 21: 5, 22: 5, 23: 5,
            24: 6, 25: 6, 26: 6, 27: 6, 30: 7, 31: 7, 32: 7, 33: 7, 44: 8, 45: 8, 50: 9, 51: 9}[v]


def location_names(used):
    out = {}
    for key, locs in used.items():
        folder, prefix = LOC_FILES[key]
        for lang in ('es', 'en'):
            path = os.path.join(LOC, folder, f'text_{prefix}_00000_{lang}.txt')
            if not os.path.exists(path):
                continue
            lines = open(path, encoding='utf-8-sig').read().splitlines()
            rows = [f'{i}\t{lines[i].strip()}' for i in sorted(locs) if i < len(lines) and lines[i].strip()]
            out[f'{key}_{lang}'] = '\n'.join(rows)
    return out


def dart_str(s):
    return "'" + s.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$').replace('\n', '\\n') + "'"


def main():
    load_wild()
    stats = load_static()
    raids_8()
    evolves = [0] * 1026
    with open(SPECIES_CSV, encoding='utf-8') as f:
        for row in csv.DictReader(f):
            i = int(row['id'])
            if i <= 1025 and row['evolves_from_species_id']:
                evolves[i] = int(row['evolves_from_species_id'])
    used = defaultdict(set)
    out = ['// GENERADO por tool/gen_encounter_data.py desde PKHeX.Core (GPL-3.0) y PokeAPI (BSD-3). No editar a mano.',
           '// ignore_for_file: lines_longer_than_80_chars', '',
           '/// Por versión de origen: registros de 8 bytes (u16 lugar, u16 especie, u8 forma,',
           '/// u8 nivel mín., u8 nivel máx., u8 tipo) en base64.',
           'const Map<int, String> kEncounters = {']
    total = 0
    for v in sorted(records):
        recs = sorted(records[v])
        total += len(recs)
        blob = b''.join(struct.pack('<HHBBBB', *r) for r in recs)
        out.append(f"  {v}: '{base64.b64encode(blob).decode()}',")
        for r in recs:
            if r[0] != ANY_LOCATION:
                used[loc_key(v)].add(r[0])
    out.append('};\n')
    out.append('/// Preevolución de cada especie (0 = ninguna), de PokeAPI.')
    vals = ', '.join(map(str, evolves))
    out.append(f'const List<int> kEvolvesFrom = <int>[{vals}];\n')
    out.append('/// Nombres de lugares "<clave>_<idioma>" → TSV "id<TAB>nombre" (clave = generación, lgpe, la o bdsp).')
    out.append('const Map<String, String> kLocationNames = {')
    for k, txt in location_names(used).items():
        out.append(f"  '{k}': {dart_str(txt)},")
    out.append('};\n')
    open(OUT, 'w', encoding='utf-8').write('\n'.join(out))
    print('ok', OUT, 'versions', len(records), 'records', total, dict(stats), os.path.getsize(OUT))


main()
