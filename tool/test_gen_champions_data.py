#!/usr/bin/env python3
"""Tests de tool/gen_champions_data.py.

  python3 tool/test_gen_champions_data.py

Con archivos sintéticos (siempre) y, si están descargados en
.scratch/champions/ (formats-data.ts, formats.ts, rulesets.ts), contra los de
Showdown actuales (o en $CHAMPIONS_SRC: el workflow champions-data.yml).
"""
import json
import os
import re
import sys
import tempfile
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_champions_data as gen  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
CURRENT = Path(os.environ.get('CHAMPIONS_SRC') or ROOT / '.scratch/champions')
COMMIT = 'b3131aec41150c9a68f59224b6da2d6dc5901dc7'

RULESETS = '''export const Rulesets = {
\tflatrules: {
\t\teffectType: 'ValidatorRule',
\t\tname: 'Flat Rules',
\t\tdesc: "Enforces in-game Flat Rules",
\t\truleset: ['Obtainable', 'Team Preview', 'Species Clause', 'Nickname Clause', 'Item Clause = 1', 'Adjust Level Down = 50', 'Picked Team Size = Auto', 'Cancel Mod'],
\t\tbanlist: ['Mythical', 'Restricted Legendary', 'Greninja-Bond'],
\t},
};
'''


def formats(*blocks):
    return 'export const Formats = [\n' + ''.join(blocks) + '];\n'


def fmt(name, mod, ruleset="'Flat Rules', 'VGC Timer', 'Open Team Sheets'", extra=''):
    return f'''\t{{
\t\tname: "{name}",
\t\tmod: '{mod}',
\t\tgameType: 'doubles',{extra}
\t\truleset: [{ruleset}],
\t}},
'''


NATDEX = fmt('[Gen 9 Champions] National Dex', 'champions', "'Standard NatDex'")
REG_MC = fmt('[Gen 9 Champions] VGC 2026 Reg M-C', 'champions')
REG_MC_BO3 = fmt('[Gen 9 Champions] VGC 2026 Reg M-C (Bo3)', 'champions', "'Flat Rules', 'Best of = 3'")
REG_MB = fmt('[Gen 9 Champions] VGC 2026 Reg M-B', 'championsregmb', extra="\n\t\tsearchShow: false,")
REG_MD = fmt('[Gen 9 Champions] VGC 2026 Reg M-D', 'championsregmd', extra="\n\t\tsearchShow: false,")


def species(n_legal=200, n_natdex=900):
    out = ['export const FormatsData = {\n']
    for i in range(n_legal):
        out.append(f'\tmon{i}: {{\n\t\ttier: "OU",\n\t\tdoublesTier: "DOU",\n\t\tnatDexTier: "OU",\n\t}},\n')
    # Solo de National Dex (Implement Champions National Dex, #12488).
    for i in range(n_natdex):
        out.append(f'\tpast{i}: {{\n\t\tisNonstandard: "Past",\n\t\ttier: "Illegal",\n\t\tnatDexTier: "OU",\n\t}},\n')
    out.append('\tgarchompmega: {\n\t\ttier: "OU",\n\t\tnatDexTier: "OU",\n\t},\n')
    out.append('\tmeganium: {\n\t\ttier: "OU",\n\t},\n')
    out.append('\tvenusaurgmax: {\n\t\ttier: "OU",\n\t},\n')
    out.append('\tfuturemega: {\n\t\tisNonstandard: "Future",\n\t\ttier: "Illegal",\n\t},\n')
    out.append('\tillegalmon: {\n\t\ttier: "Illegal",\n\t},\n')
    out.append('};\n')
    return ''.join(out)


DATES = {'regulations': [
    {'code': 'M-B', 'from': '2026-06-17', 'until': '2026-09-02', 'source': 'test', 'confirmed': False},
    {'code': 'M-C', 'from': '2026-09-09', 'until': '2026-12-02', 'source': 'test', 'confirmed': False},
]}


class Synthetic(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(dir=ROOT / '.scratch' if (ROOT / '.scratch').is_dir() else None)
        self.dir = Path(self.tmp.name)
        self.src = self.dir / 'src'
        self.src.mkdir()
        self.dates = self.dir / 'dates.json'
        self.dates.write_text(json.dumps(DATES))
        self.write(formats(NATDEX, REG_MC, REG_MC_BO3, REG_MB))

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, fmts, data=None):
        (self.src / 'formats.ts').write_text(fmts)
        (self.src / 'formats-data.ts').write_text(data or species())
        (self.src / 'rulesets.ts').write_text(RULESETS)

    def run_gen(self, *extra):
        out = self.dir / 'out.json'
        dart = self.dir / 'out.dart'
        code = gen.main([str(self.src), COMMIT, '2026-11-25', '--json', str(out), '--dart', str(dart),
                         '--dates', str(self.dates), '--today', '2026-11-25', *extra])
        return code, out, dart

    def test_vgc_list_not_national_dex(self):
        code, out, dart = self.run_gen()
        self.assertEqual(code, 0)
        d = json.loads(out.read_text())
        self.assertEqual(d['regulation']['name'], 'VGC 2026 Reg M-C')
        self.assertEqual(d['regulation']['until'], '2026-12-02')
        self.assertFalse(d['regulation']['datesConfirmed'])
        self.assertIsNone(d['nextRegulation'])
        self.assertEqual(d['ruleset'], ['Flat Rules', 'VGC Timer', 'Open Team Sheets'])
        self.assertEqual(len(d['allowed']), 201)  # 200 + meganium
        self.assertIn('meganium', d['allowed'])
        self.assertFalse(any(x.startswith('past') for x in d['allowed']))
        self.assertNotIn('venusaurgmax', d['allowed'])
        self.assertNotIn('illegalmon', d['allowed'])
        self.assertEqual(d['megas'], ['garchompmega'])
        self.assertEqual(d['source']['commit'], COMMIT)
        self.assertIn(out.read_text(), dart.read_text())

    def test_next_regulation(self):
        self.write(formats(NATDEX, REG_MC, REG_MD, REG_MB))
        code, out, _ = self.run_gen()
        self.assertEqual(code, 0)
        d = json.loads(out.read_text())
        self.assertEqual(d['regulation']['code'], 'M-C')
        self.assertEqual(d['nextRegulation']['code'], 'M-D')
        self.assertIsNone(d['nextRegulation']['from'])  # sin fechas en la tabla

    def test_unchanged_data_keeps_file(self):
        _, out, _ = self.run_gen()
        d = json.loads(out.read_text())
        d['generatedAt'] = '2000-01-01T00:00:00Z'
        out.write_text(gen.dump_json(d))
        before = out.read_text()
        self.run_gen()
        self.assertEqual(out.read_text(), before)
        # Un commit nuevo de Showdown que no cambia los datos tampoco.
        gen.main([str(self.src), 'f' * 40, '2026-12-01', '--json', str(out), '--dart', str(self.dir / 'o.dart'),
                  '--dates', str(self.dates), '--today', '2026-11-25'])
        self.assertEqual(out.read_text(), before)
        # Si cambian los datos, sí (con el commit nuevo).
        self.write(formats(REG_MC), species(n_legal=199))
        gen.main([str(self.src), 'f' * 40, '2026-12-01', '--json', str(out), '--dart', str(self.dir / 'o.dart'),
                  '--dates', str(self.dates), '--today', '2026-11-25'])
        self.assertEqual(json.loads(out.read_text())['source']['commit'], 'f' * 40)

    def test_fails_without_writing(self):
        # Formato irreconocible.
        self.write(formats(NATDEX))
        code, out, dart = self.run_gen()
        self.assertEqual(code, 1)
        self.assertFalse(out.exists() or dart.exists())
        # Lista de National Dex (todo legal): fuera del rango esperado.
        self.write(formats(REG_MC), species(n_legal=1100, n_natdex=0))
        code, out, _ = self.run_gen()
        self.assertEqual(code, 1)
        self.assertFalse(out.exists())

    def test_validate(self):
        _, out, _ = self.run_gen()
        d = json.loads(out.read_text())
        gen.validate(d)
        for bad in (
            {**d, 'schemaVersion': 2},
            {**d, 'allowed': []},
            {**d, 'allowed': d['allowed'] + ['garchompmega']},
            {**d, 'source': {**d['source'], 'commit': 'x'}},
            {**d, 'regulation': {**d['regulation'], 'from': None}},
        ):
            with self.assertRaises(gen.GenError):
                gen.validate(bad)


@unittest.skipUnless((CURRENT / 'formats-data.ts').exists(), 'no hay archivos de Showdown en .scratch/champions')
class CurrentShowdown(unittest.TestCase):
    def test_current_files(self):
        d = gen.build(CURRENT, COMMIT, '2026-11-25', gen.DEFAULT_DATES, '2026-11-25', 'now')
        self.assertRegex(d['regulation']['name'], r'^VGC \d{4} Reg ')
        self.assertIn('garchomp', d['allowed'])
        self.assertIn('garchompmega', d['megas'])
        self.assertNotIn('bulbasaur', d['allowed'])  # solo National Dex
        self.assertLess(len(d['allowed']), 400)


class Committed(unittest.TestCase):
    def test_committed_json_is_valid(self):
        gen.validate(json.loads(gen.DEFAULT_JSON.read_text(encoding='utf-8')))


if __name__ == '__main__':
    unittest.main()
