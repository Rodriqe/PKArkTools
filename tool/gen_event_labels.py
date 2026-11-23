#!/usr/bin/env python3
"""Genera las etiquetas de eventos (flags y constantes) de pkcore desde PKHeX.Core (GPL-3.0).

Uso: python3 tool/gen_event_labels.py <ruta a PKHeX.Core> packages/pkcore/lib/src/data/generated/event_labels.dart

* Gen 2–4 y BDSP: `Resources/text/script/genN/{flags,const}_<juego>_<idioma>.txt`
  (índice<TAB>categoría<TAB>descripción[<TAB>valores]).
* Gen 8–9 (SwishCrypto): nombres de bloque de `Saves/Access/SaveBlockAccessor*.cs`
  (`const uint KNombre = 0x…; // comentario`).
"""
import os, re, sys

PK, OUT = sys.argv[1], sys.argv[2]
SCRIPT = os.path.join(PK, 'Resources', 'text', 'script')

TABLES = [  # (clave, carpeta, prefijo flags, prefijo work, juego en el nombre de archivo)
    ('gs', 'gen2', 'flags', 'const', 'gs'), ('c', 'gen2', 'flags', 'const', 'c'),
    ('rs', 'gen3', 'flags', 'const', 'rs'), ('e', 'gen3', 'flags', 'const', 'e'), ('frlg', 'gen3', 'flags', 'const', 'frlg'),
    ('dp', 'gen4', 'flags', 'const', 'dp'), ('pt', 'gen4', 'flags', 'const', 'pt'), ('hgss', 'gen4', 'flags', 'const', 'hgss'),
    ('bw', 'gen5', 'flags', 'const', 'bw'), ('b2w2', 'gen5', 'flags', 'const', 'b2w2'),
    ('xy', 'gen6', 'flags', 'const', 'xy'), ('oras', 'gen6', 'flags', 'const', 'oras'),
    ('sm', 'gen7', 'flags', 'const', 'sm'), ('usum', 'gen7', 'flags', 'const', 'usum'),
    ('gg', 'gen7', 'flags', 'const', 'gg'),
    ('bdsp', 'gen8', 'flag', 'work', 'bdsp'),
]

# Let's Go (PKHeX `EventWork7b`): las etiquetas usan "<tipo><índice>" relativo a
# cada zona; se convierten a índice absoluto. Tipos: z zona, s sistema, v
# desaparición, e evento (flags) y z/s/c escena/e (constantes).
GG_FLAG_START = {'z': 0, 's': 0x80, 'v': 0x80 + 0x200, 'e': 0x80 + 0x200 + 0x600}
GG_WORK_START = {'z': 0, 's': 0x20, 'c': 0x20 + 0x80, 'e': 0x20 + 0x80 + 0x200}
GG_CATEGORY = {'z': 'm', 's': '*', 'v': 'm', 'c': 's', 'e': 's'}


def read_gg(path, starts):
    if not os.path.exists(path):
        return ''
    lines = []
    for raw in open(path, encoding='utf-8').read().splitlines():
        m = re.match(r'([a-z])(\d+)\t(.+)', raw)
        if not m or m.group(1) not in starts:
            continue
        idx = starts[m.group(1)] + int(m.group(2))
        lines.append(f'{idx}\t{GG_CATEGORY[m.group(1)]}\t{m.group(3).strip()}'.replace('\\', '/'))
    return '\n'.join(lines)


def read(path):
    if not os.path.exists(path):
        return ''
    lines = []
    for raw in open(path, encoding='utf-8').read().splitlines():
        parts = raw.split('\t')
        if len(parts) < 3 or not parts[0].strip():
            continue
        lines.append('\t'.join(p.replace('\\', '/') for p in parts))
    return '\n'.join(lines)


def dart_str(s):
    return "'" + s.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$').replace('\n', '\\n') + "'"


def accessor_names(fname):
    path = os.path.join(PK, 'Saves', 'Access', fname)
    out = []
    for m in re.finditer(r'const uint K(\w+)\s*=\s*0x([0-9A-Fa-f]+);\s*(?://\s*(.*))?', open(path, encoding='utf-8').read()):
        name, key, comment = m.group(1), int(m.group(2), 16), (m.group(3) or '').strip()
        out.append(f'{key:08X}\t{name}\t{comment}'.replace('\\', '/'))
    return '\n'.join(out)


def main():
    out = ['// GENERADO por tool/gen_event_labels.py — no editar a mano.\n',
           '// Fuente: PKHeX.Core (GPL-3.0), Resources/text/script y SaveBlockAccessor*.cs.\n',
           '// ignore_for_file: lines_longer_than_80_chars\n\n',
           '/// Etiquetas TSV por "<tipo>_<juego>_<idioma>" (tipo = flags | work).\n',
           'const Map<String, String> kEventLabels = {\n']
    for key, folder, fpre, wpre, game in TABLES:
        for lang in ('es', 'en'):
            for kind, pre in (('flags', fpre), ('work', wpre)):
                path = os.path.join(SCRIPT, folder, f'{pre}_{game}_{lang}.txt')
                if key == 'gg':
                    txt = read_gg(path, GG_FLAG_START if kind == 'flags' else GG_WORK_START)
                else:
                    txt = read(path)
                if txt:
                    out.append(f"  '{kind}_{key}_{lang}': {dart_str(txt)},\n")
    out.append('};\n\n')
    out.append('/// Nombres de bloques SwishCrypto por juego: "CLAVEHEX<TAB>Nombre<TAB>comentario".\n')
    out.append('const Map<String, String> kBlockNames = {\n')
    for key, f in (('swsh', 'SaveBlockAccessor8SWSH.cs'), ('la', 'SaveBlockAccessor8LA.cs'),
                   ('sv', 'SaveBlockAccessor9SV.cs'), ('za', 'SaveBlockAccessor9ZA.cs')):
        out.append(f"  '{key}': {dart_str(accessor_names(f))},\n")
    out.append('};\n')
    with open(OUT, 'w', encoding='utf-8') as fh:
        fh.write(''.join(out))
    print('ok', OUT, os.path.getsize(OUT))


if __name__ == '__main__':
    main()
