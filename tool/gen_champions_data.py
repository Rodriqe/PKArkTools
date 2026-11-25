#!/usr/bin/env python3
"""Genera los datos del formato oficial vigente de Pokémon Champions.

Fuentes, por orden (ver docs/usuario/formato-oficial.md):
  1. OFICIALES (tool/fetch_champions_official.py las descarga; las lee
     tool/champions_official.py):
       * noticias del juego (list.json + página de cada regulación): qué
         regulación está vigente, la siguiente, fechas y horas exactas (UTC)
         y las Megas nuevas;
       * «Eligible Pokémon» (`const pokemons = [...]`): la lista de especies
         y formas de la regulación vigente.
  2. Pokémon Showdown (tool/fetch_champions_sources.py), solo para:
       * lo que no publica el juego en un formato legible: «Flat Rules» y la
         lista completa de Megas;
       * comprobar la lista oficial (las diferencias son avisos en el log del
         workflow, no errores);
       * la lista de la regulación vigente si la oficial todavía no está
         publicada (y Showdown ya tiene esa regulación). Si no está en ninguna
         de las dos, error: nunca se inventa una lista.
     Si Showdown no responde, se reutiliza lo del último JSON bueno.

Solo se escriben la regulación VIGENTE (lista, reglas, fechas) y la SIGUIENTE
(solo nombre y fechas, para avisar del cambio); las anteriores no. El esquema
es el v1 que entiende la app 2.0; los campos nuevos son opcionales y la app
2.0 los ignora.

Salidas (las dos con el mismo contenido):
  * data/champions/champions.json  -> la app la descarga de GitHub (la
    actualiza a diario .github/workflows/champions-data.yml)
  * packages/pkcore/lib/src/data/generated/champions_data.dart -> copia
    integrada en la app (sin conexión)

Uso:
  python3 tool/gen_champions_data.py --official <dir> \
      [--showdown <dir> --commit <sha> --date AAAA-MM-DD] \
      [--json data/champions/champions.json] [--dart ...] [--no-dart] \
      [--now AAAA-MM-DDTHH:MM:SSZ]
  python3 tool/gen_champions_data.py --validate data/champions/champions.json

Si los datos no cambian, el JSON no se reescribe (el workflow solo hace commit
cuando cambian). Si algo no se entiende, termina con error y no escribe nada.
"""
import argparse
import datetime as dt
import json
import re
import sys
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
import champions_official as off  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SCHEMA_VERSION = 1
DEFAULT_JSON = ROOT / 'data/champions/champions.json'
DEFAULT_DART = ROOT / 'packages/pkcore/lib/src/data/generated/champions_data.dart'
SOURCE_REPO = 'smogon/pokemon-showdown'
SOURCE_URL = 'https://github.com/smogon/pokemon-showdown/blob/master/data/mods/champions/formats-data.ts'

# Una lista de la regulación tiene unas 200-300 especies y formas; la del mod
# entero de National Dex (o un archivo mal leído) se saldría de este rango.
MIN_ALLOWED, MAX_ALLOWED = 150, 600


class GenError(Exception):
    pass


# ------------------------------------------------------------- Showdown

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
        if _is_mega(sid):
            megas.append(sid)
            continue
        if sid.endswith('gmax'):
            continue
        legal.append(sid)
    return legal, megas


def _is_mega(sid: str) -> bool:
    return re.search(r'.mega[xyz]?$', sid) is not None and sid != 'meganium'


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


def parse_flat(text: str):
    m = re.search(r"\tflatrules: \{.*?desc: \"([^\"]+)\".*?ruleset: \[(.*?)\],\s*banlist: \[(.*?)\]", text, re.S)
    if not m:
        raise GenError('rulesets.ts: no se encontró Flat Rules')
    split = lambda s: [x.strip().strip("'\"") for x in s.split(',') if x.strip()]
    return m.group(1), split(m.group(2)), split(m.group(3))


def read_showdown(src: Path, commit: str, date: str):
    """Lo que se usa de Showdown: su regulación actual (mod 'champions'), su
    lista, Megas, ruleset y Flat Rules."""
    legal, megas = parse_species((src / 'formats-data.ts').read_text(encoding='utf-8'))
    formats = parse_formats((src / 'formats.ts').read_text(encoding='utf-8'))
    desc, flat_rules, flat_ban = parse_flat((src / 'rulesets.ts').read_text(encoding='utf-8'))
    current = [f for f in formats if f[2] == 'champions']
    if not current:
        raise GenError("formats.ts: no se encontró el formato VGC de Champions con mod: 'champions'")
    name, code, _, ruleset = current[0]
    if not re.fullmatch(r'[0-9a-f]{40}', commit or '') or not re.fullmatch(r'\d{4}-\d{2}-\d{2}', date or ''):
        raise GenError('Showdown: falta --commit (40 hex) o --date (AAAA-MM-DD)')
    return {
        'code': code, 'name': name, 'names': {f[1]: f[0] for f in formats},
        'allowed': legal, 'megas': megas, 'ruleset': ruleset,
        'flatRules': {'desc': desc, 'rules': flat_rules, 'banlist': flat_ban},
        'source': {'name': 'Pokémon Showdown', 'repo': SOURCE_REPO, 'url': SOURCE_URL, 'commit': commit, 'date': date},
    }


# ------------------------------------------------------------- oficiales

def _iso(t: dt.datetime) -> str:
    return t.astimezone(dt.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')


def read_official(src: Path):
    """[{id, page...}] de las regulaciones descargadas, por fecha de inicio."""
    feed = off.parse_feed((src / 'list.json').read_text(encoding='utf-8'))
    regs, warnings = [], []
    for item in feed:
        page = src / f'page_{item["id"]}.html'
        if not page.exists():
            continue
        p = off.parse_page(page.read_text(encoding='utf-8'), item['id'])
        if p['code'] != item['code']:
            raise GenError(f'página {item["id"]}: {p["code"]} != {item["code"]} del feed')
        # El feed da el fin (al segundo 59); la página, al minuto.
        if item['endAt'] is not None and abs(item['endAt'] - p['endsAt'].timestamp() - 59) > 60:
            warnings.append(f'{p["officialName"]}: el feed dice que termina el '
                            f'{_iso(dt.datetime.fromtimestamp(item["endAt"], dt.timezone.utc))} y la página el {_iso(p["endsAt"])}')
        pk = src / f'pokemon_{item["id"]}.html'
        p['id'] = item['id']
        p['pageUrl'] = off.page_url(item['id'])
        p['entries'] = off.parse_pokemons(pk.read_text(encoding='utf-8')) if p['eligibleUrl'] and pk.exists() else None
        regs.append(p)
    if not regs:
        raise GenError('fuentes oficiales: ninguna página de regulación descargada')
    regs.sort(key=lambda r: r['startsAt'])
    return regs, warnings


def pick(regs, now: dt.datetime):
    """(vigente, siguiente o None) según la fecha y hora (UTC)."""
    cur = next((r for r in regs if r['startsAt'] <= now < r['endsAt'] + dt.timedelta(minutes=1)), None)
    if cur is None:
        raise GenError(f'ninguna regulación oficial vigente el {_iso(now)}')
    later = [r for r in regs if r['startsAt'] > cur['startsAt']]
    return cur, (later[0] if later else None)


def _until(r) -> str:
    """Día en que deja de valer (el del minuto siguiente al último): así la
    app 2.0 muestra «M-C … – 2 dic» y «siguiente: M-D (desde el 2 dic)»."""
    return (r['endsAt'] + dt.timedelta(minutes=1)).date().isoformat()


def regulation(r, name: str):
    """Forma v1 (lo que lee la app 2.0) + campos opcionales nuevos."""
    return {
        'code': r['code'],
        'name': name,
        'from': r['startsAt'].date().isoformat(),
        'until': _until(r),
        'datesSource': r['pageUrl'],
        'datesConfirmed': True,
        # Opcionales (la app 2.0 no los lee):
        'officialName': r['officialName'],
        'startsAt': _iso(r['startsAt']),
        'endsAt': _iso(r['endsAt']),
        'eligibleUrl': r['eligibleUrl'],
    }


def _name(code: str, r, showdown) -> str:
    """`VGC AAAA Reg X` (lo exige la app 2.0): el de Showdown si ya lo tiene;
    si no, con el año en que empieza."""
    if showdown and code in showdown['names']:
        return showdown['names'][code]
    return f'VGC {r["startsAt"].year} Reg {code}'


def build(official: Path, showdown, prev, now: dt.datetime, generated_at: str):
    """-> (datos, avisos). `showdown`: read_showdown() o None; `prev`: el
    último JSON bueno (o None)."""
    regs, warnings = read_official(official)
    cur, nxt = pick(regs, now)
    prev_same = prev if prev and (prev.get('regulation') or {}).get('code') == cur['code'] else None
    sd_same = showdown if showdown and showdown['code'] == cur['code'] else None

    if cur['entries']:
        allowed = off.allowed_ids(cur['entries'])
        allowed_source = 'official'
        if sd_same:
            only_off, only_sd = off.cross_check(allowed, sd_same['allowed'])
            if only_off or only_sd:
                warnings.append(f'{cur["officialName"]}: la lista oficial y la de Showdown difieren: '
                                f'solo oficial {only_off}, solo Showdown {only_sd}')
        elif showdown:
            warnings.append(f'Showdown sigue en {showdown["code"]}: no se puede comparar con la lista oficial de {cur["code"]}')
    elif sd_same:
        allowed = [i for i in sd_same['allowed'] if i not in off.BATTLE_ONLY]
        allowed_source = 'showdown'
        warnings.append(f'{cur["officialName"]}: la lista oficial no está publicada; se usa la de Showdown')
    elif prev_same and (prev_same['regulation'].get('allowedSource') == 'official'):
        allowed = list(prev_same['allowed'])
        allowed_source = 'official'
        warnings.append(f'{cur["officialName"]}: no se pudo leer la lista oficial; se mantiene la última')
    else:
        raise GenError(f'{cur["officialName"]}: la lista de Pokémon no está publicada (ni en Showdown): '
                       'no se inventa; se mantiene el último JSON')

    base = showdown or prev
    if base is None:
        raise GenError('sin Showdown ni JSON anterior: faltan Flat Rules y Megas')
    if not showdown:
        warnings.append('Showdown no disponible: Flat Rules, Megas y fuente del último JSON')
    megas = list(base['megas'])
    for m in cur['newMegas']:
        if m not in megas:
            megas.append(m)
            if sd_same:
                warnings.append(f'{cur["officialName"]}: Mega nueva oficial que Showdown no tiene: {m}')

    reg = regulation(cur, _name(cur['code'], cur, showdown))
    reg['allowedSource'] = allowed_source
    nreg = None
    if nxt:
        nreg = regulation(nxt, _name(nxt['code'], nxt, showdown))
        nreg['allowedPublished'] = bool(nxt['eligibleUrl'])
    data = {
        'schemaVersion': SCHEMA_VERSION,
        'generatedAt': generated_at,
        'source': dict(base['source']),
        'official': {
            'name': 'Pokémon Champions (news and Eligible Pokémon)',
            'feed': off.FEED_URL,
            'regulationPage': cur['pageUrl'],
            'eligibleUrl': cur['eligibleUrl'],
        },
        'regulation': reg,
        'nextRegulation': nreg,
        'regulations': [
            {'code': r['code'], 'from': r['from'], 'until': r['until'], 'source': r['datesSource'], 'confirmed': True}
            for r in (reg, nreg) if r
        ],
        'ruleset': list(base['ruleset']),
        'flatRules': dict(base['flatRules']),
        'allowed': allowed,
        'megas': megas,
        'banned': list(base['flatRules']['banlist']),
    }
    validate(data)
    return data, warnings


# -------------------------------------------------------------- validar

_DATE = re.compile(r'^\d{4}-\d{2}-\d{2}$')
_INSTANT = re.compile(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$')
_ID = re.compile(r'^[a-z0-9]+$')


def validate(d):
    """Lo que comprueba ChampionsData.fromJson (app 2.0) y algo más."""
    def need(cond, msg):
        if not cond:
            raise GenError(f'JSON no válido: {msg}')

    need(isinstance(d, dict), 'no es un objeto')
    need(d.get('schemaVersion') == SCHEMA_VERSION, f'schemaVersion != {SCHEMA_VERSION}')
    need(isinstance(d.get('generatedAt'), str) and d['generatedAt'], 'generatedAt')
    s = d.get('source') or {}
    need(re.fullmatch(r'[0-9a-f]{40}', s.get('commit', '')) is not None, 'source.commit (40 hex)')
    need(_DATE.match(s.get('date', '')) is not None, 'source.date')
    need(str(s.get('url', '')).startswith('https://github.com/'), 'source.url (la app 2.0 exige github.com)')
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
        need(isinstance(r.get('datesSource'), str), f'{key}.datesSource')
        for k in ('startsAt', 'endsAt'):
            need(r.get(k) is None or _INSTANT.match(r[k]) is not None, f'{key}.{k}')
    reg = d['regulation']
    need(reg['from'] is not None and reg['until'] is not None, 'la regulación vigente no tiene fechas')
    need(reg['from'] < reg['until'], 'regulation: from >= until')
    nxt = d.get('nextRegulation')
    if nxt and nxt.get('from'):
        need(nxt['from'] >= reg['from'], 'nextRegulation empieza antes que la vigente')
    for r in d.get('regulations') or []:
        need(_DATE.match(r.get('from', '')) and _DATE.match(r.get('until', '')), f'regulations {r.get("code")}')
        need(isinstance(r.get('source'), str) and isinstance(r.get('confirmed'), bool), f'regulations {r.get("code")}')
    allowed, megas = d.get('allowed'), d.get('megas')
    need(isinstance(allowed, list) and MIN_ALLOWED <= len(allowed) <= MAX_ALLOWED,
         f'allowed: {len(allowed or [])} especies (esperado {MIN_ALLOWED}-{MAX_ALLOWED}; ¿lista de National Dex?)')
    need(all(isinstance(x, str) and _ID.match(x) for x in allowed), 'allowed: ids de Showdown')
    need(len(set(allowed)) == len(allowed), 'allowed: repetidos')
    need(isinstance(megas, list) and megas and all(isinstance(x, str) and _ID.match(x) for x in megas), 'megas')
    need(not any(_is_mega(x) for x in allowed), 'allowed contiene Megas')
    fr = d.get('flatRules') or {}
    rules = fr.get('rules') or []
    need(isinstance(fr.get('desc'), str), 'flatRules.desc')
    need('Flat Rules' in d.get('ruleset', []), 'ruleset sin Flat Rules')
    need(any(r.startswith('Adjust Level Down') for r in rules), 'Flat Rules sin Adjust Level Down')
    need(any(r.startswith('Item Clause') for r in rules), 'Flat Rules sin Item Clause')
    need('Species Clause' in rules, 'Flat Rules sin Species Clause')
    need({'Mythical', 'Restricted Legendary'} <= set(fr.get('banlist') or []), 'Flat Rules no prohíbe singulares y restringidos')


def dump_json(data) -> str:
    return json.dumps(data, ensure_ascii=False, indent=1) + '\n'


def dart_source(data, text: str) -> str:
    if "'''" in text:
        raise GenError("el JSON contiene '''")
    return f"""// GENERADO por tool/gen_champions_data.py — no editar a mano.
// Fuentes: las oficiales de Pokémon Champions (regulación, fechas y lista)
// y Pokémon Showdown (MIT; Flat Rules y Megas), commit {data['source']['commit']}.
// Es la misma información que data/champions/champions.json: la copia que
// lleva la app para cuando no puede descargar la última.
// ignore_for_file: lines_longer_than_80_chars

const kChampionsBuiltinJson = r'''
{text}''';
"""


def same_data(a, b):
    """¿Mismos datos? (sin contar cuándo se generó ni de qué commit de Showdown salió)."""
    skip = ('generatedAt', 'source')
    return {k: v for k, v in a.items() if k not in skip} == {k: v for k, v in b.items() if k not in skip}


def _now(s: str | None) -> dt.datetime:
    if not s:
        return dt.datetime.now(dt.timezone.utc).replace(microsecond=0)
    t = dt.datetime.fromisoformat(s.replace('Z', '+00:00'))
    return t if t.tzinfo else t.replace(tzinfo=dt.timezone.utc)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--official', type=Path, help='directorio de tool/fetch_champions_official.py')
    ap.add_argument('--showdown', type=Path, help='directorio de tool/fetch_champions_sources.py (opcional)')
    ap.add_argument('--commit', help='commit de Showdown (fetch_champions_sources.py)')
    ap.add_argument('--date', help='fecha de ese commit (AAAA-MM-DD)')
    ap.add_argument('--json', type=Path, default=DEFAULT_JSON)
    ap.add_argument('--dart', type=Path, default=DEFAULT_DART)
    ap.add_argument('--no-dart', action='store_true', help='solo el JSON (el workflow)')
    ap.add_argument('--now', help='fecha y hora UTC (pruebas); por defecto, ahora')
    ap.add_argument('--validate', type=Path, metavar='JSON', help='solo valida un JSON ya generado')
    a = ap.parse_args(argv)
    try:
        if a.validate:
            validate(json.loads(a.validate.read_text(encoding='utf-8')))
            print(f'{a.validate}: OK')
            return 0
        if not a.official:
            ap.error('falta --official <dir>')
        prev = None
        if a.json.exists():
            try:
                prev = json.loads(a.json.read_text(encoding='utf-8'))
                validate(prev)
            except (ValueError, GenError):
                prev = None
        showdown = None
        if a.showdown and (a.showdown / 'formats.ts').exists():
            try:
                showdown = read_showdown(a.showdown, a.commit, a.date)
            except GenError as e:
                print(f'::warning::Showdown: {e} (se usa el último JSON)', file=sys.stderr)
        now = _now(a.now)
        data, warnings = build(a.official, showdown, prev, now, _iso(now))
    except (GenError, off.OfficialError, OSError) as e:
        print(f'gen_champions_data: {e}', file=sys.stderr)
        return 1
    for w in warnings:
        # «::warning::» lo muestra GitHub Actions como aviso (no falla el job).
        print(f'::warning::{w}', file=sys.stderr)
    # Si los datos no cambian, se deja el archivo como estaba: ni commit ni
    # descarga nueva.
    if prev and same_data(prev, data):
        data['generatedAt'], data['source'] = prev['generatedAt'], prev['source']
    text = dump_json(data)
    a.json.parent.mkdir(parents=True, exist_ok=True)
    if not a.json.exists() or a.json.read_text(encoding='utf-8') != text:
        a.json.write_text(text, encoding='utf-8')
    if not a.no_dart:
        a.dart.write_text(dart_source(data, text), encoding='utf-8')
    r, nxt = data['regulation'], data['nextRegulation']
    print(f"{r['name']} ({r['startsAt']} – {r['endsAt']}): {len(data['allowed'])} especies/formas "
          f"({r['allowedSource']}), {len(data['megas'])} megas"
          f"{', siguiente: ' + nxt['name'] + ' desde ' + nxt['startsAt'] if nxt else ''} -> {a.json}")
    return 0


if __name__ == '__main__':
    sys.exit(main())
