#!/usr/bin/env python3
"""Genera la base de eventos (Mystery Gift) de pkcore desde la salida del oráculo PKHeX.

Uso: python3 tool/gen_event_data.py .scratch/events/events.jsonl \
        packages/pkcore/lib/src/data/generated/event_data.dart \
        [--json data/events/events.json --commit <sha de PKHeX> --date AAAA-MM-DD]
     python3 tool/gen_event_data.py --validate data/events/events.json

Normalmente se llama desde tool/gen_event_data.sh.

`data/events/events.json` (lo descarga la app; ver docs/usuario/eventos.md)
lleva lo mismo que la copia integrada: `schemaVersion`, `generatedAt`,
`source` (commit y fecha de PKHeX), `count` y `events`, un evento por línea
(`m` = datos fijos, `t` = plantilla, `r` = tarjeta, `v` = variantes). Si los
eventos no cambian, el JSON no se reescribe aunque cambie el commit de PKHeX.

PKHeX genera las plantillas con `Random.Shared` y la fecha de hoy, así que dos
ejecuciones nunca dan lo mismo. Para que el JSON solo cambie cuando cambian
los eventos, cada evento cuya huella estable (`fingerprint`: tarjeta, especie,
forma, nivel, variocolor, método, ventanas…) ya estaba en la versión anterior
(el JSON o, la primera vez, la copia integrada) reutiliza la entrada anterior.
tool/check_events_pkhex.sh comprueba igualmente el resultado con el PKHeX
nuevo. `--fresh` lo genera todo de nuevo. Si el
total baja más de un 10 % respecto al JSON anterior, termina con error sin
escribir nada (un cambio de PKHeX que el oráculo no entiende).

Entrada: `events.jsonl` del comando `events` de tools/pkhex_oracle (EventTable.cs).
Salida: cuatro listas paralelas (una entrada por evento), decodificadas con
carga perezosa por `EventDb` (lib/src/events/event_db.dart):

* kEventMeta: JSON compacto con los datos fijos del evento.
* kEventTpl:  Pokémon almacenado (descifrado) que genera PKHeX, en base64.
* kEventRaw:  tarjeta en bruto (base64; vacío en Gen 3, que no tiene formato de archivo).
* kEventVar:  variantes PID/EC/IV/naturaleza/habilidad/género (20 bytes c/u), base64.
"""
import argparse, base64, datetime as dt, json, re, sys
from pathlib import Path

SCHEMA_VERSION = 1
MIN_EVENTS = 1000  # hoy hay unos 2900
MAX_DROP = 0.10
VARIANT_SIZE = {'pk3': 80, 'pa9': 328}

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


class GenError(Exception):
    pass


def build(src):
    """Las cuatro listas paralelas a partir de la salida del oráculo."""
    rows = [json.loads(l) for l in open(src, encoding='utf-8') if l.strip()]
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

    return rows, meta, tpl, raw, var


STABLE = ('db', 'c', 't', 's', 'f', 'l', 'sh', 'g', 'fmt', 'm', 'on', 'ws', 'we', 'wg')


def fingerprint(e):
    """Lo que identifica un evento y no depende del azar ni de la fecha."""
    m = e['m']
    flags = ''.join(c for c in m.get('x', '') if c in 'EH')
    return json.dumps([m.get(k) for k in STABLE] + [flags, 'err' in m], ensure_ascii=False)


def reuse_previous(events, previous):
    """Cambia cada evento por el anterior con la misma huella (con su índice nuevo)."""
    pool = {}
    for e in previous:
        pool.setdefault(fingerprint(e), []).append(e)
    out, reused = [], 0
    for e in events:
        same = pool.get(fingerprint(e))
        if same:
            old = same.pop(0)
            out.append({**old, 'm': {**old['m'], 'i': e['m']['i']}})
            reused += 1
        else:
            out.append(e)
    return out, reused


def load_dart(path):
    """Eventos de una copia integrada (event_data.dart) ya generada."""
    lists, cur = {}, None
    for line in open(path, encoding='utf-8'):
        m = re.match(r'const List<String> (\w+) = \[', line)
        if m:
            cur = m.group(1)
            lists[cur] = []
        elif line.startswith('];'):
            cur = None
        elif cur and line.startswith("  '"):
            v = line.strip()[1:-2]
            lists[cur].append(re.sub(r"\\(.)", r'\1', v))
    keys = ('kEventMeta', 'kEventTpl', 'kEventRaw', 'kEventVar')
    if not all(k in lists for k in keys):
        return []
    return [{'m': json.loads(m), 't': t, 'r': r, 'v': v} for m, t, r, v in zip(*(lists[k] for k in keys))]


def write_dart(out, meta, tpl, raw, var, source, generated_at):
    with open(out, 'w', encoding='utf-8') as f:
        f.write('// GENERADO por tool/gen_event_data.py desde PKHeX.Core (GPL-3.0). No editar a mano.\n')
        f.write('// Fuente: tools/pkhex_oracle, comando `events` (EncounterEvent y EncountersWC3).\n')
        f.write('// ignore_for_file: lines_longer_than_80_chars\n\n')
        f.write(f"const kEventSourceCommit = '{source.get('commit', '')}';\n")
        f.write(f"const kEventSourceDate = '{source.get('date', '')}';\n")
        f.write(f"const kEventGeneratedAt = '{generated_at}';\n\n")
        f.write(f'/// Eventos (Mystery Gift) de Pokémon: {len(meta)}.\n')
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
    


_B64 = re.compile(r'^[A-Za-z0-9+/]*={0,2}$')


def validate(d):
    """Lo mismo que comprueba la app al descargarlo (EventData.parse)."""
    def need(cond, msg):
        if not cond:
            raise GenError(f'JSON no válido: {msg}')

    need(isinstance(d, dict) and d.get('schemaVersion') == SCHEMA_VERSION, 'schemaVersion')
    need(isinstance(d.get('generatedAt'), str) and d['generatedAt'], 'generatedAt')
    s = d.get('source') or {}
    need(re.fullmatch(r'[0-9a-f]{40}', s.get('commit', '')) is not None, 'source.commit (40 hex)')
    need(re.fullmatch(r'\d{4}-\d{2}-\d{2}', s.get('date', '')) is not None, 'source.date')
    ev = d.get('events')
    need(isinstance(ev, list) and len(ev) >= MIN_EVENTS, f'events: {len(ev or [])} (mínimo {MIN_EVENTS})')
    need(d.get('count') == len(ev), 'count')
    for n, e in enumerate(ev):
        m = e.get('m') if isinstance(e, dict) else None
        need(isinstance(m, dict) and isinstance(m.get('db'), str) and isinstance(m.get('i'), int)
             and isinstance(m.get('s'), int) and 0 < m['s'] <= 1025, f'evento {n}: m')
        for k in ('t', 'r', 'v'):
            need(isinstance(e.get(k), str) and _B64.match(e[k]) and len(e[k]) % 4 == 0, f'evento {n}: {k}')
        # Variantes de 20 bytes; en Gen 3 y Z-A, el Pokémon almacenado entero.
        size = VARIANT_SIZE.get(m.get('fmt'), 20)
        need(len(base64.b64decode(e['v'])) % size == 0, f'evento {n}: variantes')


def dump_json(d):
    head = {k: v for k, v in d.items() if k != 'events'}
    lines = [json.dumps(e, ensure_ascii=False, separators=(',', ':')) for e in d['events']]
    text = json.dumps(head, ensure_ascii=False, separators=(',', ':'))[:-1]
    return text + ',"events":[\n' + ',\n'.join(lines) + '\n]}\n'


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument('src', nargs='?')
    ap.add_argument('out', nargs='?')
    ap.add_argument('--json', type=Path)
    ap.add_argument('--commit', default='')
    ap.add_argument('--date', default='')
    ap.add_argument('--validate', type=Path, metavar='JSON')
    ap.add_argument('--fresh', action='store_true', help='no reutiliza las entradas anteriores')
    a = ap.parse_args(argv)
    try:
        if a.validate:
            d = json.loads(a.validate.read_text(encoding='utf-8'))
            validate(d)
            print(f"{a.validate}: OK, {d['count']} eventos, PKHeX {d['source']['commit'][:7]}")
            return 0
        if not (a.src and a.out):
            ap.error('faltan <events.jsonl> <event_data.dart>')
        rows, meta, tpl, raw, var = build(a.src)
        now = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace('+00:00', 'Z')
        source = {'name': 'PKHeX', 'repo': 'kwsch/PKHeX', 'commit': a.commit, 'date': a.date}
        generated_at = now
        if a.json:
            events = [{'m': json.loads(m), 't': t, 'r': r, 'v': v} for m, t, r, v in zip(meta, tpl, raw, var)]
            old = json.loads(a.json.read_text(encoding='utf-8')) if a.json.exists() else None
            previous = old['events'] if old else (load_dart(a.out) if Path(a.out).exists() else [])
            if len(events) < (1 - MAX_DROP) * len(previous):
                raise GenError(f'el total baja de {len(previous)} a {len(events)} eventos (más de un '
                               f'{int(MAX_DROP * 100)} %): no se escribe nada')
            if not a.fresh:
                events, reused = reuse_previous(events, previous)
                print(f'{reused} de {len(events)} eventos sin cambios (se reutiliza la entrada anterior)')
            d = {'schemaVersion': SCHEMA_VERSION, 'generatedAt': now, 'source': source,
                 'count': len(events), 'events': events}
            validate(d)
            # Mismos eventos: se deja el archivo como estaba.
            if old and old.get('events') == events:
                d = old
            source, generated_at = d['source'], d['generatedAt']
            meta = [json.dumps(e['m'], ensure_ascii=False, separators=(',', ':')) for e in d['events']]
            tpl, raw, var = ([e[k] for e in d['events']] for k in ('t', 'r', 'v'))
            text = dump_json(d)
            a.json.parent.mkdir(parents=True, exist_ok=True)
            if not a.json.exists() or a.json.read_text(encoding='utf-8') != text:
                a.json.write_text(text, encoding='utf-8')
        write_dart(a.out, meta, tpl, raw, var, source, generated_at)
    except GenError as e:
        print(f'gen_event_data: {e}', file=sys.stderr)
        return 1
    print(f'{len(meta)} eventos -> {a.out}' + (f', {a.json}' if a.json else ''))
    return 0


if __name__ == '__main__':
    sys.exit(main())
