#!/usr/bin/env python3
"""Genera la base de eventos (Mystery Gift) de pkcore desde la salida del oráculo PKHeX.

Uso: python3 tool/gen_event_data.py .scratch/events/events.jsonl \
        packages/pkcore/lib/src/data/generated/event_data.dart

Entrada: `events.jsonl` del comando `events` de tools/pkhex_oracle (EventTable.cs).
Salida: cuatro listas paralelas (una entrada por evento), decodificadas con
carga perezosa por `EventDb` (lib/src/events/event_db.dart):

* kEventMeta: JSON compacto con los datos fijos del evento.
* kEventTpl:  Pokémon almacenado (descifrado) que genera PKHeX, en base64.
* kEventRaw:  tarjeta en bruto (base64; vacío en Gen 3, que no tiene formato de archivo).
* kEventVar:  variantes PID/EC/IV/naturaleza/habilidad/género (20 bytes c/u), base64.
"""
import base64, json, sys

SRC, OUT = sys.argv[1], sys.argv[2]

KEYS = {  # clave del oráculo -> clave corta en pkcore
    'db': 'db', 'index': 'i', 'card': 'c', 'title': 't', 'species': 's', 'form': 'f',
    'level': 'l', 'shiny': 'sh', 'gen': 'g', 'format': 'fmt', 'versions': 'v',
    'langs': 'tl', 'pkLangs': 'pl', 'date': 'd', 'winStart': 'ws', 'winEnd': 'we',
    'winGen': 'wg', 'method': 'm', 'otByLang': 'ot', 'nickByLang': 'nk', 'otName': 'on',
    'tplVersion': 'tv', 'tplLang': 'tlg', 'err': 'err',
}
FLAGS = [('egg', 'E'), ('recvOt', 'O'), ('recvId', 'I'), ('recvGender', 'G'),
         ('recvLang', 'L'), ('home', 'H'), ('metToday', 'T'), ('eggToday', 'U')]


def dart(s):
    return "'" + s.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$') + "'"


rows = [json.loads(l) for l in open(SRC, encoding='utf-8') if l.strip()]
meta, tpl, raw, var = [], [], [], []
for r in rows:
    m = {KEYS[k]: v for k, v in r.items() if k in KEYS and v not in (None, '', [], {})}
    if 'err' in m and 'tpl' in r:
        del m['err']
    if 'err' in m:
        m['err'] = m['err'][:160]
    flags = ''.join(c for k, c in FLAGS if r.get(k))
    if flags:
        m['x'] = flags
    meta.append(json.dumps(m, ensure_ascii=False, separators=(',', ':')))
    tpl.append(r.get('tpl', ''))
    raw.append(r.get('raw', ''))
    var.append(base64.b64encode(b''.join(base64.b64decode(v) for v in r.get('variants', []))).decode())

with open(OUT, 'w', encoding='utf-8') as f:
    f.write('// GENERADO por tool/gen_event_data.py desde PKHeX.Core (GPL-3.0). No editar a mano.\n')
    f.write('// Fuente: tools/pkhex_oracle, comando `events` (EncounterEvent y EncountersWC3).\n')
    f.write('// ignore_for_file: lines_longer_than_80_chars\n\n')
    f.write(f'/// Eventos (Mystery Gift) de Pokémon: {len(rows)}.\n')
    for name, items, doc in [
        ('kEventMeta', meta, 'Datos fijos de cada evento (JSON compacto; ver `EventGift`).'),
        ('kEventTpl', tpl, 'Plantilla: Pokémon almacenado descifrado que genera PKHeX (base64).'),
        ('kEventRaw', raw, 'Tarjeta en bruto (base64; vacío en Gen 3).'),
        ('kEventVar', var, 'Variantes legales PID/EC/IV/naturaleza/habilidad/género (20 bytes c/u, base64).'),
    ]:
        f.write(f'/// {doc}\nconst List<String> {name} = [\n')
        for it in items:
            f.write(f'  {dart(it)},\n')
        f.write('];\n\n')
print(f'{len(rows)} eventos -> {OUT}')
