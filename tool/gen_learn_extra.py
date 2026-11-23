#!/usr/bin/env python3
"""Genera la compatibilidad de MT/MO de Gen 3 y de tutores de Gen 3–4 desde PKHeX.Core (GPL-3.0).

Uso: python3 tool/gen_learn_extra.py <ruta a PKHeX.Core> packages/pkcore/lib/src/data/generated/learn_extra.dart

Los datos personales de Gen 3 de PKHeX no incluyen las MT/MO ni los tutores:
se cargan aparte de `Resources/byte/personal/hmtm_g3.pkl` y `tutors_g3.pkl`
(`PersonalTable.PopulateGen3Tutors`). Los tutores de Platino/HGSS están en
`tutors_g4.pkl` (`PopulateGen4Tutors`). Cada archivo es un BinLinker con una
entrada de bits por especie (índice = especie nacional; en Gen 4, también formas).
Las listas de movimientos por bit vienen de `PersonalInfo3`/`PersonalInfo4` y
`LearnSource3E`.
"""
import base64
import os
import re
import struct
import sys

PK, OUT = sys.argv[1], sys.argv[2]
PERSONAL = os.path.join(PK, 'Resources', 'byte', 'personal')


def binlinker(name, ident):
    d = open(os.path.join(PERSONAL, name), 'rb').read()
    assert d[:2] == ident, (name, d[:2])
    n = struct.unpack_from('<H', d, 2)[0]
    offs = [struct.unpack_from('<I', d, 4 + i * 4)[0] for i in range(n + 1)]
    widths = {offs[i + 1] - offs[i] for i in range(n)}
    assert len(widths) == 1, (name, widths)
    w = widths.pop()
    return w, b''.join(d[offs[i]:offs[i + 1]] for i in range(n))


def ushort_list(path, prop):
    src = open(os.path.join(PK, path), encoding='utf-8').read()
    m = re.search(prop + r'\s*=>\s*\[(.*?)\];', src, re.S)
    assert m, (path, prop)
    body = re.sub(r'//[^\n]*', '', m.group(1))
    return [int(x, 10) for x in re.findall(r'\d+', body)]


g3_tm = ushort_list('PersonalInfo/Info/PersonalInfo3.cs', 'MachineMovesTechnical')
g3_hm = ushort_list('PersonalInfo/Info/PersonalInfo3.cs', 'MachineMovesHidden')
g3_tutor = ushort_list('Legality/LearnSource/Sources/LearnSource3E.cs', 'Tutor_E')
g4_tutor = ushort_list('PersonalInfo/Info/PersonalInfo4.cs', 'TutorMoves')
assert len(g3_tm) == 50 and len(g3_hm) == 8 and len(g3_tutor) == 30 and len(g4_tutor) == 52

w_m3, m3 = binlinker('hmtm_g3.pkl', b'g3')
w_t3, t3 = binlinker('tutors_g3.pkl', b'g3')
w_t4, t4 = binlinker('tutors_g4.pkl', b'g4')


def b64(b):
    return base64.b64encode(b).decode('ascii')


def ints(xs):
    return ', '.join(str(x) for x in xs)


out = f"""// GENERADO por tool/gen_learn_extra.py — no editar a mano.
// Fuente: PKHeX.Core (GPL-3.0), Resources/byte/personal/{{hmtm_g3,tutors_g3,tutors_g4}}.pkl,
// PersonalInfo3/PersonalInfo4 y LearnSource3E.
// ignore_for_file: lines_longer_than_80_chars

/// Movimientos por bit de la compatibilidad de MT (50) y MO (8) de Gen 3.
const List<int> kG3MachineMoves = [{ints(g3_tm + g3_hm)}];

/// Bits de MT/MO de Gen 3 por especie ({w_m3} bytes por entrada).
const int kG3MachineWidth = {w_m3};
const String kG3MachineFlags = '{b64(m3)}';

/// Movimientos de los tutores de Rojo Fuego/Verde Hoja y Esmeralda.
const List<int> kG3TutorMoves = [{ints(g3_tutor)}];
const int kG3TutorWidth = {w_t3};
const String kG3TutorFlags = '{b64(t3)}';

/// Movimientos de los tutores de Platino/HeartGold/SoulSilver.
const List<int> kG4TutorMoves = [{ints(g4_tutor)}];
const int kG4TutorWidth = {w_t4};
const String kG4TutorFlags = '{b64(t4)}';
"""
open(OUT, 'w', encoding='utf-8').write(out)
print(f'{OUT}: g3 MT {len(m3) // w_m3}, g3 tutores {len(t3) // w_t3}, g4 tutores {len(t4) // w_t4}')
