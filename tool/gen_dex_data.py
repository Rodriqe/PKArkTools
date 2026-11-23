#!/usr/bin/env python3
"""Genera las tablas de Pokédex de Gen 6–9 de pkcore a partir de PKHeX.Core (GPL-3.0).

Uso:
    python3 tool/gen_dex_data.py <ruta a PKHeX.Core> packages/pkcore/lib/src/data/generated/dex_data.dart

Produce `dex_data.dart` con:
  * Índices de formas de la Pokédex Gen 5–6 (Zukan5/Zukan6: `GetFormIndex*`).
  * Especies con formas y número de formas de la Pokédex Gen 7 (DexFormUtil).
  * Por especie (Switch): número de formas, máscara de formas presentes en el juego y su índice
    en cada Pokédex regional (Galar/Armadura/Corona; Hisui; Paldea/Kitakami/
    Arándano; Ciudad Luminalia), leído de `Resources/byte/personal`.
  * Tabla de entradas estadísticas por especie/forma de Leyendas Arceus
    (PokedexConstants8a.FormStorageIndexIds/Values).
"""
import os
import re
import struct
import sys

PK = sys.argv[1]
OUT = sys.argv[2]
PERSONAL = os.path.join(PK, 'Resources', 'byte', 'personal')
DEX = os.path.join(PK, 'Saves', 'Substructures', 'PokeDex')


def src(*parts):
    return open(os.path.join(PK, *parts), encoding='utf-8-sig').read()


def switch_pairs(code, func):
    """Extrae `NNN => (III, CC)` del switch de [func]."""
    i = code.index(func + '(ushort species) => species switch')
    body = code[i:code.index('};', i)]
    return [(int(a), int(b), int(c)) for a, b, c in re.findall(r'(\d+)\s*=>\s*\((\d+),\s*(\d+)\)', body)]


def cs_array(code, name):
    i = code.index(name)
    a = code.index('[', i + len(name))
    b = code.index(']', a)
    body = re.sub(r'//[^\n]*', '', code[a + 1:b])
    return [int(x, 16) if x.startswith('0x') else int(x) for x in re.findall(r'0x[0-9A-Fa-f]+|\d+', body)]


def personal(name, size, fields):
    raw = open(os.path.join(PERSONAL, name), 'rb').read()
    out = []
    for i in range(len(raw) // size):
        e = raw[i * size:(i + 1) * size]
        out.append({k: f(e) for k, f in fields.items()})
    return out


u16 = lambda o: (lambda e: struct.unpack_from('<H', e, o)[0])
u8 = lambda o: (lambda e: e[o])
bit = lambda o, b: (lambda e: (e[o] >> b) & 1)


def per_species(table, max_species, keys):
    """Para cada especie, busca en todas sus formas el primer índice no nulo de cada clave."""
    rows = []
    for s in range(max_species + 1):
        base = table[s]
        forms = [base]
        fc, fi = base['fc'], base['fi']
        if fi and fc > 1:
            forms += [table[fi + f - 1] for f in range(1, fc) if fi + f - 1 < len(table)]
        row = [max(1, fc), sum(1 << i for i, f in enumerate(forms[:31]) if f['present'])]
        for k in keys:
            row.append(next((f[k] for f in forms if f[k]), 0))
        rows.append(row)
    return rows


def flat(name, rows):
    vals = [v for r in rows for v in r]
    lines = []
    for i in range(0, len(vals), 24):
        lines.append('  ' + ', '.join(str(v) for v in vals[i:i + 24]) + ',')
    return f'const List<int> {name} = <int>[\n' + '\n'.join(lines) + '\n];\n'


def main():
    z5 = open(os.path.join(DEX, 'Zukan5.cs'), encoding='utf-8-sig').read()
    z6 = open(os.path.join(DEX, 'Zukan6.cs'), encoding='utf-8-sig').read()
    gen6 = {}
    for func, code in (('GetFormIndexBW', z5), ('GetFormIndexB2W2', z5), ('GetFormIndexXY', z6), ('GetFormIndexAO', z6)):
        gen6[func] = switch_pairs(code, func)

    dfu = src('Saves', 'Util', 'DexFormUtil.cs')
    gen7 = {k: (cs_array(dfu, f'DexSpeciesWithForm_{k} =>'), cs_array(dfu, f'DexSpeciesCount_{k} =>')) for k in ('SM', 'USUM', 'GG')}

    swsh = personal('personal_swsh', 0xB0, {
        'fi': u16(0x1E), 'fc': u8(0x20), 'present': bit(0x21, 6),
        'galar': u16(0x5C), 'armor': u16(0xAC), 'crown': u16(0xAE)})
    la = personal('personal_la', 0xB0, {
        'fi': u16(0x1E), 'fc': u8(0x20), 'present': bit(0x21, 6), 'hisui': u16(0x60)})
    sv = personal('personal_sv', 0x50, {
        'fi': u16(0x18), 'fc': u8(0x1A), 'present': u8(0x1C),
        'paldea': u16(0x1E), 'kitakami': u8(0x4A), 'blueberry': u8(0x4B)})
    za = personal('personal_za', 0x50, {
        'fi': u16(0x18), 'fc': u8(0x1A), 'present': u8(0x1C), 'lumiose': u16(0x1E)})
    for t in (sv, za):
        for e in t:
            e['present'] = 1 if e['present'] else 0

    # SwSh usa solo la forma base para su índice (PKHeX Zukan8.GetDexLookup).
    swsh_rows = []
    for s in range(899):
        b = swsh[s]
        forms = [b] + ([swsh[b['fi'] + f - 1] for f in range(1, b['fc'])] if b['fi'] and b['fc'] > 1 else [])
        swsh_rows.append([max(1, b['fc']), sum(1 << i for i, f in enumerate(forms[:31]) if f['present']), b['galar'], b['armor'], b['crown']])

    la_rows = per_species(la, 905, ['hisui'])
    sv_rows = per_species(sv, 1025, ['paldea', 'kitakami', 'blueberry'])
    za_rows = per_species(za, 1025, ['lumiose'])

    c8a = src('Saves', 'Substructures', 'Gen8', 'LA', 'Pokedex', 'PokedexConstants8a.cs')
    fst_ids = cs_array(c8a, 'FormStorageIndexIds =>')
    fst_vals = cs_array(c8a, 'FormStorageIndexValues =>')
    assert len(fst_ids) == len(fst_vals), (len(fst_ids), len(fst_vals))

    out = ['// GENERADO por tool/gen_dex_data.py desde PKHeX.Core (GPL-3.0). No editar a mano.',
           '// ignore_for_file: lines_longer_than_80_chars', '']
    for func, pairs in gen6.items():
        name = 'kDexForms' + func.replace('GetFormIndex', '')
        out.append(f'/// PKHeX `{func}`: especie → (índice del primer bit de forma, número de formas).')
        out.append(f'const Map<int, (int, int)> {name} = {{')
        out.append('  ' + ', '.join(f'{s}: ({i}, {c})' for s, i, c in pairs) + ',')
        out.append('};\n')
    for k, (species, counts) in gen7.items():
        assert len(species) == len(counts), k
        out.append(f'/// PKHeX `DexFormUtil.DexSpeciesWithForm_{k}` / `DexSpeciesCount_{k}`.')
        out.append(f'const List<int> kDex7Species{k.title()} = <int>[{", ".join(map(str, species))}];')
        out.append(f'const List<int> kDex7Counts{k.title()} = <int>[{", ".join(map(str, counts))}];\n')
    out.append('/// Espada/Escudo: por especie [formas, máscara de formas presentes, Galar, Armadura, Corona] (5 valores).')
    out.append(flat('kDexSwsh', swsh_rows))
    out.append('/// Leyendas Arceus: por especie [formas, máscara de formas presentes, Hisui] (3 valores).')
    out.append(flat('kDexLa', la_rows))
    out.append('/// Escarlata/Púrpura: por especie [formas, máscara de formas presentes, Paldea, Kitakami, Arándano] (5 valores).')
    out.append(flat('kDexSv', sv_rows))
    out.append('/// Leyendas Z-A: por especie [formas, máscara de formas presentes, Luminalia] (3 valores).')
    out.append(flat('kDexZa', za_rows))
    out.append('/// Leyendas Arceus: `species | form << 11` → entrada estadística (PokedexConstants8a).')
    out.append(flat('kDexLaFormIds', [fst_ids]))
    out.append(flat('kDexLaFormSlots', [fst_vals]))
    open(OUT, 'w', encoding='utf-8').write('\n'.join(out))
    print('ok', OUT, 'swsh', sum(1 for r in swsh_rows if r[2] or r[3] or r[4]), 'la', sum(1 for r in la_rows if r[2]),
          'sv', sum(1 for r in sv_rows if r[2] or r[3] or r[4]), 'za', sum(1 for r in za_rows if r[2]), 'laforms', len(fst_ids))


main()
