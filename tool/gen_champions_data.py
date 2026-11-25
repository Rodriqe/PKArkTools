#!/usr/bin/env python3
"""Genera los datos del formato oficial vigente de Pokémon Champions.

Fuente (pública y actualizable): Pokémon Showdown
  * data/mods/champions/formats-data.ts  -> especies legales (sin isNonstandard)
  * config/formats.ts                     -> nombre y reglas del formato VGC vigente
  * data/rulesets.ts                      -> qué incluye «Flat Rules»
Fechas de cada regulación (no están en Showdown): tool/champions_regulations.json.

Salidas (las dos con el mismo contenido):
  * data/champions/champions.json  -> la app la descarga de GitHub (la
    actualiza a diario .github/workflows/champions-data.yml)
  * packages/pkcore/lib/src/data/generated/champions_data.dart -> copia
    integrada en la app (sin conexión)

Uso:
  python3 tool/gen_champions_data.py <dir con los .ts> <commit> <fecha AAAA-MM-DD> \
      [--json data/champions/champions.json] \
      [--dart packages/pkcore/lib/src/data/generated/champions_data.dart] \
      [--dates tool/champions_regulations.json] [--today AAAA-MM-DD]
  python3 tool/gen_champions_data.py --validate data/champions/champions.json

Si los datos no cambian (aunque haya commits nuevos en Showdown), el JSON no
se reescribe: el workflow solo hace commit cuando cambian los datos. Si Showdown cambia algo que el
generador no entiende, termina con error y no escribe nada.
Ver docs/usuario/formato-oficial.md.
"""
import argparse
import datetime as dt
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCHEMA_VERSION = 1
DEFAULT_JSON = ROOT / 'data/champions/champions.json'
DEFAULT_DART = ROOT / 'packages/pkcore/lib/src/data/generated/champions_data.dart'
DEFAULT_DATES = ROOT / 'tool/champions_regulations.json'
SOURCE_REPO = 'smogon/pokemon-showdown'
SOURCE_URL = 'https://github.com/smogon/pokemon-showdown/blob/master/data/mods/champions/formats-data.ts'

# Una lista de la regulación tiene unas 200-300 especies y formas; la del mod
# entero de National Dex (o un archivo mal leído) se saldría de este rango.
MIN_ALLOWED, MAX_ALLOWED = 150, 600


class GenError(Exception):
    pass


def parse_species(text: str):
    """Especies del formato: sin `isNonstandard` ni `tier: "Illegal"`.

    Solo cuentan los campos del formato normal (`tier`, `isNonstandard`), no
    los de National Dex (`natDexTier`, añadido por «Implement Champions
    National Dex», #12488): una especie solo de NatDex sigue marcada como
    `isNonstandard: "Past"` y queda fuera.
    """
    legal, megas = [], []
    entries = list(re.finditer(r"^\t([a-z0-9]+): \{(.*?)^\t\},?", text, re.S | re.M))
    if not entries:
        raise GenError('formats-data.ts: no se encontró ninguna especie')
    for m in entries:
        sid, body = m.group(1), m.group(2)
        if re.search(r'^\t\tisNonstandard:', body, re.M):
            continue
        tier = re.search(r'^\t\ttier: "([^"]+)"', body, re.M)
        if tier and tier.group(1) == 'Illegal':
            continue
        # «meganium» no es una Mega; «meganiummega» sí.
        if re.search(r'.mega[xyz]?$', sid) and sid != 'meganium':
            megas.append(sid)
            continue
        if sid.endswith('gmax'):
            continue
        legal.append(sid)
    return legal, megas


_VGC = re.compile(
    r'name: "\[Gen 9 Champions\] (VGC (\d{4}) Reg ([A-Z0-9]+(?:-[A-Z0-9]+)?))",\s*(.*?)\n\t\}',
    re.S,
)


def parse_formats(text: str):
    """Formatos VGC de Champions (sin Bo3), en el orden del archivo.

    Devuelve [(nombre, código, mod, ruleset)]. Solo `[Gen 9 Champions] VGC
    AAAA Reg X`: National Dex, BSS, Draft, etc. no cuentan.
    """
    out = []
    for m in _VGC.finditer(text):
        name, code, body = m.group(1), m.group(3), m.group(4)
        mod = re.search(r"mod: '([a-z0-9]+)'", body)
        rules = re.search(r"ruleset: \[(.*?)\]", body, re.S)
        rs = [r.strip().strip("'\"") for r in rules.group(1).split(',') if r.strip()] if rules else []
        out.append((name, code, mod.group(1) if mod else '', rs))
    return out


def pick_regulations(formats, dates, today: str):
    """(vigente, siguiente o None).

    Vigente: el formato con `mod: 'champions'` (el mod de la regulación
    actual; las anteriores pasan a `championsregmb`, etc.). Si hay varios, el
    que según la tabla de fechas está en curso hoy; si no, el primero.
    Siguiente: un formato VGC con un código posterior al vigente (p. ej. Reg
    M-D cuando Showdown lo añada).
    """
    current = [f for f in formats if f[2] == 'champions']
    if not current:
        raise GenError("formats.ts: no se encontró el formato VGC de Champions con mod: 'champions'")
    by_code = {d['code']: d for d in dates}
    cur = current[0]
    for f in current:
        d = by_code.get(f[1])
        if d and d.get('from') and d['from'] <= today < (d.get('until') or '9999'):
            cur = f
            break
    later = sorted({f[1]: f for f in formats if _code_key(f[1]) > _code_key(cur[1])}.values(), key=lambda f: _code_key(f[1]))
    return cur, (later[0] if later else None)


def _code_key(code: str):
    return tuple((0, int(p)) if p.isdigit() else (1, p) for p in re.split(r'[-]', code))


def parse_flat(text: str):
    m = re.search(r"\tflatrules: \{.*?desc: \"([^\"]+)\".*?ruleset: \[(.*?)\],\s*banlist: \[(.*?)\]", text, re.S)
    if not m:
        raise GenError('rulesets.ts: no se encontró Flat Rules')
    split = lambda s: [x.strip().strip("'\"") for x in s.split(',') if x.strip()]
    return m.group(1), split(m.group(2)), split(m.group(3))


def regulation(code, name, dates):
    d = next((x for x in dates if x['code'] == code), {})
    return {
        'code': code,
        'name': name,
        'from': d.get('from'),
        'until': d.get('until'),
        'datesSource': d.get('source', ''),
        'datesConfirmed': bool(d.get('confirmed', False)),
    }


def build(src: Path, commit: str, date: str, dates_path: Path, today: str, generated_at: str):
    legal, megas = parse_species((src / 'formats-data.ts').read_text(encoding='utf-8'))
    formats = parse_formats((src / 'formats.ts').read_text(encoding='utf-8'))
    desc, flat_rules, flat_ban = parse_flat((src / 'rulesets.ts').read_text(encoding='utf-8'))
    dates = json.loads(dates_path.read_text(encoding='utf-8'))['regulations']
    cur, nxt = pick_regulations(formats, dates, today)
    data = {
        'schemaVersion': SCHEMA_VERSION,
        'generatedAt': generated_at,
        'source': {
            'name': 'Pokémon Showdown',
            'repo': SOURCE_REPO,
            'url': SOURCE_URL,
            'commit': commit,
            'date': date,
        },
        'regulation': regulation(cur[1], cur[0], dates),
        'nextRegulation': regulation(nxt[1], nxt[0], dates) if nxt else None,
        'regulations': [
            {'code': d['code'], 'from': d['from'], 'until': d['until'], 'source': d['source'], 'confirmed': bool(d['confirmed'])}
            for d in dates
        ],
        'ruleset': cur[3],
        'flatRules': {'desc': desc, 'rules': flat_rules, 'banlist': flat_ban},
        'allowed': legal,
        'megas': megas,
        'banned': flat_ban,
    }
    validate(data)
    return data


_DATE = re.compile(r'^\d{4}-\d{2}-\d{2}$')
_ID = re.compile(r'^[a-z0-9]+$')


def validate(d):
    """Las comprobaciones de tools_test que se pueden hacer sin Dart."""
    def need(cond, msg):
        if not cond:
            raise GenError(f'JSON no válido: {msg}')

    need(isinstance(d, dict), 'no es un objeto')
    need(d.get('schemaVersion') == SCHEMA_VERSION, f'schemaVersion != {SCHEMA_VERSION}')
    need(isinstance(d.get('generatedAt'), str) and d['generatedAt'], 'generatedAt')
    s = d.get('source') or {}
    need(re.fullmatch(r'[0-9a-f]{40}', s.get('commit', '')) is not None, 'source.commit (40 hex)')
    need(_DATE.match(s.get('date', '')) is not None, 'source.date')
    for key in ('regulation', 'nextRegulation'):
        r = d.get(key)
        if key == 'nextRegulation' and r is None:
            continue
        need(isinstance(r, dict), key)
        need(re.fullmatch(r'VGC \d{4} Reg [A-Z0-9-]+', r.get('name', '')) is not None, f'{key}.name')
        need(r.get('name', '').endswith('Reg ' + r.get('code', '?')), f'{key}.code')
        for k in ('from', 'until'):
            need(r.get(k) is None or _DATE.match(r[k]) is not None, f'{key}.{k}')
        need(isinstance(r.get('datesConfirmed'), bool), f'{key}.datesConfirmed')
    reg = d['regulation']
    need(reg['from'] is not None and reg['until'] is not None, 'la regulación vigente no tiene fechas (tool/champions_regulations.json)')
    need(reg['from'] < reg['until'], 'regulation: from >= until')
    for r in d.get('regulations') or []:
        need(_DATE.match(r.get('from', '')) and _DATE.match(r.get('until', '')), f'regulations {r.get("code")}')
    allowed, megas = d.get('allowed'), d.get('megas')
    need(isinstance(allowed, list) and MIN_ALLOWED <= len(allowed) <= MAX_ALLOWED,
         f'allowed: {len(allowed or [])} especies (esperado {MIN_ALLOWED}-{MAX_ALLOWED}; ¿lista de National Dex?)')
    need(all(isinstance(x, str) and _ID.match(x) for x in allowed), 'allowed: ids de Showdown')
    need(len(set(allowed)) == len(allowed), 'allowed: repetidos')
    need(isinstance(megas, list) and megas and all(isinstance(x, str) and _ID.match(x) for x in megas), 'megas')
    need(not any(re.search(r'.mega[xyz]?$', x) and x != 'meganium' for x in allowed), 'allowed contiene Megas')
    fr = d.get('flatRules') or {}
    rules = fr.get('rules') or []
    need('Flat Rules' in d.get('ruleset', []), 'ruleset sin Flat Rules')
    need(any(r.startswith('Adjust Level Down') for r in rules), 'Flat Rules sin Adjust Level Down')
    need(any(r.startswith('Item Clause') for r in rules), 'Flat Rules sin Item Clause')
    need('Species Clause' in rules, 'Flat Rules sin Species Clause')
    need({'Mythical', 'Restricted Legendary'} <= set(fr.get('banlist') or []), 'Flat Rules no prohíbe singulares y restringidos')


def dump_json(data) -> str:
    return json.dumps(data, ensure_ascii=False, indent=1) + '\n'


def dart_source(data, text: str) -> str:
    s = data['source']
    if "'''" in text:
        raise GenError("el JSON contiene '''")
    return f"""// GENERADO por tool/gen_champions_data.py — no editar a mano.
// Fuente: Pokémon Showdown (MIT), commit {s['commit']} ({s['date']}).
// Es la misma información que data/champions/champions.json: la copia que
// lleva la app para cuando no puede descargar la última.
// ignore_for_file: lines_longer_than_80_chars

const kChampionsBuiltinJson = r'''
{text}''';
"""


def same_data(a, b):
    """¿Mismos datos? (sin contar cuándo se generó ni de qué commit salió)."""
    skip = ('generatedAt', 'source')
    return {k: v for k, v in a.items() if k not in skip} == {k: v for k, v in b.items() if k not in skip}


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('src', nargs='?')
    ap.add_argument('commit', nargs='?')
    ap.add_argument('date', nargs='?')
    ap.add_argument('--json', type=Path, default=DEFAULT_JSON)
    ap.add_argument('--dart', type=Path, default=DEFAULT_DART)
    ap.add_argument('--no-dart', action='store_true', help='solo el JSON (el workflow)')
    ap.add_argument('--dates', type=Path, default=DEFAULT_DATES)
    ap.add_argument('--today', default=dt.date.today().isoformat())
    ap.add_argument('--validate', type=Path, metavar='JSON', help='solo valida un JSON ya generado')
    a = ap.parse_args(argv)
    try:
        if a.validate:
            validate(json.loads(a.validate.read_text(encoding='utf-8')))
            print(f'{a.validate}: OK')
            return 0
        if not (a.src and a.commit and a.date):
            ap.error('faltan <dir> <commit> <fecha>')
        now = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace('+00:00', 'Z')
        data = build(Path(a.src), a.commit, a.date, a.dates, a.today, now)
    except GenError as e:
        print(f'gen_champions_data: {e}', file=sys.stderr)
        return 1
    # Si los datos no cambian (Showdown tocó otra cosa de formats.ts, por
    # ejemplo), se deja el archivo como estaba: ni commit ni descarga nueva.
    if a.json.exists():
        try:
            old = json.loads(a.json.read_text(encoding='utf-8'))
            if same_data(old, data):
                data['generatedAt'], data['source'] = old['generatedAt'], old['source']
        except (ValueError, KeyError):
            pass
    text = dump_json(data)
    a.json.parent.mkdir(parents=True, exist_ok=True)
    if not a.json.exists() or a.json.read_text(encoding='utf-8') != text:
        a.json.write_text(text, encoding='utf-8')
    if not a.no_dart:
        a.dart.write_text(dart_source(data, text), encoding='utf-8')
    nxt = data['nextRegulation']
    print(f"{data['regulation']['name']}: {len(data['allowed'])} especies/formas, {len(data['megas'])} megas"
          f"{', siguiente: ' + nxt['name'] if nxt else ''} -> {a.json}")
    return 0


if __name__ == '__main__':
    sys.exit(main())
