#!/usr/bin/env python3
"""Descarga de Pokémon Showdown los 3 archivos que lee tool/gen_champions_data.py.

  python3 tool/fetch_champions_sources.py .scratch/champions

Toma todo del mismo commit (la cabeza de `master` en ese momento) e imprime,
en formato `clave=valor` (sirve para $GITHUB_OUTPUT):
  commit=<sha del último commit que tocó alguno de los 3 archivos>
  date=<AAAA-MM-DD de ese commit>
Solo hace GET anónimos a GitHub (api.github.com y raw.githubusercontent.com).
"""
import json
import re
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

REPO = 'smogon/pokemon-showdown'
FILES = {
    'formats-data.ts': 'data/mods/champions/formats-data.ts',
    'formats.ts': 'config/formats.ts',
    'rulesets.ts': 'data/rulesets.ts',
}


def get(url: str) -> bytes:
    for attempt in range(3):
        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'gen-champions-data'})
            with urllib.request.urlopen(req, timeout=30) as r:
                return r.read()
        except OSError as e:
            if attempt == 2:
                raise SystemExit(f'fetch_champions_sources: {url}: {e}')
            time.sleep(5 * (attempt + 1))
    raise AssertionError


def api(path: str):
    return json.loads(get(f'https://api.github.com/repos/{REPO}/{path}'))


def main():
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    head = api('commits/master')['sha']
    if not re.fullmatch(r'[0-9a-f]{40}', head):
        raise SystemExit('fetch_champions_sources: sha no válido')
    latest = None
    for name, path in FILES.items():
        (out / name).write_bytes(get(f'https://raw.githubusercontent.com/{REPO}/{head}/{path}'))
        q = urllib.parse.urlencode({'sha': head, 'path': path, 'per_page': 1})
        c = api(f'commits?{q}')[0]
        sha, date = c['sha'], c['commit']['committer']['date']
        if latest is None or date > latest[1]:
            latest = (sha, date)
    sha, date = latest
    if not re.fullmatch(r'[0-9a-f]{40}', sha) or not re.match(r'\d{4}-\d{2}-\d{2}T', date):
        raise SystemExit('fetch_champions_sources: respuesta de la API no válida')
    print(f'commit={sha}')
    print(f'date={date[:10]}')


if __name__ == '__main__':
    main()
