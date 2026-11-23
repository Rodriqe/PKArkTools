#!/usr/bin/env python3
"""Extrae las tablas de caracteres de PKHeX.Core (GPL-3.0) a Dart.

Uso: python3 tool/gen_charsets.py <PKHeX.Core/PKM/Strings> <salida.dart>
Tablas portadas de PKHeX (https://github.com/kwsch/PKHeX), (c) Kaphotics y colaboradores, GPL-3.0.
"""
import re, sys, os, glob

src, out = sys.argv[1], sys.argv[2]
text = {os.path.basename(p): open(p, encoding='utf-8').read() for p in glob.glob(os.path.join(src, '*.cs'))}
alltext = '\n'.join(text.values())

def unescape(lit):
    body = lit[1:-1]
    if body.startswith('\\u'):
        return chr(int(body[2:], 16))
    return {"\\'": "'", '\\\\': '\\', '\\0': '\0', '\\"': '"'}.get(body, body)

def file_consts(fname):
    d = {}
    for m in re.finditer(r"const char (\w+)\s*=\s*('(?:\\.|[^'])+?'|[\w.()]+)\s*;", text[fname]):
        d[m.group(1)] = m.group(2)
    return d

def resolve(tok, fname, depth=0):
    if depth > 10: raise SystemExit('ciclo en ' + tok)
    if tok.startswith("'"):
        return unescape(tok)
    if tok.startswith('(char)'):
        return '\0'
    if '.' in tok:
        cls, name = tok.split('.', 1)
        return resolve(name, cls + '.cs', depth + 1)
    if tok == 'Terminator' and fname == 'StringConverter2KOR.cs':
        return '\0'
    if tok == 'Terminator' and fname in ('StringConverter1.cs', 'StringConverter2.cs', 'StringConverter3.cs'):
        d = file_consts(fname)
        if 'Terminator' not in d: return '\0'
    d = file_consts(fname)
    if tok not in d:
        raise SystemExit('constante desconocida: %s en %s' % (tok, fname))
    return resolve(d[tok], fname, depth + 1)

def table(fname, name):
    t = re.sub(r"//[^\n]*", "", text[fname])
    m = re.search(r'ReadOnlySpan<char> ' + name + r'\s*=>\s*\[(.*?)\];', t, re.S)
    if not m: raise SystemExit('tabla no encontrada %s %s' % (fname, name))
    body = re.sub(r'//[^\n]*', '', m.group(1))
    toks = re.findall(r"'(?:\\.|[^'])*'|[A-Za-z_][\w.]*", body)
    return [resolve(x, fname) for x in toks]

# Constantes especiales de la tabla Gen4 (NUL = 0xFFFF)
tables = {
    'kCharsG1En': table('StringConverter2.cs', 'TableEN'),
    'kCharsG1Jp': table('StringConverter2.cs', 'TableJP'),
    'kCharsG12Ita': table('StringConverter2.cs', 'TableITA'),
    'kCharsG12Fre': table('StringConverter2.cs', 'TableFRE'),
    'kCharsG3En': table('StringConverter3.cs', 'G3_EN'),
    'kCharsG3Jp': table('StringConverter3.cs', 'G3_JP'),
    'kCharsG4': table('StringConverter4Util.cs', 'TableINT'),
    # Gen 2 coreano: tabla 0 (1 byte) y tablas 1..B (2 bytes: [tabla][índice]).
    'kCharsG2Kor0': table('StringConverter2KOR.cs', 'Table0'),
}
for _i, _n in enumerate('123456789AB', start=1):
    tables[f'kCharsG2Kor{_n}'] = table('StringConverter2KOR.cs', f'Table{_n}')
with open(out, 'w', encoding='utf-8') as f:
    f.write('// GENERADO por tool/gen_charsets.py — no editar a mano.\n')
    f.write('// Tablas de caracteres portadas de PKHeX.Core (GPL-3.0), https://github.com/kwsch/PKHeX\n\n')
    for k, v in tables.items():
        codes = [ord(c) if c not in ('￿',) else 0 for c in v]
        f.write(f'/// {len(codes)} entradas. 0 = terminador / sin glifo.\n')
        f.write(f'const List<int> {k} = <int>[' + ','.join(map(str, codes)) + '];\n\n')
for k, v in tables.items(): print(k, len(v))
