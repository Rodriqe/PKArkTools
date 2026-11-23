#!/usr/bin/env python3
"""Genera la tabla de composición canónica (NFC) para nombres de archivo.

macOS (smbfs, AFP, HFS+) devuelve los nombres en NFD ("e" + acento) y el Arca
construye sus rutas en NFC ("é"): sin componer, una misma ruta parecería dos.

Uso: python3 tool/gen_nfc_table.py apps/pkarktools/lib/data/folder/nfc_table.dart
"""
import sys
import unicodedata

pairs = {}
for cp in range(0x110000):
    if 0xAC00 <= cp <= 0xD7A3 or 0xD800 <= cp <= 0xDFFF:
        continue  # Hangul se compone algorítmicamente; sustitutos no son caracteres.
    ch = chr(cp)
    if unicodedata.normalize('NFC', ch) != ch:
        continue  # Exclusiones de composición y singletons.
    dec = unicodedata.decomposition(ch)
    if not dec or dec.startswith('<'):
        continue  # Sin descomposición o solo de compatibilidad.
    parts = [int(x, 16) for x in dec.split()]
    if len(parts) != 2:
        continue
    pairs[(parts[0] << 21) | parts[1]] = cp

out = sys.argv[1]
with open(out, 'w', encoding='utf-8') as f:
    f.write('// GENERADO por tool/gen_nfc_table.py (Unicode %s). No editar a mano.\n' % unicodedata.unidata_version)
    f.write('// ignore_for_file: lines_longer_than_80_chars\n\n')
    f.write('/// Composición canónica: (base << 21 | marca) → carácter compuesto.\n')
    f.write('const Map<int, int> nfcPairs = {\n')
    items = sorted(pairs.items())
    for i in range(0, len(items), 6):
        f.write('  ' + ' '.join('0x%x: 0x%x,' % kv for kv in items[i:i + 6]) + '\n')
    f.write('};\n')
print(len(pairs), 'pares')
