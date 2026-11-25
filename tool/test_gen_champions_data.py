#!/usr/bin/env python3
"""Tests de tool/gen_champions_data.py y tool/champions_official.py.

  python3 tool/test_gen_champions_data.py

Fuentes oficiales: copias reales en tool/fixtures/champions_official/
(descargadas el 2026-11-25: M-C vigente con su lista, M-D anunciada sin lista).
Showdown: archivos sintéticos y, si están descargados en .scratch/champions/
(o en $CHAMPIONS_SRC: el workflow champions-data.yml), los actuales.
"""
import datetime as dt
import json
import os
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
import champions_official as off  # noqa: E402
import gen_champions_data as gen  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
FIX = ROOT / 'tool/fixtures/champions_official'
CURRENT = Path(os.environ.get('CHAMPIONS_SRC') or ROOT / '.scratch/champions')
COMMIT = 'b3131aec41150c9a68f59224b6da2d6dc5901dc7'
NOW = '2026-11-25T12:00:00Z'
UTC = dt.timezone.utc

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
REG_MC_OLD = fmt('[Gen 9 Champions] VGC 2026 Reg M-C', 'championsregmc', extra="\n\t\tsearchShow: false,")
REG_MC_BO3 = fmt('[Gen 9 Champions] VGC 2026 Reg M-C (Bo3)', 'champions', "'Flat Rules', 'Best of = 3'")
REG_MB = fmt('[Gen 9 Champions] VGC 2026 Reg M-B', 'championsregmb', extra="\n\t\tsearchShow: false,")
REG_MD = fmt('[Gen 9 Champions] VGC 2027 Reg M-D', 'champions')


def species(names=None, n_natdex=900):
    out = ['export const FormatsData = {\n']
    for sid in names or [f'mon{i}' for i in range(200)]:
        out.append(f'\t{sid}: {{\n\t\ttier: "OU",\n\t\tdoublesTier: "DOU",\n\t\tnatDexTier: "OU",\n\t}},\n')
    # Solo de National Dex (Implement Champions National Dex, #12488).
    for i in range(n_natdex):
        out.append(f'\tpast{i}: {{\n\t\tisNonstandard: "Past",\n\t\ttier: "Illegal",\n\t\tnatDexTier: "OU",\n\t}},\n')
    out.append('\tgarchompmega: {\n\t\ttier: "OU",\n\t\tnatDexTier: "OU",\n\t},\n')
    if 'meganium' not in (names or []):
        out.append('\tmeganium: {\n\t\ttier: "OU",\n\t},\n')
    out.append('\tvenusaurgmax: {\n\t\ttier: "OU",\n\t},\n')
    out.append('\tfuturemega: {\n\t\tisNonstandard: "Future",\n\t\ttier: "Illegal",\n\t},\n')
    out.append('\tillegalmon: {\n\t\ttier: "Illegal",\n\t},\n')
    out.append('};\n')
    return ''.join(out)


def at(s):
    return gen._now(s)


def official_ids():
    return off.allowed_ids(off.parse_pokemons((FIX / 'pokemon_816.html').read_text(encoding='utf-8')))


# ------------------------------------------------------ fuentes oficiales

class OfficialParsers(unittest.TestCase):
    def test_feed(self):
        regs = off.parse_feed((FIX / 'list.json').read_text(encoding='utf-8'))
        self.assertEqual([(r['id'], r['code']) for r in regs], [('878', 'M-D'), ('816', 'M-C'), ('776', 'M-B'), ('751', 'M-A')])
        # Solo se descargan las que no han terminado: la vigente y la siguiente.
        self.assertEqual([r['code'] for r in off.feed_to_fetch(regs, at(NOW))], ['M-D', 'M-C'])
        self.assertEqual([r['code'] for r in off.feed_to_fetch(regs, at('2026-12-02T03:00:00Z'))], ['M-D'])
        for bad in ('no', '[]', '{"data": []}', '{"data": [{"infoKind": 3}]}',
                    '{"data": [{"id": "1", "infoKind": 12, "title": "Something else"}]}'):
            with self.assertRaises(off.OfficialError):
                off.parse_feed(bad)

    def test_page_current(self):
        p = off.parse_page((FIX / 'page_816.html').read_text(encoding='utf-8'), '816')
        self.assertEqual(p['code'], 'M-C')
        self.assertEqual(p['officialName'], 'Regulation Set M-C')
        self.assertEqual(p['startsAt'], dt.datetime(2026, 9, 9, 2, 0, tzinfo=UTC))
        self.assertEqual(p['endsAt'], dt.datetime(2026, 12, 2, 1, 59, tzinfo=UTC))
        self.assertEqual(p['eligibleUrl'],
                         'https://web-view.app.pokemonchampions.jp/battle/pages/events/rs178713870219xeaaio/en/pokemon.html')
        self.assertEqual(p['newMegas'], ['absolmegaz', 'salamencemega', 'garchompmegaz', 'lucariomegaz',
                                         'golisopodmega', 'baxcaliburmega'])

    def test_page_next_without_list(self):
        p = off.parse_page((FIX / 'page_878.html').read_text(encoding='utf-8'), '878')
        self.assertEqual(p['code'], 'M-D')
        self.assertEqual(p['startsAt'], dt.datetime(2026, 12, 2, 2, 0, tzinfo=UTC))
        self.assertEqual(p['endsAt'], dt.datetime(2027, 3, 3, 1, 59, tzinfo=UTC))
        self.assertIsNone(p['eligibleUrl'])
        self.assertEqual(p['newMegas'], ['heatranmega', 'tatsugirimega'])

    def test_page_rejects(self):
        page = (FIX / 'page_816.html').read_text(encoding='utf-8')
        with self.assertRaises(off.OfficialError):
            off.parse_page(page.replace('at 02:00 UTC', 'at 02:00'), '816')
        with self.assertRaises(off.OfficialError):
            off.parse_page(page.replace('Regulation Set M-C', 'Regulation'), '816')
        # Un enlace a otro dominio no cuenta como la lista oficial.
        evil = page.replace('web-view.app.pokemonchampions.jp', 'evil.example')
        self.assertIsNone(off.parse_page(evil, '816')['eligibleUrl'])

    def test_pokemons(self):
        entries = off.parse_pokemons((FIX / 'pokemon_816.html').read_text(encoding='utf-8'))
        self.assertEqual(len(entries), 262)
        self.assertEqual(entries[0], (3, 0, 'Venusaur'))
        for bad in ('<script>const x = 1;</script>', 'const pokemons = [];', 'const pokemons = [["0003-000",2,"Venusaur"]];',
                    'const pokemons = [["3-0",1,"Venusaur"]];', 'const pokemons = [nope];'):
            with self.assertRaises(off.OfficialError):
                off.parse_pokemons(bad)

    def test_mapping(self):
        m = off.map_pokemon
        self.assertEqual(m(83, 0, 'Farfetch’d'), ['farfetchd'])
        self.assertEqual(m(784, 0, 'Kommo-o'), ['kommoo'])
        self.assertEqual(m(122, 0, 'Mr. Mime'), ['mrmime'])
        self.assertEqual(m(479, 0, 'Rotom (Rotom)'), ['rotom'])
        self.assertEqual(m(479, 2, 'Rotom (Wash Rotom)'), ['rotomwash'])
        self.assertEqual(m(128, 2, 'Tauros (Paldean Form (Blaze Breed))'), ['taurospaldeablaze'])
        self.assertEqual(m(711, 3, 'Gourgeist (Jumbo Variety)'), ['gourgeistsuper'])
        self.assertEqual(m(678, 1, 'Meowstic (Female)'), ['meowsticf'])
        self.assertEqual(m(670, 5, 'Floette'), ['floetteeternal'])
        self.assertEqual(m(666, 18, 'Vivillon'), ['vivillon'])
        self.assertEqual(m(925, 1, 'Maushold'), ['maushold'])
        self.assertEqual(m(931, 2, 'Squawkabilly'), ['squawkabilly', 'squawkabillyblue', 'squawkabillyyellow', 'squawkabillywhite'])
        with self.assertRaises(off.OfficialError):
            m(1017, 1, 'Ogerpon (Wellspring Mask)')

    def test_mc_list_against_showdown_list_of_2_0(self):
        """La lista oficial de M-C frente a la de Showdown que llevaba la 2.0:
        igual salvo Meowstic hembra (en el juego es elegible; Showdown no la
        tiene en el mod) y las formas que solo existen en combate (Castform
        Sol/Lluvia/Nieve, Aegislash Filo), que la lista oficial no pone."""
        ids = official_ids()
        self.assertEqual(len(ids), 264)
        v2 = json.loads((ROOT / 'tool/fixtures/champions_showdown_2_0.json').read_text(encoding='utf-8'))['allowed']
        self.assertEqual(len(v2), 267)
        self.assertEqual(off.cross_check(ids, v2), (['meowsticf'], []))
        self.assertEqual(sorted(set(v2) - set(ids)), sorted(off.BATTLE_ONLY))


# ---------------------------------------------------------------- build

class Build(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(dir=ROOT / '.scratch' if (ROOT / '.scratch').is_dir() else None)
        self.dir = Path(self.tmp.name)
        self.off = self.dir / 'official'
        shutil.copytree(FIX, self.off)
        self.src = self.dir / 'src'
        self.src.mkdir()
        self.write(formats(NATDEX, REG_MC, REG_MC_BO3, REG_MB), species([i for i in official_ids() if i != 'meowsticf'] + ['castformsunny']))

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, fmts, data):
        (self.src / 'formats.ts').write_text(fmts)
        (self.src / 'formats-data.ts').write_text(data)
        (self.src / 'rulesets.ts').write_text(RULESETS)

    def showdown(self, commit=COMMIT):
        return gen.read_showdown(self.src, commit, '2026-11-25')

    def run_gen(self, *extra, now=NOW, showdown=True):
        out, dart = self.dir / 'out.json', self.dir / 'out.dart'
        args = ['--official', str(self.off), '--json', str(out), '--dart', str(dart), '--now', now]
        if showdown:
            args += ['--showdown', str(self.src), '--commit', COMMIT, '--date', '2026-11-25']
        return gen.main(args + list(extra)), out, dart

    def test_showdown_vgc_list_not_national_dex(self):
        self.write(formats(NATDEX, REG_MC, REG_MC_BO3, REG_MB), species())
        s = self.showdown()
        self.assertEqual((s['code'], s['name']), ('M-C', 'VGC 2026 Reg M-C'))
        self.assertEqual(s['ruleset'], ['Flat Rules', 'VGC Timer', 'Open Team Sheets'])
        self.assertEqual(len(s['allowed']), 201)  # 200 + meganium
        self.assertIn('meganium', s['allowed'])
        self.assertFalse(any(x.startswith('past') for x in s['allowed']))
        self.assertNotIn('venusaurgmax', s['allowed'])
        self.assertNotIn('illegalmon', s['allowed'])
        self.assertEqual(s['megas'], ['garchompmega'])
        with self.assertRaises(gen.GenError):
            gen.read_showdown(self.src, 'x', '2026-11-25')
        self.write(formats(NATDEX), species())
        with self.assertRaises(gen.GenError):
            self.showdown()

    def test_current_and_next(self):
        d, warnings = gen.build(self.off, self.showdown(), None, at(NOW), NOW)
        r, n = d['regulation'], d['nextRegulation']
        self.assertEqual((r['code'], r['name'], r['from'], r['until']), ('M-C', 'VGC 2026 Reg M-C', '2026-09-09', '2026-12-02'))
        self.assertTrue(r['datesConfirmed'])
        self.assertEqual(r['datesSource'], 'https://champions-news.pokemon-home.com/en/page/816.html')
        self.assertEqual((r['startsAt'], r['endsAt']), ('2026-09-09T02:00:00Z', '2026-12-02T01:59:00Z'))
        self.assertEqual(r['allowedSource'], 'official')
        self.assertEqual((n['code'], n['name'], n['from'], n['until']), ('M-D', 'VGC 2026 Reg M-D', '2026-12-02', '2027-03-03'))
        self.assertTrue(n['datesConfirmed'])
        self.assertFalse(n['allowedPublished'])
        # Solo la vigente y la siguiente; nada de M-A ni M-B.
        self.assertEqual([x['code'] for x in d['regulations']], ['M-C', 'M-D'])
        self.assertEqual(d['allowed'], official_ids())
        self.assertIn('garchompmega', d['megas'])
        self.assertIn('salamencemega', d['megas'])  # Mega nueva oficial que no está en el Showdown sintético
        self.assertEqual(d['source']['commit'], COMMIT)
        self.assertEqual(d['official']['feed'], off.FEED_URL)
        self.assertTrue(any('meowsticf' in w for w in warnings))  # diferencia con Showdown: aviso

    def test_switches_by_date(self):
        d, _ = gen.build(self.off, self.showdown(), None, at('2026-12-02T01:59:59Z'), 'x')
        self.assertEqual(d['regulation']['code'], 'M-C')
        # Desde las 02:00 UTC del 2 de diciembre vale M-D; su lista no está
        # publicada ni Showdown la tiene: error, no se inventa.
        with self.assertRaises(gen.GenError):
            gen.build(self.off, self.showdown(), None, at('2026-12-02T02:00:00Z'), 'x')
        # Si Showdown ya está en M-D, se usa su lista (marcada) mientras no
        # haya oficial, sin las formas de combate.
        self.write(formats(REG_MD, REG_MC_OLD), species(official_ids() + ['heatran', 'castformsunny']))
        d, warnings = gen.build(self.off, self.showdown(), None, at('2026-12-02T02:30:00Z'), 'x')
        self.assertEqual(d['regulation']['code'], 'M-D')
        self.assertEqual(d['regulation']['name'], 'VGC 2027 Reg M-D')
        self.assertEqual(d['regulation']['allowedSource'], 'showdown')
        self.assertIn('heatran', d['allowed'])
        self.assertNotIn('castformsunny', d['allowed'])
        self.assertIn('heatranmega', d['megas'])
        self.assertIsNone(d['nextRegulation'])
        self.assertEqual([x['code'] for x in d['regulations']], ['M-D'])
        self.assertTrue(any('no está publicada' in w for w in warnings))

    def test_official_list_of_next_when_published(self):
        page = (self.off / 'page_878.html').read_text(encoding='utf-8')
        url = 'https://web-view.app.pokemonchampions.jp/battle/pages/events/rsmdtest/en/pokemon.html'
        (self.off / 'page_878.html').write_text(page.replace(
            'Pokémon that will newly appear', f'<a class="btn-link" href="{url}">Eligible Pokémon</a><br />Pokémon that will newly appear'))
        pk = (self.off / 'pokemon_816.html').read_text(encoding='utf-8')
        (self.off / 'pokemon_878.html').write_text(pk.replace('const pokemons = [', 'const pokemons = [["0485-000",1,"Heatran"],'))
        d, _ = gen.build(self.off, self.showdown(), None, at(NOW), 'x')
        self.assertTrue(d['nextRegulation']['allowedPublished'])
        self.assertNotIn('heatran', d['allowed'])  # la siguiente no cuenta antes de empezar
        d, _ = gen.build(self.off, self.showdown(), None, at('2026-12-02T02:30:00Z'), 'x')
        self.assertEqual(d['regulation']['allowedSource'], 'official')
        self.assertEqual(d['allowed'][0], 'heatran')
        self.assertEqual(d['official']['eligibleUrl'], url)

    def test_without_showdown_uses_last_json(self):
        prev, _ = gen.build(self.off, self.showdown(), None, at(NOW), NOW)
        d, warnings = gen.build(self.off, None, prev, at(NOW), NOW)
        self.assertEqual(d['source'], prev['source'])
        self.assertEqual(d['flatRules'], prev['flatRules'])
        self.assertEqual(d['allowed'], prev['allowed'])
        self.assertTrue(any('Showdown no disponible' in w for w in warnings))
        with self.assertRaises(gen.GenError):
            gen.build(self.off, None, None, at(NOW), NOW)

    def test_main_writes_json_and_dart(self):
        code, out, dart = self.run_gen()
        self.assertEqual(code, 0)
        self.assertIn(out.read_text(), dart.read_text())
        gen.validate(json.loads(out.read_text()))

    def test_unchanged_data_keeps_file(self):
        self.run_gen()
        _, out, _ = self.run_gen()
        before = out.read_text()
        self.run_gen(now='2026-11-26T02:30:00Z')
        self.assertEqual(out.read_text(), before)
        # Un commit nuevo de Showdown que no cambia los datos tampoco.
        gen.main(['--official', str(self.off), '--showdown', str(self.src), '--commit', 'f' * 40, '--date', '2026-12-01',
                  '--json', str(out), '--no-dart', '--now', NOW])
        self.assertEqual(out.read_text(), before)

    def test_fails_without_writing(self):
        # Sin lista para M-D (después del cambio).
        code, out, dart = self.run_gen(now='2026-12-02T02:30:00Z')
        self.assertEqual(code, 1)
        self.assertFalse(out.exists() or dart.exists())
        # Feed roto.
        (self.off / 'list.json').write_text('<html>error</html>')
        code, out, dart = self.run_gen()
        self.assertEqual(code, 1)
        self.assertFalse(out.exists() or dart.exists())

    def test_keeps_last_good_json(self):
        code, out, _ = self.run_gen()
        good = out.read_text()
        (self.off / 'pokemon_816.html').write_text('<html>const pokemons = [];</html>')
        code, out, _ = self.run_gen()
        self.assertEqual(code, 1)
        self.assertEqual(out.read_text(), good)

    def test_validate(self):
        d, _ = gen.build(self.off, self.showdown(), None, at(NOW), NOW)
        gen.validate(d)
        for bad in (
            {**d, 'schemaVersion': 2},
            {**d, 'allowed': []},
            {**d, 'allowed': d['allowed'] + ['garchompmega']},
            {**d, 'source': {**d['source'], 'commit': 'x'}},
            {**d, 'source': {**d['source'], 'url': 'https://champions-news.pokemon-home.com/'}},
            {**d, 'regulation': {**d['regulation'], 'from': None}},
            {**d, 'regulation': {**d['regulation'], 'name': 'Regulation Set M-C'}},
            {**d, 'regulation': {**d['regulation'], 'startsAt': '2026-09-09'}},
        ):
            with self.assertRaises(gen.GenError):
                gen.validate(bad)


@unittest.skipUnless((CURRENT / 'formats-data.ts').exists(), 'no hay archivos de Showdown en .scratch/champions')
class CurrentShowdown(unittest.TestCase):
    def test_current_files(self):
        s = gen.read_showdown(CURRENT, COMMIT, '2026-11-25')
        self.assertRegex(s['name'], r'^VGC \d{4} Reg ')
        self.assertIn('garchompmega', s['megas'])
        self.assertNotIn('bulbasaur', s['allowed'])  # solo National Dex
        self.assertLess(len(s['allowed']), 400)
        if s['code'] == 'M-C':
            # Las únicas diferencias con la lista oficial de M-C.
            self.assertEqual(off.cross_check(official_ids(), s['allowed']), (['meowsticf'], []))


class Committed(unittest.TestCase):
    def test_committed_json_is_valid(self):
        d = json.loads(gen.DEFAULT_JSON.read_text(encoding='utf-8'))
        gen.validate(d)
        self.assertTrue(d['regulation']['datesConfirmed'])
        self.assertTrue(d['regulation']['datesSource'].startswith(off.NEWS_BASE))


if __name__ == '__main__':
    unittest.main()
