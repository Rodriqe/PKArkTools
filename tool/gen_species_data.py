#!/usr/bin/env python3
"""Genera packages/pkcore/lib/src/data/generated/species_data.dart a partir de los CSV de PokeAPI.

Uso: python3 tool/gen_species_data.py <dir_csv_pokeapi> <salida.dart>
CSV requeridos: pokemon_species.csv, pokemon_species_names.csv, pokemon_types.csv, experience.csv
Fuente: https://github.com/PokeAPI/pokeapi (data/v2/csv).
"""
import csv, sys, os

src, out = sys.argv[1], sys.argv[2]
def rows(name):
    with open(os.path.join(src, name), newline='', encoding='utf-8') as f:
        return list(csv.DictReader(f))

species = rows('pokemon_species.csv')
maxid = max(int(r['id']) for r in species)
growth = [0] * (maxid + 1)
for r in species:
    growth[int(r['id'])] = int(r['growth_rate_id'])

names = {7: [''] * (maxid + 1), 9: [''] * (maxid + 1), 1: [''] * (maxid + 1)}
for r in rows('pokemon_species_names.csv'):
    lang = int(r['local_language_id']); sid = int(r['pokemon_species_id'])
    if lang in names and sid <= maxid:
        names[lang][sid] = r['name']
for i in range(1, maxid + 1):
    if not names[7][i]:
        names[7][i] = names[9][i]

types = [0] * (maxid + 1)
for r in rows('pokemon_types.csv'):
    pid = int(r['pokemon_id'])
    if pid > maxid: continue
    slot = int(r['slot']); t = int(r['type_id'])
    types[pid] |= t << (0 if slot == 1 else 5)

# experience tables: growth_rate_id -> level -> exp
exp = {}
for r in rows('experience.csv'):
    exp.setdefault(int(r['growth_rate_id']), {})[int(r['level'])] = int(r['experience'])

def dstr(s):
    return "'" + s.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$') + "'"

with open(out, 'w', encoding='utf-8') as f:
    f.write('// GENERADO por tool/gen_species_data.py — no editar a mano.\n')
    f.write('// Datos: PokeAPI (https://github.com/PokeAPI/pokeapi). Nombres de especies © Nintendo/Game Freak/Creatures.\n\n')
    f.write(f'const int kMaxSpeciesId = {maxid};\n\n')
    for lang, var in ((9, 'kSpeciesNamesEn'), (7, 'kSpeciesNamesEs'), (1, 'kSpeciesNamesJa')):
        f.write(f'const List<String> {var} = <String>[\n')
        f.write(',\n'.join('  ' + dstr(n) for n in names[lang]))
        f.write(',\n];\n\n')
    f.write('/// Tasa de crecimiento por especie (id de PokeAPI: 1 lento, 2 medio, 3 rápido, 4 medio-lento, 5 errático, 6 fluctuante).\n')
    f.write('const List<int> kSpeciesGrowth = <int>[' + ','.join(map(str, growth)) + '];\n\n')
    f.write('/// Tipos empaquetados: tipo1 | (tipo2 << 5). Ids de tipo de PokeAPI (1 normal … 18 hada).\n')
    f.write('const List<int> kSpeciesTypes = <int>[' + ','.join(map(str, types)) + '];\n\n')
    f.write('/// Experiencia mínima por nivel (índice = nivel, 0 sin uso) para cada tasa de crecimiento.\n')
    f.write('const Map<int, List<int>> kExperienceTables = <int, List<int>>{\n')
    for g in sorted(exp):
        lst = [0] + [exp[g][l] for l in range(1, 101)]
        f.write(f'  {g}: <int>[' + ','.join(map(str, lst)) + '],\n')
    f.write('};\n')
print('ok', maxid)
