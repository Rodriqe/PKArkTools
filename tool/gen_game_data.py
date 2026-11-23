#!/usr/bin/env python3
"""Genera las tablas de datos de juego de pkcore a partir de PKHeX.Core (GPL-3.0).

Uso:
    python3 tool/gen_game_data.py <ruta a PKHeX.Core> packages/pkcore/lib/src/data/generated

Produce:
  * game_text.dart      nombres (es/en) de movimientos, objetos (Gen 1, 2, 3 y 4+),
                        habilidades, naturalezas y tipos.
  * game_binaries.dart  tablas binarias en base64: datos personales (stats base,
                        tipos, habilidades, género, formas, MT) por juego, learnsets
                        por nivel y movimientos huevo (formato BinLinker de PKHeX),
                        PP y tipo de movimientos por contexto, movimientos
                        inexistentes por contexto y listas de objetos por bolsillo.

El texto y los binarios provienen de `PKHeX.Core/Resources` y de tablas en el
código C# de PKHeX; los nombres son © Nintendo/Game Freak/Creatures.
"""
import base64
import os
import re
import struct
import sys

PK = sys.argv[1]
OUT = sys.argv[2]
RES = os.path.join(PK, 'Resources')


def read_lines(path):
    raw = open(path, 'rb').read()
    if raw[:2] in (b'\xff\xfe', b'\xfe\xff'):
        s = raw.decode('utf-16')
    else:
        s = raw.decode('utf-8-sig')
    lines = [line.rstrip('\r').replace('\ufeff', '') for line in s.split('\n')]
    while lines and lines[-1] == '':
        lines.pop()
    return lines


def text(kind, lang):
    return read_lines(os.path.join(RES, 'text', 'other', lang, f'text_{kind}_{lang}.txt'))


def items_text(sub, name, lang):
    base = os.path.join(RES, 'text', 'items')
    path = os.path.join(base, sub, f'text_{name}_{lang}.txt') if sub else os.path.join(base, f'text_{name}_{lang}.txt')
    return read_lines(path)


def dart_str(s):
    return "'" + s.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$') + "'"


def dart_list(name, values):
    body = ',\n'.join('  ' + dart_str(v) for v in values)
    return f'const List<String> {name} = <String>[\n{body},\n];\n'


# ----------------------------------------------------------------- C# arrays

NUM = re.compile(r'^(0x[0-9A-Fa-f]+|\d+)$')


def strip_comments(src):
    src = re.sub(r'/\*.*?\*/', '', src, flags=re.S)
    return re.sub(r'//[^\n]*', '', src)


def parse_arrays(path):
    """Devuelve {nombre: expresión} para `ReadOnlySpan<T> X => [...]` y `T[] X = [...]`."""
    src = strip_comments(open(path, encoding='utf-8').read())
    out = {}
    for m in re.finditer(r'(?:ReadOnlySpan<\w+>|\w+\[\])\s+(\w+)\s*(?:=>|=)\s*', src):
        name = m.group(1)
        rest = src[m.end():]
        if rest.startswith('['):
            depth, i = 0, 0
            while True:
                c = rest[i]
                if c == '[':
                    depth += 1
                elif c == ']':
                    depth -= 1
                    if depth == 0:
                        break
                i += 1
            out[name] = rest[:i + 1]
        else:
            out[name] = rest[:rest.index(';')]
    return out


class Scope:
    def __init__(self, files, consts=None):
        self.names = {}
        for f in reversed(files):  # el primero tiene prioridad
            self.names.update(parse_arrays(f))
        self.consts = consts or {}

    def ev(self, expr):
        expr = expr.strip()
        if expr.startswith('[') and expr.endswith(']'):
            inner = expr[1:-1]
            result = []
            for tok in split_top(inner):
                tok = tok.strip()
                if not tok:
                    continue
                tok = re.sub(r'^\((?:ushort|byte|int)\)\s*', '', tok)
                em = re.match(r'^(Move|Species|Ability)\.(\w+)$', tok)
                if tok.startswith('..'):
                    result += self.ev(tok[2:])
                elif em:
                    result.append(enum_value(em.group(1), em.group(2)))
                elif NUM.match(tok):
                    result.append(int(tok, 16) if tok.lower().startswith("0x") else int(tok, 10))
                else:
                    raise ValueError(f'token {tok!r}')
            return result
        m = re.match(r'^(\w+)\.Slice\((\w+),\s*(\w+)\)$', expr)
        if m:
            base = self.ev(m.group(1))
            a, b = self.num(m.group(2)), self.num(m.group(3))
            return base[a:a + b]
        m = re.match(r'^(\w+)\.AsSpan\(\.\.\^(\w+)\)$', expr)
        if m:
            return self.ev(m.group(1))[:-self.num(m.group(2))]
        m = re.match(r'^(\w+)\[(\^?\w*)\.\.(\^?\w*)\]$', expr)
        if m:
            base = self.ev(m.group(1))
            a = self.idx(m.group(2), len(base), 0)
            b = self.idx(m.group(3), len(base), len(base))
            return base[a:b]
        if re.match(r'^\w+$', expr):
            return self.ev(self.names[expr])
        raise ValueError(f'expr {expr!r}')

    def num(self, s):
        return int(s, 0) if NUM.match(s) else self.consts[s]

    def idx(self, s, n, default):
        if s == '':
            return default
        if s.startswith('^'):
            return n - self.num(s[1:])
        return self.num(s)


_ENUMS = {}


def enum_value(enum, name):
    if enum not in _ENUMS:
        src = strip_comments(open(os.path.join(PK, 'Game', 'Enums', enum + '.cs'), encoding='utf-8').read())
        body = src[src.index('{') + 1:src.rindex('}')]
        values, cur = {}, -1
        for part in body.split(','):
            part = part.strip()
            if not part:
                continue
            if '=' in part:
                n, v = [x.strip() for x in part.split('=')]
                cur = int(v, 0)
            else:
                n = part
                cur += 1
            values[n] = cur
        _ENUMS[enum] = values
    return _ENUMS[enum][name]


def split_top(s):
    parts, depth, cur = [], 0, ''
    for c in s:
        if c in '[(':
            depth += 1
        elif c in '])':
            depth -= 1
        if c == ',' and depth == 0:
            parts.append(cur)
            cur = ''
        else:
            cur += c
    parts.append(cur)
    return parts


# ----------------------------------------------------------------- personal

# fmt: size, stats(hp,atk,def,spe,spa,spd), type1, type2, gender, growth,
#      abilities(offsets), abilityWidth, formCount, formIndex, tmOffset
FMT = {
    1: (0x1C, (1, 2, 3, 4, 5, 5), 6, 7, None, 0x13, (), 1, None, None, 0x14),
    2: (0x20, (1, 2, 3, 4, 5, 6), 7, 8, 0x0D, 0x16, (), 1, None, None, 0x18),
    3: (0x1C, (0, 1, 2, 3, 4, 5), 6, 7, 0x10, 0x13, (0x16, 0x17), 1, None, None, None),
    4: (0x2C, (0, 1, 2, 3, 4, 5), 6, 7, 0x10, 0x13, (0x16, 0x17), 1, 0x29, 0x2A, 0x1C),
    5: (None, (0, 1, 2, 3, 4, 5), 6, 7, 0x12, 0x15, (0x18, 0x19, 0x1A), 1, 0x20, 0x1C, 0x28),
    8: (None, (0, 1, 2, 3, 4, 5), 6, 7, 0x12, 0x15, (0x18, 0x1A, 0x1C), 2, 0x20, 0x1E, 0x28),
    9: (0x50, (0, 1, 2, 3, 4, 5), 6, 7, 0x0C, 0x0F, (0x12, 0x14, 0x16), 2, 0x1A, 0x18, 0x2C),
}

PI = os.path.join(PK, 'PersonalInfo', 'Info')
LS = os.path.join(PK, 'Legality', 'LearnSource', 'Sources')


def machine(file, name):
    return Scope([file]).ev(name)


def tm_lists():
    p4 = os.path.join(PI, 'PersonalInfo4.cs')
    sw = os.path.join(PI, 'PersonalInfo8SWSH.cs')
    swsh = machine(sw, 'MachineMovesTechnical') + [0] * 0  # TM00-TM99
    return {
        'dp': machine(p4, 'MachineMovesTechnical') + machine(p4, 'MachineMovesHiddenDPPt'),
        'pt': machine(p4, 'MachineMovesTechnical') + machine(p4, 'MachineMovesHiddenDPPt'),
        'hgss': machine(p4, 'MachineMovesTechnical') + machine(p4, 'MachineMovesHiddenHGSS'),
        'bw': machine(os.path.join(PI, 'PersonalInfo5BW.cs'), 'MachineMoves'),
        'b2w2': machine(os.path.join(PI, 'PersonalInfo5BW.cs'), 'MachineMoves'),
        'xy': machine(os.path.join(LS, 'LearnSource6XY.cs'), 'MachineMoves'),
        'ao': machine(os.path.join(LS, 'LearnSource6AO.cs'), 'MachineMoves'),
        'sm': machine(os.path.join(PI, 'PersonalInfo7.cs'), 'MachineMoves'),
        'uu': machine(os.path.join(PI, 'PersonalInfo7.cs'), 'MachineMoves'),
        'gg': machine(os.path.join(LS, 'LearnSource7GG.cs'), 'MachineMoves'),
        'swsh': swsh,
        'swsh_tr': machine(sw, 'MachineMovesRecord'),
        # Tutores de tipo (Juramentos, definitivos, Cometa Draco, Metaláser) y de la DLC (Isla de la Armadura).
        'swsh_type_tutor': [520, 519, 518, 338, 307, 308, 434, 796],
        'swsh_special_tutor': machine(sw, 'SpecialTutorMoves'),
        'bdsp': machine(os.path.join(PI, 'PersonalInfo8BDSP.cs'), 'MachineMoves'),
        'sv': machine(os.path.join(PI, 'PersonalInfo9SV.cs'), 'MachineMoves'),
        'za': machine(os.path.join(PI, 'PersonalInfo9ZA.cs'), 'MachineMoves'),
    }


GAMES = [
    # clave, archivo personal, formato, learnset, eggmoves
    ('rb', 'personal_rb', 1, 'lvlmove_rb', None),
    ('y', 'personal_y', 1, 'lvlmove_y', None),
    ('gs', 'personal_gs', 2, 'lvlmove_gs', 'eggmove_gs'),
    ('c', 'personal_c', 2, 'lvlmove_c', 'eggmove_c'),
    ('rs', 'personal_rs', 3, 'lvlmove_rs', 'eggmove_rs'),
    ('e', 'personal_e', 3, 'lvlmove_e', 'eggmove_rs'),
    ('fr', 'personal_fr', 3, 'lvlmove_fr', 'eggmove_rs'),
    ('dp', 'personal_dp', 4, 'lvlmove_dp', 'eggmove_dppt'),
    ('pt', 'personal_pt', 4, 'lvlmove_pt', 'eggmove_dppt'),
    ('hgss', 'personal_hgss', 4, 'lvlmove_hgss', 'eggmove_hgss'),
    ('bw', 'personal_bw', 5, 'lvlmove_bw', 'eggmove_bw'),
    ('b2w2', 'personal_b2w2', 5, 'lvlmove_b2w2', 'eggmove_bw'),
    ('xy', 'personal_xy', 5, 'lvlmove_xy', 'eggmove_xy'),
    ('ao', 'personal_ao', 5, 'lvlmove_ao', 'eggmove_ao'),
    ('sm', 'personal_sm', 5, 'lvlmove_sm', 'eggmove_sm'),
    ('uu', 'personal_uu', 5, 'lvlmove_uu', 'eggmove_uu'),
    ('gg', 'personal_gg', 5, 'lvlmove_gg', None),
    ('swsh', 'personal_swsh', 8, 'lvlmove_swsh', 'eggmove_swsh'),
    ('bdsp', 'personal_bdsp', 8, 'lvlmove_bdsp', 'eggmove_bdsp'),
    ('la', 'personal_la', 8, 'lvlmove_la', None),
    ('sv', 'personal_sv', 9, 'lvlmove_sv', 'eggmove_sv'),
    ('za', 'personal_za', 9, 'lvlmove_za', None),
]

SIZES = {'bw': 0x3C, 'b2w2': 0x4C, 'xy': 0x40, 'ao': 0x50, 'sm': 0x54, 'uu': 0x54, 'gg': 0x54,
         'swsh': 0xB0, 'bdsp': 0x44, 'la': 0xB0}

RECORD = 20  # hp atk def spe spa spd t1 t2 gender growth a1(2) a2(2) aH(2) formIdx(2) formCount pad


def repack_personal(key, fname, fmt, tms):
    raw = open(os.path.join(RES, 'byte', 'personal', fname), 'rb').read()
    size, stats, t1, t2, gender, growth, abil, aw, fcount, findex, tmofs = FMT[fmt]
    if size is None:
        size = SIZES[key]
    count = len(raw) // size
    tm_moves = tms.get(key, [])
    tm_bytes = (len(tm_moves) + 7) // 8
    if key == 'swsh':
        # Cada grupo de bits ocupa bytes completos: se rellena la lista de
        # movimientos hasta el múltiplo de 8 para que el índice de bit de cada
        # grupo (DT, tutores) siga alineado tras las 100 MT (13 bytes = 104 bits).
        def pad(moves):
            return moves + [0] * (-len(moves) % 8)
        tm_moves = pad(tm_moves)
        groups = [(0x3C, pad(tms['swsh_tr'])), (0x38, pad(tms['swsh_type_tutor'])),
                  (0xA8, pad(tms['swsh_special_tutor']))]
        tr_moves = [m for _, moves in groups for m in moves]
    else:
        groups = []
        tr_moves = []
    tr_bytes = None
    out = bytearray()
    for i in range(count):
        e = raw[i * size:(i + 1) * size]
        rec = bytearray(RECORD)
        for j, o in enumerate(stats):
            rec[j] = e[o]
        rec[6], rec[7] = e[t1], e[t2]
        rec[8] = e[gender] if gender is not None else 255
        rec[9] = e[growth]
        for j, o in enumerate(abil):
            v = e[o] if aw == 1 else e[o] | (e[o + 1] << 8)
            struct.pack_into('<H', rec, 10 + j * 2, v)
        if findex is not None:
            struct.pack_into('<H', rec, 16, e[findex] | (e[findex + 1] << 8))
            rec[18] = e[fcount]
        else:
            rec[18] = 1
        out += rec
        if tm_bytes:
            out += e[tmofs:tmofs + tm_bytes] if key not in ('swsh',) else e[0x28:0x28 + tm_bytes]
        for ofs, moves in groups:
            out += e[ofs:ofs + len(moves) // 8]
    extra = sum(len(moves) // 8 for _, moves in groups)
    return bytes(out), count, RECORD + tm_bytes + extra, tm_moves + tr_moves


# ----------------------------------------------------------------- moves

def move_tables():
    mi = os.path.join(PK, 'Moves')
    ctx = {}
    for suffix in ['1', '2', '3', '4', '5', '6', '7', '7b', '8', '8a', '8b', '9', '9a']:
        names = parse_arrays(os.path.join(mi, f'MoveInfo{suffix}.cs'))
        sc = Scope([os.path.join(mi, f'MoveInfo{suffix}.cs')])
        pp = sc.ev('PP') if 'PP' in names else None
        if pp is None:
            pp = ctx['8'][0]  # BDSP comparte los PP de Espada/Escudo
        typ = sc.ev('Type') if 'Type' in names else None
        dummied = sc.ev('DummiedMoves') if 'DummiedMoves' in names else None
        if 'AllowedMoves' in names:  # LGPE: lista blanca -> bitset de inexistentes
            allowed = set(sc.ev('AllowedMoves'))
            bits = bytearray((len(pp) + 7) // 8)
            for mv in range(1, len(pp)):
                if mv not in allowed:
                    bits[mv >> 3] |= 1 << (mv & 7)
            dummied = list(bits)
        ctx[suffix] = (pp, typ, dummied)
    return ctx


# ----------------------------------------------------------------- items

ITEMS = os.path.join(PK, 'Items')


def item_scope(*names):
    return Scope([os.path.join(ITEMS, n + '.cs') for n in names],
                 consts={'COUNT_TM': 100, 'COUNT_TR': 100, 'ExtraKeyCrystal': 1})


def items_for_games():
    """Listas de objetos por bolsillo y lista de objetos equipables por juego."""
    g = {}
    s = item_scope('ItemStorage1')
    g['g1'] = {'pouches': {'Items': s.ev('General'), 'PCItems': s.ev('General')}, 'held': []}
    s = item_scope('ItemStorage2')
    g['gs'] = {'pouches': {'TMHMs': s.ev('Machine'), 'Items': s.ev('General'), 'KeyItems': s.ev('KeyGS'),
                           'Balls': s.ev('Balls'), 'PCItems': s.ev('General') + s.ev('Balls') + s.ev('Machine') + s.ev('KeyGS')},
               'held': s.ev('General') + s.ev('Balls') + s.ev('Machine')[:50]}
    g['c'] = dict(g['gs'])
    g['c'] = {'pouches': dict(g['gs']['pouches'], KeyItems=s.ev('KeyCrystal'),
                              PCItems=s.ev('General') + s.ev('Balls') + s.ev('Machine') + s.ev('KeyCrystal')),
              'held': g['gs']['held']}
    s = item_scope('ItemStorage3RS')
    pc = s.ev('General') + s.ev('Berry') + s.ev('Balls') + s.ev('Machine')
    held3 = s.ev('General') + s.ev('Balls') + s.ev('Berry') + s.ev('MachineOnlyTM')
    g['rs'] = {'pouches': {'Items': s.ev('General'), 'KeyItems': s.ev('Key'), 'Balls': s.ev('Balls'),
                           'TMHMs': s.ev('Machine'), 'Berries': s.ev('Berry'), 'PCItems': pc}, 'held': held3}
    s = item_scope('ItemStorage3E', 'ItemStorage3RS')
    g['e'] = {'pouches': dict(g['rs']['pouches'], KeyItems=s.ev('Key')), 'held': held3}
    s = item_scope('ItemStorage3FRLG', 'ItemStorage3RS')
    g['frlg'] = {'pouches': dict(g['rs']['pouches'], KeyItems=s.ev('Key'), PCItems=s.ev('General')), 'held': held3}
    for key, cls, general in [('dp', 'ItemStorage4DP', 'GeneralDP'), ('pt', 'ItemStorage4Pt', 'GeneralPt'),
                              ('hgss', 'ItemStorage4HGSS', 'GeneralPt')]:
        s = item_scope(cls, 'ItemStorage4')
        balls = 'BallsHGSS' if key == 'hgss' else 'BallsDPPt'
        keyp = {'dp': 'KeyDP', 'pt': 'KeyPt', 'hgss': 'KeyHGSS'}[key]
        names = s.names
        if keyp not in names:
            keyp = 'Key'
        p = {'Items': s.ev(general), 'KeyItems': s.ev(keyp), 'TMHMs': s.ev('Machine'), 'MailItems': s.ev('Mail'),
             'Medicine': s.ev('Medicine'), 'Berries': s.ev('Berry'), 'Balls': s.ev(balls), 'BattleItems': s.ev('Battle')}
        held = p['Items'] + p['MailItems'] + p['Medicine'] + p['Berries'] + p['Balls'] + p['BattleItems'] + p['TMHMs'][:-8]
        g[key] = {'pouches': p, 'held': held}
    for key, cls in [('bw', 'ItemStorage5BW'), ('b2w2', 'ItemStorage5B2W2')]:
        s = item_scope(cls, 'ItemStorage5')
        p = {'Items': s.ev('General'), 'KeyItems': s.ev('Key'),
             'TMHMs': s.ev('Machine'), 'Medicine': s.ev('Medicine'), 'Berries': s.ev('Berry')}
        g[key] = {'pouches': p, 'held': p['Items'] + p['Medicine'] + p['Berries']}
    for key, cls in [('xy', 'ItemStorage6XY'), ('ao', 'ItemStorage6AO')]:
        s = item_scope(cls, 'ItemStorage6XY')
        p = {'Items': s.ev('General'), 'KeyItems': s.ev('Key'), 'TMHMs': s.ev('Machine'),
             'Medicine': s.ev('Medicine'), 'Berries': s.ev('Berry')}
        g[key] = {'pouches': p, 'held': p['Items'] + p['Medicine'] + p['Berries']}
    s = item_scope('ItemStorage7SM')
    p = {'Items': s.ev('General'), 'Medicine': s.ev('Medicine'), 'TMHMs': s.ev('Machine'), 'Berries': s.ev('Berry'),
         'KeyItems': s.ev('Key'), 'ZCrystals': s.ev('ZCrystalKey')}
    g['sm'] = {'pouches': p, 'held': p['Items'] + p['Berries'] + p['Medicine'] + s.ev('ZCrystalHeld')}
    s = item_scope('ItemStorage7USUM', 'ItemStorage7SM')
    p = {'Items': s.ev('General'), 'Medicine': s.ev('Medicine'), 'TMHMs': s.ev('Machine'), 'Berries': s.ev('Berry'),
         'KeyItems': s.ev('Key'), 'ZCrystals': s.ev('ZCrystalKey'), 'BattleItems': s.ev('Roto')}
    g['usum'] = {'pouches': p, 'held': p['Items'] + p['Berries'] + p['Medicine'] + s.ev('ZCrystalHeld') + s.ev('Roto')}
    s = item_scope('ItemStorage7GG')
    p = {'Medicine': s.ev('Medicine'), 'TMHMs': s.ev('Machine'), 'Candy': s.ev('Candy'),
         'ZCrystals': s.ev('PowerUp'), 'Balls': s.ev('Catching'), 'BattleItems': s.ev('Battle'),
         'Items': s.ev('General')}
    g['lgpe'] = {'pouches': p, 'held': []}
    s = item_scope('ItemStorage8SWSH')
    p = {'Medicine': s.ev('Medicine'), 'Balls': s.ev('Balls'), 'BattleItems': s.ev('Battle'), 'Berries': s.ev('Berry'),
         'Items': s.ev('General'), 'TMHMs': s.ev('MachineRecord'), 'Treasure': s.ev('Treasure'),
         'Candy': s.ev('Ingredients'), 'KeyItems': s.ev('Key')}
    g['swsh'] = {'pouches': p, 'held': p['Items'] + p['Balls'] + p['BattleItems'] + p['Berries'] + p['Medicine'] +
                 p['TMHMs'][100:200] + p['Treasure'] + p['Candy']}
    s = item_scope('ItemStorage8BDSP')
    p = {'Items': s.ev('General'), 'KeyItems': s.ev('Key'), 'TMHMs': s.ev('Machine'), 'Medicine': s.ev('Medicine'),
         'Berries': s.ev('Berry'), 'Balls': s.ev('Balls'), 'BattleItems': s.ev('Battle'), 'Treasure': s.ev('Treasure')}
    g['bdsp'] = {'pouches': p, 'held': p['Items'] + p['TMHMs'] + p['Medicine'] + p['Berries'] + p['Balls'] +
                 p['BattleItems'] + p['Treasure']}
    s = item_scope('ItemStorage9SV')
    p = {'Medicine': s.ev('Medicine'), 'Balls': s.ev('Balls'), 'BattleItems': s.ev('Battle'), 'Berries': s.ev('Berry'),
         'Items': s.ev('Other'), 'TMHMs': s.ev('Machine'), 'Treasure': s.ev('Treasure'),
         'Ingredients': s.ev('Picnic'), 'KeyItems': s.ev('Event'), 'Candy': s.ev('Material')}
    g['sv'] = {'pouches': p, 'held': p['Medicine'] + p['Balls'] + p['BattleItems'] + p['Berries'] + p['Items'] +
               p['Treasure']}
    s = item_scope('ItemStorage8LA')
    p = {'Items': s.ev('General'), 'KeyItems': s.ev('Key'), 'PCItems': s.ev('General'), 'Treasure': s.ev('Recipe')}
    g['la'] = {'pouches': p, 'held': []}
    s = item_scope('ItemStorage9ZA')
    p = {'Medicine': s.ev('Medicine'), 'Balls': s.ev('Balls'), 'Berries': s.ev('Berry'), 'Items': s.ev('Other'),
         'TMHMs': s.ev('TM'), 'MegaStones': s.ev('MegaStones'), 'Treasure': s.ev('Treasure'), 'KeyItems': s.ev('Key')}
    g['za'] = {'pouches': p, 'held': p['Medicine'] + p['Balls'] + p['Berries'] + p['MegaStones'] + p['Treasure'] +
               p['Items'][:-2]}
    return g


# ----------------------------------------------------------------- salida

def b64(data):
    return base64.b64encode(data).decode('ascii')


def dart_b64(name, data):
    s = b64(data)
    if not s:
        return f"const String {name} = '';\n"
    chunks = [s[i:i + 120] for i in range(0, len(s), 120)]
    body = '\n'.join(f"    '{c}'" for c in chunks)
    return f"const String {name} =\n{body};\n"


def u16bytes(values):
    return struct.pack(f'<{len(values)}H', *values)


def main():
    os.makedirs(OUT, exist_ok=True)
    hdr = ('// GENERADO por tool/gen_game_data.py — no editar a mano.\n'
           '// Fuente: PKHeX.Core (GPL-3.0). Nombres © Nintendo/Game Freak/Creatures.\n'
           '// ignore_for_file: lines_longer_than_80_chars\n\n')

    # ---- texto
    t = [hdr]
    for kind, var in [('Moves', 'Moves'), ('Abilities', 'Abilities'), ('Natures', 'Natures'), ('Types', 'Types'),
                      ('Forms', 'Forms')]:
        for lang, suf in [('es', 'Es'), ('en', 'En')]:
            t.append(dart_list(f'k{var}{suf}', text(kind, lang)))
    for lang, suf in [('es', 'Es'), ('en', 'En')]:
        t.append(dart_list(f'kItems{suf}', items_text(None, 'Items', lang)))
        t.append(dart_list(f'kItemsG3{suf}', items_text('gen3', 'ItemsG3', lang)))
        t.append(dart_list(f'kItemsG2{suf}', items_text('gen2', 'ItemsG2', lang)))
        t.append(dart_list(f'kItemsG1{suf}', items_text('gen1', 'ItemsG1', lang)))
    with open(os.path.join(OUT, 'game_text.dart'), 'w', encoding='utf-8') as f:
        f.write(''.join(t))

    # ---- binarios
    b = [hdr]
    tms = tm_lists()
    meta = []
    for key, fname, fmt, lvl, egg in GAMES:
        data, count, rec, tm_moves = repack_personal(key, fname, fmt, tms)
        b.append(dart_b64(f'_personal_{key}', data))
        b.append(dart_b64(f'_tm_{key}', u16bytes(tm_moves)))
        b.append(dart_b64(f'_lvl_{key}', open(os.path.join(RES, 'byte', 'levelup', lvl + '.pkl'), 'rb').read()))
        if egg:
            b.append(dart_b64(f'_egg_{key}', open(os.path.join(RES, 'byte', 'eggmove', egg + '.pkl'), 'rb').read()))
        meta.append((key, count, rec, egg is not None))
    b.append('\n/// Tablas por juego: (personal, registros, tamaño de registro, MT, learnset, huevo).\n')
    b.append('const Map<String, (String, int, int, String, String, String?)> kGameTables = {\n')
    for key, count, rec, has_egg in meta:
        egg = f'_egg_{key}' if has_egg else 'null'
        b.append(f"  '{key}': (_personal_{key}, {count}, {rec}, _tm_{key}, _lvl_{key}, {egg}),\n")
    b.append('};\n\n')

    # ---- Leyendas Z-A: movimientos «plus» (PKHeX `PersonalInfo9ZA.PlusMoves`,
    # `plus_za.pkl` y `AlphaMove` del dato personal, offset 0x4E).
    za_raw = open(os.path.join(RES, 'byte', 'personal', 'personal_za'), 'rb').read()
    za_alpha = [struct.unpack_from('<H', za_raw, i + 0x4E)[0] for i in range(0, len(za_raw), FMT[9][0])]
    b.append('/// Leyendas Z-A: movimiento de cada índice de flag «plus» (u16).\n')
    b.append(dart_b64('kZaPlusMoves', u16bytes(machine(os.path.join(PI, 'PersonalInfo9ZA.cs'), 'PlusMoves'))))
    b.append('/// Leyendas Z-A: nivel al que cada movimiento pasa a «plus» (BinLinker, como los learnsets).\n')
    b.append(dart_b64('kZaPlusLevels', open(os.path.join(RES, 'legality', 'misc', 'plus_za.pkl'), 'rb').read()))
    b.append('/// Leyendas Z-A: movimiento alfa por entrada personal (u16).\n')
    b.append(dart_b64('kZaAlphaMoves', u16bytes(za_alpha)))
    b.append('\n')

    mt = move_tables()
    b.append('/// Tablas de movimientos por contexto: (PP, tipo, inexistentes).\n')
    for suffix, (pp, typ, dummied) in mt.items():
        b.append(dart_b64(f'_pp_{suffix}', bytes(pp)))
        if typ:
            b.append(dart_b64(f'_type_{suffix}', bytes(typ)))
        if dummied:
            b.append(dart_b64(f'_dummied_{suffix}', bytes(dummied)))
    b.append('const Map<String, (String, String?, String?)> kMoveTables = {\n')
    for suffix, (pp, typ, dummied) in mt.items():
        tt = f'_type_{suffix}' if typ else 'null'
        dd = f'_dummied_{suffix}' if dummied else 'null'
        b.append(f"  '{suffix}': (_pp_{suffix}, {tt}, {dd}),\n")
    b.append('};\n\n')

    items = items_for_games()
    b.append('/// Objetos por juego: bolsillo -> ids (u16 base64); "held" = equipables.\n')
    b.append('const Map<String, Map<String, String>> kItemTables = {\n')
    for game, info in items.items():
        b.append(f"  '{game}': {{\n")
        for pouch, ids in info['pouches'].items():
            b.append(f"    '{pouch}': '{b64(u16bytes(ids))}',\n")
        b.append(f"    'held': '{b64(u16bytes(info['held']))}',\n")
        b.append('  },\n')
    b.append('};\n')
    with open(os.path.join(OUT, 'game_binaries.dart'), 'w', encoding='utf-8') as f:
        f.write(''.join(b))
    print('ok', OUT)


if __name__ == '__main__':
    main()
