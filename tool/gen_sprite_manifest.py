#!/usr/bin/env python3
"""Genera el índice de iconos (sprites) que la app descarga bajo demanda.

Uso:
    python3 tool/gen_sprite_manifest.py <clon de PKHeX> <clon de smogon/sprites> \
        apps/pkarktools/lib/data/sprites/sprite_manifest.g.dart

Cada clon debe estar en el commit fijado y con los PNG de sus carpetas
descargados (basta un clon parcial con «sparse-checkout» de esas carpetas):

* PKHeX (kwsch/PKHeX): objetos, Balls, cintas y tipos, y la tabla de objetos
  de Gen 2/3 → Gen 4 de `ItemConverter`. También aporta los nombres de especie
  en inglés (`text_Species_en.txt`) para el mapeo especie → archivo.
* smogon/sprites: iconos de Pokémon de HOME (`src/minisprites/pokemon/home`),
  que cubren las especies 1–1025 y sus formas. Las formas especiales que esa
  carpeta no tiene (Gigamax, Megas de Leyendas Z-A, tipos de Silvally,
  Terapagos) y las versiones variocolor de las formas especiales salen de
  otras carpetas del MISMO commit, en grupos aparte que solo listan los
  archivos usados (ver `EXTRA_SETS`):
  - `src/_uncategorized/canonical/home/small[-shiny]`: volcado de los iconos
    de caja de HOME (Gigamax, Silvally, variocolor de las Megas de Gen 6/7).
  - `src/champions`: iconos de Pokémon Champions, mismo estilo que HOME
    (Megas de Z-A con su variocolor «-s»).
  - `src/previews/gen9`: renders de HOME (lo que no está en las anteriores:
    Gigamax de la Isla de la Armadura / Nieves de la Corona, algunas Megas de
    Z-A, Terapagos). El índice de formas por número
  de PKHeX sale de los volcados de HOME del mismo repositorio
  (`src/_uncategorized/canonical/home/small*`, «0052-002-Meowth-Galar») y de
  la tabla explícita `HAND_FORMS` para lo que no recogen (Gen 9, Hisui…).

Los iconos NO se empaquetan: la app los descarga de
https://raw.githubusercontent.com/<repo>/<commit>/... y los guarda en su
directorio de caché. Este script lista los nombres de archivo y sus tamaños
(para verificar las descargas y no pedir iconos que no existen) y mide el
contenido no transparente de cada grupo para escalarlo (ver `SpriteLayout`).
Los sprites son © Nintendo/Game Freak/The Pokémon Company.
"""
import os
import re
import subprocess
import sys
import unicodedata

from PIL import Image

PKHEX, SMOGON, OUT = sys.argv[1], sys.argv[2], sys.argv[3]

# Grupo → (repositorio de GitHub, clon local, carpeta dentro del repositorio).
SETS = {
    'pokemon': ('smogon/sprites', SMOGON, 'src/minisprites/pokemon/home'),
    'item': ('kwsch/PKHeX', PKHEX, 'PKHeX.Drawing.PokeSprite/Resources/img/Big Items'),
    'ball': ('kwsch/PKHeX', PKHEX, 'PKHeX.Drawing.PokeSprite/Resources/img/ball'),
    'ribbon': ('kwsch/PKHeX', PKHEX, 'PKHeX.Drawing.Misc/Resources/img/ribbons'),
    'type': ('kwsch/PKHeX', PKHEX, 'PKHeX.Drawing.Misc/Resources/img/types/square'),
}

# Grupos de formas especiales: carpetas del mismo repositorio y commit de las
# que solo se listan los archivos que usan las tablas de abajo.
EXTRA_SETS = {
    'pokemon_small': 'src/_uncategorized/canonical/home/small',
    'pokemon_small_shiny': 'src/_uncategorized/canonical/home/small-shiny',
    'pokemon_champions': 'src/champions',
    'pokemon_preview': 'src/previews/gen9',
}

# Megas de Leyendas Z-A (y Mega Dimensión): (especie, forma de PKHeX) → forma
# en smogon (sin la «-o»). Se busca en champions y, si no, en previews/gen9;
# el variocolor es el mismo nombre con «-s».
ZA_MEGAS = {
    (26, 2): 'mega_x', (26, 3): 'mega_y', (36, 1): 'mega', (71, 1): 'mega', (121, 1): 'mega',
    (149, 1): 'mega', (154, 1): 'mega', (160, 1): 'mega', (227, 1): 'mega', (358, 1): 'mega',
    (359, 2): 'mega_z', (398, 1): 'mega', (445, 2): 'mega_z', (448, 2): 'mega_z', (478, 1): 'mega',
    (485, 1): 'mega', (491, 1): 'mega', (500, 1): 'mega', (530, 1): 'mega', (545, 1): 'mega',
    (560, 1): 'mega', (604, 1): 'mega', (609, 1): 'mega', (623, 1): 'mega', (652, 1): 'mega',
    (655, 1): 'mega', (658, 3): 'mega', (668, 1): 'mega', (670, 6): 'mega', (678, 2): 'm_mega',
    (678, 3): 'f_mega', (687, 1): 'mega', (689, 1): 'mega', (691, 1): 'mega', (701, 1): 'mega',
    (718, 5): 'mega', (740, 1): 'mega', (768, 1): 'mega', (780, 1): 'mega', (801, 2): 'mega',
    (801, 3): 'original_mega', (807, 1): 'mega', (870, 1): 'mega', (952, 1): 'mega', (970, 1): 'mega',
    (978, 3): 'curly_mega', (978, 4): 'droopy_mega', (978, 5): 'stretchy_mega', (998, 1): 'mega',
}

# Otras formas sin icono en la carpeta principal: (especie, forma) → (grupo, archivo).
OTHER_FORMS = {
    **{(773, f): ('pokemon_small', f'0773-{f:03d}-Silvally-{t}') for f, t in enumerate(
        ['', 'Fighting', 'Flying', 'Poison', 'Ground', 'Rock', 'Bug', 'Ghost', 'Steel', 'Fire', 'Water',
         'Grass', 'Electric', 'Psychic', 'Ice', 'Dragon', 'Dark', 'Fairy']) if f},
    (1024, 1): ('pokemon_preview', 'sterapagos-oterastal'),
    (1024, 2): ('pokemon_preview', 'sterapagos-ostellar'),
}

# Gigamax: especie (o especie y forma del ejemplar) → nombre en el volcado de HOME
# («NNNN-000-Especie-Gmax») o, si no está, en previews/gen9 («<base>[-oforma]-g»).
# Toxtricity y Urshifu tienen una Gigamax por forma.
GMAX_SPECIES = [3, 6, 9, 12, 25, 52, 68, 94, 99, 131, 133, 143, 569, 809, 812, 815, 818, 823, 826, 834,
                839, 841, 842, 844, 851, 858, 861, 869, 879, 884]
GMAX_FORMS = {(849, 0): None, (849, 1): 'low_key', (892, 0): None, (892, 1): 'rapid_strike'}

# Percentil del «tamaño necesario» de cada sprite que se toma como referencia
# del grupo: los pocos que lo superan se reducen solo lo justo al dibujarlos.
PERCENTILE = 0.92

# Formas que los volcados de HOME no recogen (especie → {forma de PKHeX: forma
# en smogon}). La forma de smogon va sin la «-o» inicial; None = icono base.
HAND_FORMS = {
    # Galar que faltan en el volcado
    80: {2: 'galar'}, 144: {1: 'galar'}, 145: {1: 'galar'}, 146: {1: 'galar'}, 199: {1: 'galar'},
    25: {9: 'world'},
    # Hisui
    58: {1: 'hisui'}, 59: {1: 'hisui'}, 100: {1: 'hisui'}, 101: {1: 'hisui'}, 157: {1: 'hisui'},
    211: {1: 'hisui'}, 215: {1: 'hisui'}, 503: {1: 'hisui'}, 549: {1: 'hisui'}, 570: {1: 'hisui'},
    571: {1: 'hisui'}, 628: {1: 'hisui'}, 705: {1: 'hisui'}, 706: {1: 'hisui'}, 713: {1: 'hisui'},
    724: {1: 'hisui'}, 483: {1: 'origin'}, 484: {1: 'origin'}, 550: {2: 'white_striped'},
    # Paldea
    128: {1: 'paldea_combat', 2: 'paldea_blaze', 3: 'paldea_aqua'}, 194: {1: 'paldea'},
    # Kalos / Alola / Galar sin entrada en el volcado
    670: {5: 'eternal'},
    718: {2: '10', 3: None},
    774: {**{f: 'meteor' for f in range(7)}, 7: None, 8: 'orange', 9: 'yellow', 10: 'green', 11: 'blue', 12: 'indigo', 13: 'violet'},
    854: {1: 'antique'}, 855: {1: 'antique'},
    869: {1: 'ruby_cream', 2: 'matcha_cream', 3: 'mint_cream', 4: 'lemon_cream', 5: 'salted_cream', 6: 'ruby_swirl', 7: 'caramel_swirl', 8: 'rainbow_swirl'},
    892: {1: 'rapid_strike'}, 893: {1: 'dada'}, 898: {1: 'ice', 2: 'shadow'},
    # Leyendas: Arceus y Gen 9
    901: {1: 'bloodmoon'}, 902: {1: 'f'}, 905: {1: 'therian'},
    916: {1: 'f'}, 925: {1: 'four'}, 931: {1: 'blue', 2: 'yellow', 3: 'white'}, 964: {1: 'hero'},
    978: {1: 'droopy', 2: 'stretchy'}, 982: {1: 'three_segment'}, 999: {1: 'roaming'},
    1012: {1: 'artisan'}, 1013: {1: 'masterpiece'},
    1017: {1: 'wellspring', 2: 'hearthflame', 3: 'cornerstone', 4: None, 5: 'wellspring', 6: 'hearthflame', 7: 'cornerstone'},
}


def norm(s):
    """Nombre «aplanado» de smogon: Ho-Oh → ho_oh, Mr. Mime → mr_mime, Flabébé → flabebe."""
    s = s.replace('♀', '-f').replace('♂', '-m')
    s = unicodedata.normalize('NFKD', s).encode('ascii', 'ignore').decode().lower()
    s = re.sub(r"['’.]", '', s)
    return re.sub(r'[^a-z0-9]+', '_', s).strip('_')


def git(repo, *args):
    return subprocess.check_output(['git', '-C', repo, *args], text=True).strip()


def conv_table(name):
    src = open(os.path.join(PKHEX, 'PKHeX.Core', 'PKM', 'Util', 'Conversion', 'ItemConverter.cs'), encoding='utf-8').read()
    i = src.index(f'ReadOnlySpan<ushort> {name} =>')
    body = src[src.index('[', i) + 1:src.index('];', i)]
    body = re.sub(r'//[^\n]*', '', body)
    vals = [v.strip() for v in body.replace('\n', ',').split(',') if v.strip()]
    return [65535 if v == 'NaN' else (int(v, 16) if v.lower().startswith('0x') else int(v, 10)) for v in vals]


def need(path):
    """Lado del hueco cuadrado que necesita el contenido no transparente del
    sprite si se dibuja la imagen entera centrada (en píxeles del sprite)."""
    im = Image.open(path).convert('RGBA')
    w, h = im.size
    box = im.getchannel('A').point(lambda a: 255 if a >= 24 else 0).getbbox()
    if box is None:
        return 0
    l, t, r, b = box
    return max(2 * max(w / 2 - l, r - w / 2), 2 * max(h / 2 - t, b - h / 2))


def pokemon_tables(files):
    species = open(os.path.join(PKHEX, 'PKHeX.Core/Resources/text/other/en/text_Species_en.txt'), encoding='utf-8-sig').read().splitlines()
    base = [''] + [f's{norm(species[i])}' for i in range(1, 1026)]
    for i in range(1, 1026):
        assert base[i] in files, (i, base[i])
    forms = {}
    female = set()
    # Volcados de HOME: «NNNN-FFF-Especie[-Forma].png».
    dumps = []
    for d in ('small', 'small-cosmetic'):
        dumps += git(SMOGON, 'ls-tree', '--name-only', 'HEAD', f'src/_uncategorized/canonical/home/{d}/').splitlines()
    for path in dumps:
        m = re.match(r'(\d{4})-(\d{3})-([^-]+)(?:-(.+))?\.png$', os.path.basename(path))
        if not m:
            continue
        sp, f, suffix = int(m[1]), int(m[2]), m[4]
        if sp > 1025:
            continue
        if suffix is None:
            if f > 0:
                forms[(sp, f)] = base[sp]
            continue
        if suffix == 'Female':
            if f'{base[sp]}-f' in files:
                female.add(sp)
            continue
        if '~Female' in suffix:
            continue
        s = re.sub(r'__[0-9a-fA-F]{4}', '', suffix).replace('~', '_')
        name = f'{base[sp]}-o{norm(s)}'
        if name in files:
            forms[(sp, f)] = name
    for sp, table in HAND_FORMS.items():
        for f, s in table.items():
            name = base[sp] if s is None else f'{base[sp]}-o{s}'
            assert name in files, (sp, f, name)
            forms[(sp, f)] = name
    for sp in range(1, 1026):
        if f'{base[sp]}-f' in files:
            female.add(sp)
    return base, forms, female


def special_tables(base, forms, files):
    """Tablas de formas especiales y variocolor → (grupo, archivo), y los
    archivos que usan de cada grupo extra."""
    def ls(d):
        return {os.path.basename(p)[:-4] for p in git(SMOGON, 'ls-tree', '--name-only', 'HEAD', d + '/').splitlines() if p.endswith('.png')}
    avail = {g: ls(d) for g, d in EXTRA_SETS.items()}
    dump_by_form = {}
    for n in avail['pokemon_small']:
        m = re.match(r'(\d{4})-(\d{3})-', n)
        if m:
            dump_by_form.setdefault((int(m[1]), int(m[2])), []).append(n)

    def pick(name, groups=('pokemon_champions', 'pokemon_preview')):
        for g in groups:
            if name in avail[g]:
                return (g, name)
        return None

    extra, shiny, gmax, gmax_shiny = {}, {}, {}, {}
    for (sp, f), suf in ZA_MEGAS.items():
        n = pick(f'{base[sp]}-o{suf}')
        assert n, (sp, f, suf)
        extra[(sp, f)] = n
        s = (n[0], n[1] + '-s')
        assert s[1] in avail[s[0]], s
        shiny[(sp, f)] = s
    for k, v in OTHER_FORMS.items():
        assert v[1] in avail[v[0]], v
        extra[k] = v
    # Variocolor de las Megas, Primigenias y Ultra del set principal: el volcado de HOME.
    for (sp, f), name in forms.items():
        if re.search(r'-o(mega|primal|ultra)', name):
            hits = [n for n in avail['pokemon_small_shiny'] if n.startswith(f'{sp:04d}-{f:03d}-')]
            assert len(hits) == 1, (sp, f, hits)
            shiny[(sp, f)] = ('pokemon_small_shiny', hits[0])

    def gmax_ref(sp, form_suffix):
        hits = [n for n in avail['pokemon_small'] if n.startswith(f'{sp:04d}-000-') and n.endswith('-Gmax')]
        if form_suffix is None and len(hits) == 1:
            n = hits[0]
            assert n in avail['pokemon_small_shiny'], n
            return ('pokemon_small', n), ('pokemon_small_shiny', n)
        n = base[sp] + (f'-o{form_suffix}' if form_suffix else '') + '-g'
        assert n in avail['pokemon_preview'] and n + '-s' in avail['pokemon_preview'], n
        return ('pokemon_preview', n), ('pokemon_preview', n + '-s')
    for sp in GMAX_SPECIES:
        gmax[str(sp)], gmax_shiny[str(sp)] = gmax_ref(sp, None)
    for (sp, f), suf in GMAX_FORMS.items():
        # Urshifu Brusco (0) no está en el volcado: previews/gen9 para las dos.
        key = f'{sp}-{f}'
        if sp == 892:
            gmax[key], gmax_shiny[key] = gmax_ref(sp, suf or '')
        else:
            gmax[key], gmax_shiny[key] = gmax_ref(sp, suf)
    used = {g: set() for g in EXTRA_SETS}
    for t in (extra, shiny, gmax, gmax_shiny):
        for g, n in t.values():
            used[g].add(n)
    return extra, shiny, gmax, gmax_shiny, used


def main():
    commits = {}
    files = {}
    metrics = {}
    def measure(group, clone, d, names):
        files[group] = [(f[:-4], os.path.getsize(os.path.join(clone, d, f))) for f in names]
        needs = {f[:-4]: need(os.path.join(clone, d, f)) for f in names}
        vals = sorted(v for v in needs.values() if v > 0)
        ref = vals[min(len(vals) - 1, int(len(vals) * PERCENTILE))]
        over = {n: v for n, v in needs.items() if v > ref}
        metrics[group] = (ref, over)

    for group, (repo, clone, d) in SETS.items():
        commits[repo] = git(clone, 'rev-parse', 'HEAD')
        measure(group, clone, d, sorted(f for f in os.listdir(os.path.join(clone, d)) if f.endswith('.png')))
    base, forms, female = pokemon_tables({n for n, _ in files['pokemon']})
    extra, shiny, gmax, gmax_shiny, used = special_tables(base, forms, {n for n, _ in files['pokemon']})
    for group, d in EXTRA_SETS.items():
        SETS[group] = ('smogon/sprites', SMOGON, d)
        measure(group, SMOGON, d, sorted(f'{n}.png' for n in used[group]))

    out = [
        '// GENERADO por tool/gen_sprite_manifest.py. No editar a mano.',
        '// Índice de los iconos que se descargan bajo demanda (Pokémon: iconos de HOME del',
        '// repositorio smogon/sprites; objetos, Balls, cintas y tipos: recursos de PKHeX).',
        '// Los sprites son © Nintendo/Game Freak/The Pokémon Company y no se distribuyen con la app.',
        '// ignore_for_file: lines_longer_than_80_chars',
        '',
        '/// Commit fijo de cada repositorio de origen.',
        'const Map<String, String> kSpriteCommits = {',
    ]
    for repo, c in commits.items():
        out.append(f"  '{repo}': '{c}',")
    out += ['};', '', '/// Repositorio y carpeta de cada grupo.', 'const Map<String, (String, String)> kSpriteSources = {']
    for group, (repo, _, d) in SETS.items():
        out.append(f"  '{group}': ('{repo}', '{d}'),")
    out += ['};', '', '/// Archivos de cada grupo (sin «.png») y su tamaño en bytes, «nombre:tamaño» separados por comas.',
            'const Map<String, String> kSpriteFiles = {']
    total = 0
    for group, entries in files.items():
        total += sum(s for _, s in entries)
        out.append(f"  '{group}': '{','.join(f'{n}:{s}' for n, s in entries)}',")
    out += ['};', '', f'const int kSpriteTotalBytes = {total};', '']
    out += ['/// Recuadro de contenido de referencia de cada grupo, en píxeles del sprite:',
            f'/// percentil {int(PERCENTILE * 100)} del lado de hueco que necesita el contenido no transparente',
            '/// de cada sprite dibujado entero y centrado.',
            'const Map<String, double> kSpriteContentRef = {']
    for group, (ref, _) in metrics.items():
        out.append(f"  '{group}': {float(ref)},")
    out += ['};', '', '/// Sprites que superan la referencia de su grupo y el lado que necesitan.',
            'const Map<String, String> kSpriteOversize = {']
    for group, (_, over) in metrics.items():
        out.append(f"  '{group}': '{','.join(f'{n}:{float(v)}' for n, v in sorted(over.items()))}',")
    out += ['};', '']
    out.append('/// Icono de HOME de cada especie (índice = número de Pokédex nacional; 0 vacío).')
    out.append('const List<String> kPokemonIconBase = [' + ', '.join(f"'{b}'" for b in base) + '];')
    out.append('')
    out.append('/// Icono de cada forma («especie-forma» de PKHeX → archivo). Las formas que no')
    out.append('/// están usan el icono base de la especie.')
    out.append('const Map<String, String> kPokemonIconForms = {')
    for (sp, f), name in sorted(forms.items()):
        out.append(f"  '{sp}-{f}': '{name}',")
    out.append('};')
    out.append('')
    def rec_map(doc, name, table):
        out.extend(doc)
        out.append(f'const Map<String, (String, String)> {name} = {{')
        for k, (g, n) in sorted(table.items(), key=lambda e: tuple(int(x) for x in str(e[0]).replace('-', ' ').split()) if not isinstance(e[0], tuple) else e[0]):
            key = k if isinstance(k, str) else f'{k[0]}-{k[1]}'
            out.append(f"  '{key}': ('{g}', '{n}'),")
        out.extend(['};', ''])

    rec_map(['/// Formas sin icono en la carpeta principal («especie-forma» → (grupo, archivo)):',
             '/// Megas de Leyendas Z-A, tipos de Silvally, Terapagos.'], 'kPokemonIconFormsExtra', extra)
    rec_map(['/// Icono variocolor de las formas especiales (Mega, Primigenia, Ultra) por «especie-forma».'],
            'kPokemonIconShinyForms', shiny)
    rec_map(['/// Icono Gigamax por «especie» o, si cambia con la forma, «especie-forma» del ejemplar.'],
            'kPokemonIconGmax', gmax)
    rec_map(['/// Icono Gigamax variocolor (mismas claves que [kPokemonIconGmax]).'], 'kPokemonIconGmaxShiny', gmax_shiny)
    out.append('/// Especies con icono propio de hembra («<base>-f»).')
    out.append('const Set<int> kPokemonIconFemale = {' + ', '.join(map(str, sorted(female))) + '};')
    out.append('')
    out.append('/// Icono de huevo.')
    out.append("const String kPokemonIconEgg = 'xegg';")
    out.append('')
    out.append('/// PKHeX `ItemConverter.Item3to4`: objeto de Gen 3 → id moderno (65535 = no existe).')
    out.append('const List<int> kItem3to4 = [' + ', '.join(map(str, conv_table('Item3to4'))) + '];')
    out.append('')
    out.append('/// PKHeX `ItemConverter.Item2to4`: objeto de Gen 2 → id moderno (65535 = no existe).')
    out.append('const List<int> kItem2to4 = [' + ', '.join(map(str, conv_table('Item2to4'))) + '];')
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    open(OUT, 'w', encoding='utf-8').write('\n'.join(out) + '\n')
    mapped = set(forms.values()) | set(base) | {f'{base[s]}-f' for s in female} | {'xegg'}
    unmapped = sorted(n for n, _ in files['pokemon'] if n not in mapped)
    print(commits, total, {g: m[0] for g, m in metrics.items()}, {g: len(m[1]) for g, m in metrics.items()})
    print('formas extra', len(extra), 'variocolor', len(shiny), 'gigamax', len(gmax), {g: len(v) for g, v in used.items()})
    print('formas mapeadas', len(forms), 'hembras', len(female), 'archivos sin mapear', len(unmapped), unmapped)


main()
