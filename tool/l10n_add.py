#!/usr/bin/env python3
"""Añade claves a app_es.arb / app_en.arb.

Uso: python3 tool/l10n_add.py claves.json
claves.json = {"clave": ["texto es", "texto en"], ...}; los marcadores {x}
se declaran como String (o int si el nombre empieza por n/count).
"""
import json, re, sys, os
ROOT = os.path.join(os.path.dirname(__file__), '..', 'apps', 'pkarktools', 'lib', 'l10n')
keys = json.load(open(sys.argv[1], encoding='utf-8'))
for idx, lang in enumerate(['es', 'en']):
    path = os.path.join(ROOT, f'app_{lang}.arb')
    data = json.load(open(path, encoding='utf-8'))
    for k, v in keys.items():
        data[k] = v[idx]
        if lang == 'es':
            ph = sorted(set(re.findall(r'\{(\w+)(?:,|\})', v[0])))
            if ph:
                data['@' + k] = {'placeholders': {p: {'type': 'int' if p in ('n', 'count') or p.startswith('n') and p[1:2].isupper() else 'String'} for p in ph}}
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write('\n')
