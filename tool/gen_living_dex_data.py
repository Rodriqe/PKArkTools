#!/usr/bin/env python3
"""Genera la tabla de la Living Dex de pkcore desde la salida del oráculo PKHeX.

Uso: python3 tool/gen_living_dex_data.py .scratch/livingdex/livingdex.jsonl \
        packages/pkcore/lib/src/data/generated/living_dex_data.dart

Entrada: `livingdex.jsonl` del comando `livingdex` de tools/pkhex_oracle (LivingDexTable.cs).
Salida: tres listas paralelas (una entrada por versión(es)/especie/forma), decodificadas
con carga perezosa por `LivingDexDb` (lib/src/livingdex/living_dex.dart):

* kLivingDexMeta: 'versiones|especie|forma|estado' donde estado es
    'k,m,sm,fl,es,nv'  (tipo e/s/w, modo f/1/k, modo variocolor f/1/-, flags L=bloqueado, S=variocolor fijo, F=objeto de evento,
                        especie del encuentro, nivel)  si hay plantilla, o
    '!motivo'          (battle, fused, totem, lord, boxrevert, eventform, region, noenc, err) si no.
* kLivingDexTpl: Pokémon almacenado (descifrado) que generó PKHeX, con los ceros
  comprimidos (0x00 n = n ceros) y en base64.
* kLivingDexAlt: plantilla alternativa (modo keep), mismo formato; vacío si no hay.
"""
import base64, json, sys

SRC, OUT = sys.argv[1], sys.argv[2]


def rle(b):
    o = bytearray(); i = 0
    while i < len(b):
        if b[i] == 0:
            j = i
            while j < len(b) and b[j] == 0 and j - i < 255:
                j += 1
            o += bytes([0, j - i]); i = j
        else:
            o.append(b[i]); i += 1
    return base64.b64encode(bytes(o)).decode()


rows = [json.loads(l) for l in open(SRC, encoding='utf-8') if l.strip()]
meta, tpl, alt = [], [], []
for r in rows:
    vs = '.'.join(str(v) for v in r.get('vs', [r['v']]))
    if 'tpl' in r and r.get('mode') != 'bad':
        k = {'egg': 'e', 'static': 's', 'wild': 'w'}[r['kind']]
        m = {'free': 'f', 'm1': '1', 'keep': 'k'}[r['mode']]
        sm = {'free': 'f', 'm1': '1'}.get(r.get('smode'), '-')
        fl = ('L' if r.get('locked') else '') + ('S' if r.get('shinyFixed') else '') + ('F' if r.get('fateful') else '')
        st = f"{k},{m},{sm},{fl},{r['encSpecies']},{r['level']}"
        tpl.append(rle(base64.b64decode(r['tpl'])))
        alt.append(rle(base64.b64decode(r['alt'])) if r.get('alt') else '')
    else:
        why = r.get('skip') or ('noenc' if r.get('err') == 'noenc' else
                                ('region' if 'Vivillon' in r.get('err', '') else 'err'))
        st = '!' + why
        tpl.append(''); alt.append('')
    meta.append(f"{vs}|{r['s']}|{r['f']}|{st}")

with open(OUT, 'w', encoding='utf-8') as f:
    f.write('// GENERADO por tool/gen_living_dex_data.py desde PKHeX.Core (GPL-3.0). No editar a mano.\n')
    f.write('// Fuente: tools/pkhex_oracle, comando `livingdex` (encuentros de cada versión).\n')
    f.write('// ignore_for_file: lines_longer_than_80_chars\n\n')
    f.write(f'/// Filas (versión/especie/forma): {len(rows)}.\n')
    for name, items, doc in [
        ('kLivingDexMeta', meta, "'versiones|especie|forma|estado' (ver tool/gen_living_dex_data.py)."),
        ('kLivingDexTpl', tpl, 'Plantilla: Pokémon almacenado descifrado que genera PKHeX (ceros comprimidos, base64).'),
        ('kLivingDexAlt', alt, 'Plantilla alternativa (modo keep), mismo formato; vacío si no hay.'),
    ]:
        f.write(f'/// {doc}\nconst List<String> {name} = [\n')
        for it in items:
            f.write(f"  '{it}',\n")
        f.write('];\n\n')
print(f'{len(rows)} filas → {OUT}')
