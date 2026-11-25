#!/usr/bin/env python3
"""Descarga las fuentes OFICIALES de las regulaciones de Pokémon Champions.

  python3 tool/fetch_champions_official.py .scratch/official

Guarda en el directorio:
  list.json             el feed de noticias del juego
  page_<id>.html        la página de cada regulación que no ha terminado
                        (la vigente y la siguiente; como mucho 3)
  pokemon_<id>.html     su «Eligible Pokémon», si ya está publicada

Pocas peticiones por ejecución (1 + 2-3 páginas + 1-2 listas), GET con un
User-Agent genérico del proyecto, timeout de 30 s y 2 reintentos. Si algo
falla, termina con error sin dejar archivos a medias: el workflow no hace
commit y la app sigue con el último JSON bueno.
"""
import datetime as dt
import sys
import time
import urllib.request
from pathlib import Path
from urllib.parse import urlparse

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
import champions_official as off  # noqa: E402

USER_AGENT = 'PKArkTools-data/1.0 (+https://github.com/Rodriqe/PKArkTools)'
MAX_BYTES = 2 * 1024 * 1024
ALLOWED_HOSTS = {urlparse(off.NEWS_BASE).hostname, off.ELIGIBLE_HOST}


def get(url: str) -> bytes:
    host = urlparse(url).hostname
    if urlparse(url).scheme != 'https' or host not in ALLOWED_HOSTS:
        raise SystemExit(f'fetch_champions_official: URL no permitida: {url}')
    for attempt in range(3):
        try:
            req = urllib.request.Request(url, headers={'User-Agent': USER_AGENT})
            with urllib.request.urlopen(req, timeout=30) as r:
                data = r.read(MAX_BYTES + 1)
            if len(data) > MAX_BYTES:
                raise SystemExit(f'fetch_champions_official: {url}: demasiado grande')
            return data
        except OSError as e:
            if attempt == 2:
                raise SystemExit(f'fetch_champions_official: {url}: {e}')
            time.sleep(5 * (attempt + 1))
    raise AssertionError


def main():
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    now = dt.datetime.now(dt.timezone.utc)
    files = {}
    try:
        feed = get(off.FEED_URL)
        files['list.json'] = feed
        regs = off.feed_to_fetch(off.parse_feed(feed.decode('utf-8')), now)
        for r in regs:
            page = get(off.page_url(r['id']))
            files[f'page_{r["id"]}.html'] = page
            p = off.parse_page(page.decode('utf-8'), r['id'])
            if p['eligibleUrl']:
                files[f'pokemon_{r["id"]}.html'] = get(p['eligibleUrl'])
            print(f'{p["officialName"]}: {p["startsAt"]:%Y-%m-%d %H:%M} – {p["endsAt"]:%Y-%m-%d %H:%M} UTC, '
                  f'lista: {"sí" if p["eligibleUrl"] else "no publicada"}', file=sys.stderr)
    except off.OfficialError as e:
        raise SystemExit(f'fetch_champions_official: {e}')
    for old in list(out.glob('page_*.html')) + list(out.glob('pokemon_*.html')):
        old.unlink()
    for name, data in files.items():
        (out / name).write_bytes(data)


if __name__ == '__main__':
    main()
