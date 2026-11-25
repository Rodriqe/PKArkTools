#!/usr/bin/env python3
"""Lectura de las fuentes OFICIALES de Pokémon Champions (sin red).

Lo usan tool/fetch_champions_official.py (qué descargar) y
tool/gen_champions_data.py (qué escribir en data/champions/champions.json).

Fuentes (ver docs/usuario/formato-oficial.md):
  * Noticias del juego: https://champions-news.pokemon-home.com/en/json/list.json
    Las entradas con `infoKind == 12` son regulaciones; la página de cada una
    (`/en/page/<id>.html`) da el nombre, las fechas exactas (UTC), las Megas
    nuevas y el enlace a «Eligible Pokémon».
  * «Eligible Pokémon» (web-view.app.pokemonchampions.jp/.../en/pokemon.html):
    lleva la lista embebida como `const pokemons = [["0026-001",1,"Raichu
    (Alolan Form)"], ...]` (especie-forma del juego, marca, nombre en inglés).

Los ids especie-forma del juego se traducen a ids de Showdown (los que ya
entiende la app 2.0): `000` es la forma base; las demás formas se reconocen
por la etiqueta del nombre (`(Alolan Form)` -> `alola`). Una etiqueta que no
está en FORM_LABELS es un error: mejor no publicar que inventar una forma.
"""
import datetime as dt
import html
import json
import re
from urllib.parse import urlparse

NEWS_BASE = 'https://champions-news.pokemon-home.com/en/'
FEED_URL = NEWS_BASE + 'json/list.json'
ELIGIBLE_HOST = 'web-view.app.pokemonchampions.jp'
REGULATION_KIND = 12


class OfficialError(Exception):
    pass


def page_url(item_id: str) -> str:
    return f'{NEWS_BASE}page/{item_id}.html'


def to_id(name: str) -> str:
    """Id de Showdown de un nombre en inglés (`Farfetch’d` -> `farfetchd`)."""
    return re.sub(r'[^a-z0-9]', '', name.lower().replace('é', 'e'))


# ---------------------------------------------------------------- noticias

def parse_feed(text: str):
    """Regulaciones del feed: [{'id', 'code', 'title', 'endAt'}] (más nueva primero).

    `endAt` (epoch, UTC) es el fin de la regulación (la página lo dice en
    texto; sirve para elegir qué páginas descargar y para comprobarlas).
    """
    try:
        root = json.loads(text)
    except ValueError as e:
        raise OfficialError(f'list.json: {e}') from None
    items = root.get('data') if isinstance(root, dict) else None
    if not isinstance(items, list) or not items:
        raise OfficialError('list.json: sin "data"')
    out = []
    for it in items:
        if not isinstance(it, dict) or it.get('infoKind') != REGULATION_KIND:
            continue
        iid, title = str(it.get('id', '')), str(it.get('title', ''))
        m = re.search(r'Regulation Set ([A-Z]-[A-Z0-9]+)\b', title)
        if not re.fullmatch(r'\d{1,6}', iid) or not m:
            raise OfficialError(f'list.json: regulación no reconocida: {iid} {title!r}')
        try:
            end = int(it.get('endAt'))
        except (TypeError, ValueError):
            end = None
        out.append({'id': iid, 'code': m.group(1), 'title': title, 'endAt': end})
    if not out:
        raise OfficialError('list.json: ninguna regulación (infoKind 12)')
    return out


def feed_to_fetch(regs, now: dt.datetime, limit: int = 3):
    """Las regulaciones que pueden ser la vigente o la siguiente (no han terminado)."""
    ts = now.timestamp()
    live = [r for r in regs if r['endAt'] is None or r['endAt'] >= ts]
    return live[:limit]


_MONTHS = {m: i for i, m in enumerate(
    ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
     'September', 'October', 'November', 'December'], 1)}
_WHEN = r'(?:[A-Z][a-z]+day, )?([A-Z][a-z]+) (\d{1,2}), (\d{4}),? at (\d{1,2}):(\d{2}) UTC'
_DURATION = re.compile(_WHEN + r'\s+to\s+' + _WHEN)


def _when(month, day, year, hh, mm) -> dt.datetime:
    if month not in _MONTHS:
        raise OfficialError(f'mes no reconocido: {month}')
    return dt.datetime(int(year), _MONTHS[month], int(day), int(hh), int(mm), tzinfo=dt.timezone.utc)


def _text(fragment: str) -> str:
    return html.unescape(re.sub(r'<[^>]+>', '\n', fragment))


def parse_page(text: str, item_id: str = ''):
    """Página de una regulación -> dict con code, officialName, startsAt,
    endsAt (último minuto incluido, como lo dice la página), eligibleUrl (o
    None si todavía no se publicó la lista) y newMegas (ids de Showdown)."""
    title = re.search(r'<div class="article-title">(.*?)</div>', text, re.S) or \
        re.search(r'<title>(.*?)</title>', text, re.S)
    if not title:
        raise OfficialError(f'página {item_id}: sin título')
    title = html.unescape(title.group(1)).strip()
    m = re.search(r'Regulation Set ([A-Z]-[A-Z0-9]+)\b', title)
    if not m:
        raise OfficialError(f'página {item_id}: título no reconocido: {title!r}')
    code = m.group(1)
    body = re.search(r'<div class="article-body">(.*?)</article>', text, re.S)
    if not body:
        raise OfficialError(f'página {item_id}: sin cuerpo')
    body = body.group(1)
    plain = re.sub(r'\s+', ' ', _text(body))
    d = _DURATION.search(plain)
    if not d:
        raise OfficialError(f'página {item_id}: no se encontró la duración (… at HH:MM UTC to … at HH:MM UTC)')
    g = d.groups()
    start, end = _when(*g[:5]), _when(*g[5:])
    if not start < end:
        raise OfficialError(f'página {item_id}: fechas al revés')
    links = re.findall(r'href="(https://[^"]+/pokemon\.html)"', body)
    eligible = None
    for link in links:
        u = urlparse(html.unescape(link))
        if u.scheme == 'https' and u.hostname == ELIGIBLE_HOST:
            eligible = u.geturl()
            break
    megas = []
    for name in re.findall(r'•\s*Mega ([A-Za-z][A-Za-z .’\'-]*?)\s*(?=<|•|$)', html.unescape(body), re.M):
        mx = re.fullmatch(r'(.+?)(?: ([XYZ]))?', name.strip())
        mid = to_id(mx.group(1)) + 'mega' + (mx.group(2) or '').lower()
        if mid not in megas:
            megas.append(mid)
    return {
        'code': code,
        'officialName': f'Regulation Set {code}',
        'startsAt': start,
        'endsAt': end,
        'eligibleUrl': eligible,
        'newMegas': megas,
    }


# ------------------------------------------------------- Eligible Pokémon

_POKEMONS = re.compile(r'const pokemons\s*=\s*(\[.*?\])\s*;', re.S)


def parse_pokemons(text: str):
    """`const pokemons = [...]` -> [(especie, forma, nombre)]."""
    m = _POKEMONS.search(text)
    if not m:
        raise OfficialError('pokemon.html: no se encontró `const pokemons`')
    try:
        arr = json.loads(m.group(1))
    except ValueError as e:
        raise OfficialError(f'pokemon.html: `pokemons` no es JSON: {e}') from None
    out = []
    for e in arr:
        if not (isinstance(e, list) and len(e) >= 3 and isinstance(e[0], str) and isinstance(e[2], str)):
            raise OfficialError(f'pokemon.html: entrada no reconocida: {e!r}')
        km = re.fullmatch(r'(\d{4})-(\d{3})', e[0])
        if not km:
            raise OfficialError(f'pokemon.html: id no reconocido: {e[0]!r}')
        if e[1] != 1:
            # Todas las entradas publicadas llevan 1; otro valor tendría un
            # significado que no conocemos.
            raise OfficialError(f'pokemon.html: marca desconocida {e[1]!r} en {e[0]}')
        out.append((int(km.group(1)), int(km.group(2)), e[2]))
    if not out:
        raise OfficialError('pokemon.html: lista vacía')
    return out


# Etiqueta del nombre oficial (lo que va entre paréntesis) -> sufijo del id de
# Showdown. Solo formas que no son la base (la forma 000 es siempre la base).
FORM_LABELS = {
    'Alolan Form': 'alola',
    'Galarian Form': 'galar',
    'Hisuian Form': 'hisui',
    'Paldean Form (Combat Breed)': 'paldeacombat',
    'Paldean Form (Blaze Breed)': 'paldeablaze',
    'Paldean Form (Aqua Breed)': 'paldeaaqua',
    'Heat Rotom': 'heat',
    'Wash Rotom': 'wash',
    'Frost Rotom': 'frost',
    'Fan Rotom': 'fan',
    'Mow Rotom': 'mow',
    'Female': 'f',
    'Small Variety': 'small',
    'Large Variety': 'large',
    'Jumbo Variety': 'super',
    'Midnight Form': 'midnight',
    'Dusk Form': 'dusk',
    'Low Key Form': 'lowkey',
}

# Formas sin etiqueta y distintas de 000: la lista oficial pone un solo icono
# por especie y todas sus formas del juego cuentan. Por defecto, el id base
# (Vivillon, Maushold: formas solo estéticas). Excepciones:
UNLABELED = {
    # Floette solo existe en Champions como la de la Flor Eterna (y su Mega).
    (670, 5): ['floetteeternal'],
    # Los cuatro plumajes son formas distintas (cambia la habilidad).
    (931, None): ['squawkabilly', 'squawkabillyblue', 'squawkabillyyellow', 'squawkabillywhite'],
}


def map_pokemon(species: int, form: int, name: str):
    """(especie, forma, nombre oficial) -> ids de Showdown."""
    m = re.fullmatch(r'(.+?)(?: \((.*)\))?', name.strip())
    base, label = to_id(m.group(1)), m.group(2)
    if not base:
        raise OfficialError(f'{species:04}-{form:03}: nombre vacío')
    if form == 0:
        return [base]
    if label is None:
        ids = UNLABELED.get((species, form)) or UNLABELED.get((species, None))
        return list(ids) if ids else [base]
    suffix = FORM_LABELS.get(label)
    if suffix is None:
        raise OfficialError(f'{species:04}-{form:03} {name!r}: forma desconocida (añádela a FORM_LABELS)')
    return [base + suffix]


def allowed_ids(entries):
    """Lista oficial -> ids de Showdown (orden de la lista, sin repetidos)."""
    out = []
    for s, f, name in entries:
        for i in map_pokemon(s, f, name):
            if i not in out:
                out.append(i)
    return out


# Formas que solo existen en combate: Showdown las lista como especies
# aparte, la lista oficial no (y nunca están guardadas en una partida).
BATTLE_ONLY = {'castformsunny', 'castformrainy', 'castformsnowy', 'aegislashblade'}


def cross_check(official, showdown):
    """(solo en la oficial, solo en Showdown), sin las formas de combate."""
    o, s = set(official), set(showdown) - BATTLE_ONLY
    return sorted(o - s), sorted(s - o)
