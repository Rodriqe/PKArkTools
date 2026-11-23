#!/usr/bin/env python3
"""Genera los nombres de forma de pkcore y la tabla de verificación de formas.

Uso (lo llama tool/gen_form_data.sh tras ejecutar `PkhexOracle forms <dir>`):
    python3 tool/gen_form_data.py <dir del oráculo> <raíz del repo>

Entradas (de tools/pkhex_oracle, comando `forms`, PKHeX.Core GPL-3.0):
  * form_names.json  nombres de forma por contexto y especie (FormConverter), en/es.
  * form_presence.csv  (juego, especie) → número de formas y máscara de formas
                     presentes en el juego (`IsPresentInGame`).
  * form_oracle.csv  (juego, especie, forma) → tipos, stats base, habilidades,
                     género y preevolución, para cada combinación presente en
                     cada juego de Gen 3–9.

Salidas:
  * packages/pkcore/lib/src/data/generated/form_names.dart
  * packages/pkcore/test/data/form_oracle.csv.gz  (la usa form_data_pkhex_test.dart)
"""
import gzip
import json
import os
import sys

SRC = sys.argv[1]
ROOT = sys.argv[2]


def dart_str(s):
    return "'" + s.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$') + "'"


def main():
    names = json.load(open(os.path.join(SRC, 'form_names.json'), encoding='utf-8'))
    pool, index = [], {}

    def intern(s):
        if s not in index:
            index[s] = len(pool)
            pool.append(s)
        return index[s]

    # Listas idénticas entre contextos se comparten (por id de lista).
    lists, list_index = [], {}

    def intern_list(values):
        key = tuple(intern(v) for v in values)
        if key not in list_index:
            list_index[key] = len(lists)
            lists.append(key)
        return list_index[key]

    contexts = {}
    for ctx in sorted(names):
        contexts[ctx] = {int(sp): (intern_list(en), intern_list(es)) for sp, (en, es) in names[ctx].items()}

    out = ['// GENERADO por tool/gen_form_data.py — no editar a mano.\n',
           '// Fuente: PKHeX.Core FormConverter (GPL-3.0). Nombres © Nintendo/Game Freak/Creatures.\n',
           '// ignore_for_file: lines_longer_than_80_chars\n\n',
           '/// Cadenas de nombres de forma.\n',
           'const List<String> kFormNamePool = <String>[\n']
    out += [f'  {dart_str(s)},\n' for s in pool]
    out.append('];\n\n/// Listas de nombres de forma (índices en [kFormNamePool]).\n')
    out.append('const List<List<int>> kFormNameLists = <List<int>>[\n')
    out += [f'  [{", ".join(map(str, l))}],\n' for l in lists]
    out.append('];\n\n')
    out.append('/// Contexto (EntityContext de PKHeX) → especie → (lista en, lista es) en [kFormNameLists].\n')
    out.append('const Map<String, Map<int, (int, int)>> kFormNames = {\n')
    for ctx, m in contexts.items():
        body = ', '.join(f'{sp}: ({a}, {b})' for sp, (a, b) in sorted(m.items()))
        out.append(f"  '{ctx}': {{{body}}},\n")
    out.append('};\n\n')
    # Presencia: solo las especies cuya máscara no es «todas sus formas» (0 = la
    # especie no está en el juego aunque tenga datos personales).
    out.append('/// Juego (GameDataTable.key) → especie → máscara de formas presentes, cuando no\n')
    out.append('/// son todas las de `formCount` (0: la especie no está en el juego).\n')
    out.append('const Map<String, Map<int, int>> kFormPresence = {\n')
    pres, maxsp = {}, {}
    for line in open(os.path.join(SRC, 'form_presence.csv'), encoding='utf-8'):
        if not line.strip() or line.startswith('#'):
            continue
        key, sp, count, mask = line.strip().split(',')
        maxsp[key] = max(maxsp.get(key, 0), int(sp))
        if int(mask) != (1 << int(count)) - 1:
            pres.setdefault(key, {})[int(sp)] = int(mask)
    for key, m in pres.items():
        body = ', '.join(f'{sp}: {mask}' for sp, mask in sorted(m.items()))
        out.append(f"  '{key}': {{{body}}},\n")
    out.append('};\n\n')
    out.append('/// Juego (GameDataTable.key) → última especie de la Pokédex Nacional en sus datos\n')
    out.append('/// personales (`MaxSpeciesID`); las entradas siguientes son formas.\n')
    out.append('const Map<String, int> kGameMaxSpecies = {\n')
    out += [f"  '{k}': {v},\n" for k, v in maxsp.items()]
    out.append('};\n')
    dst = os.path.join(ROOT, 'packages', 'pkcore', 'lib', 'src', 'data', 'generated', 'form_names.dart')
    with open(dst, 'w', encoding='utf-8') as f:
        f.write(''.join(out))

    csv = open(os.path.join(SRC, 'form_oracle.csv'), 'rb').read()
    test = os.path.join(ROOT, 'packages', 'pkcore', 'test', 'data', 'form_oracle.csv.gz')
    os.makedirs(os.path.dirname(test), exist_ok=True)
    with open(test, 'wb') as f:
        # mtime=0: el .gz es reproducible (mismo contenido → mismos bytes).
        with gzip.GzipFile(fileobj=f, mode='wb', mtime=0, filename='') as gz:
            gz.write(csv)
    rows = sum(1 for line in csv.decode().splitlines() if line and not line.startswith('#'))
    print(f'form_names.dart: {len(pool)} cadenas, {len(lists)} listas; form_oracle.csv.gz: {rows} filas')


main()
