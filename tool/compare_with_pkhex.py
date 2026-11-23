#!/usr/bin/env python3
"""Compara dos volcados JSON (pkcore vs. oráculo PKHeX) campo por campo.

Uso: python3 tool/compare_with_pkhex.py pkcore.json pkhex.json [--legality-detail]

Lectura: toda diferencia es un bug de pkcore (salvo campos que pkcore no lee,
marcados como null en su volcado). Legalidad: lista falsos positivos (pkcore
avisa y PKHeX da el Pokémon por válido) y falsos negativos (PKHeX lo marca
ilegal y pkcore no emite ningún aviso de severidad «warning»).
"""
import collections
import json
import sys

LEGALITY = 'legality'

# Glifos de uso privado de Gen 8+ para ♂/♀ (PKHeX los conserva; pkcore los normaliza).
GLYPHS = str.maketrans({'\ue08e': '♂', '\ue08f': '♀'})


def norm(v):
    return v.translate(GLYPHS) if isinstance(v, str) else v


def pkhex_flags(issues, our):
    """¿PKHeX marca como inválido/dudoso el mismo aspecto que el aviso [our] de pkcore?"""
    code, field = our['code'], our.get('id') or ''
    # Motivos de PKHeX que no dicen nada del aspecto concreto (rastreador de HOME, basura en cadenas).
    unrelated = {'TransferTrackerMissing', 'TrashBytesShouldBeEmpty'}
    bad = [i for i in issues if i['severity'] in ('Invalid', 'Fishy') and i['code'] not in unrelated]
    ids = {i['id'] for i in bad}
    if code == 'ppTooHigh':
        return 'CurrentMove' in ids or any(i['code'].startswith('MovePPTooHigh') for i in bad)
    if code == 'moveDuplicate':  # PKHeX marca la primera aparición; pkcore, la repetida
        return any(i['code'] == 'Duplicate' for i in bad)
    if code in ('moveNotLearnable', 'moveNotInGame', 'noMoves'):
        n = field[-1:] if field.startswith('move') else ''
        return f'Move{n}' in ids if n else any(i.startswith('Move') or i == 'CurrentMove' for i in ids)
    if code == 'relearnInvalid':
        return any(i.startswith('Relearn') for i in ids)
    if code.startswith('encounter') or code in ('eventSpeciesNotFateful', 'speciesNotInGame', 'metLevelInvalid'):
        return bool(ids & {'Encounter', 'Level', 'Fateful', 'GameOrigin', 'Form'})
    if code == 'metDateInvalid':
        return any(i['code'] == 'DateCalendarInvalidMet' for i in bad)
    if code == 'obedienceLevelInvalid':
        return any(i['code'] == 'TransferObedienceLevel' for i in bad)
    if code == 'shinyLocked':
        return bool(ids & {'Shiny', 'PID'})
    if code.startswith('ball') or code == 'cherishWithoutEvent':
        return 'Ball' in ids
    if code.startswith('ability') or code == 'hiddenAbilityOldOrigin':
        return 'Ability' in ids
    return bool(bad)


def load(path):
    with open(path, encoding='utf-8') as f:
        return json.load(f)


def r_issues_of(r):
    return r[LEGALITY]['issues']


def main():
    ours, ref = load(sys.argv[1]), load(sys.argv[2])
    detail = '--legality-detail' in sys.argv
    diffs = []

    print(f"== Save: pkcore={ours['game']} pkhex={ref['game']}  checksums pkcore={ours['checksumsValid']} pkhex={ref['checksumsValid']}")
    if ours['checksumsValid'] != ref['checksumsValid']:
        diffs.append(('save', 'checksumsValid', ours['checksumsValid'], ref['checksumsValid']))

    for k, v in ref['trainer'].items():
        o = ours['trainer'].get(k)
        if o is None and v is not None:
            print(f"   (pkcore no lee trainer.{k}; PKHeX={v})")
        elif o != v:
            diffs.append(('trainer', k, o, v))

    o_slots = {s['slot']: s for s in ours['slots']}
    r_slots = {s['slot']: s for s in ref['slots']}
    print(f"== Pokémon: pkcore={len(o_slots)} pkhex={len(r_slots)}")
    for slot in sorted(set(o_slots) | set(r_slots)):
        o, r = o_slots.get(slot), r_slots.get(slot)
        if o is None or r is None:
            diffs.append((slot, 'presencia', o is not None, r is not None))
            continue
        for k, v in r.items():
            if k in (LEGALITY, 'slot'):
                continue
            if norm(o.get(k)) != norm(v):
                diffs.append((slot, k, o.get(k), v))

    oi, ri = ours.get('items') or {}, ref.get('items') or {}
    for k in sorted(set(oi) | set(ri), key=int):
        if oi.get(k) != ri.get(k):
            diffs.append(('items', k, oi.get(k), ri.get(k)))

    od, rd = ours.get('pokedex') or {}, ref.get('pokedex') or {}
    for kind in ('seen', 'caught'):
        a, b = set(od.get(kind, [])), set(rd.get(kind, []))
        if a != b:
            diffs.append(('pokedex', kind, sorted(a - b)[:20], sorted(b - a)[:20]))

    print(f"== Diferencias de lectura: {len(diffs)}")
    by_field = collections.Counter(d[1] for d in diffs)
    for field, n in by_field.most_common():
        print(f"   {field}: {n}")
    for d in diffs[:60]:
        print(f"   {d[0]:>14} {d[1]:<14} pkcore={d[2]!r} pkhex={d[3]!r}")

    # ---------------------------------------------------------- legalidad
    # Falso positivo: un aviso de pkcore sobre algo que PKHeX da por bueno.
    # Falso negativo: PKHeX marca el Pokémon inválido y pkcore no emite ningún «warning».
    fp, fn = [], []
    fp_codes, fn_codes = collections.Counter(), collections.Counter()
    pkhex_invalid = both = 0
    for slot, r in r_slots.items():
        o = o_slots.get(slot)
        if o is None:
            continue
        r_issues = r[LEGALITY]['issues']
        o_issues = o[LEGALITY]['issues']
        for i in o_issues:
            if not pkhex_flags(r_issues, i):
                fp.append((slot, i, o, r))
                fp_codes[f"{i['code']}({i['severity']})"] += 1
        o_warn = [i for i in o_issues if i['severity'] == 'warning']
        if not r[LEGALITY]['valid']:
            pkhex_invalid += 1
            if o_warn:
                both += 1
            else:
                fn.append((slot, o, r))
                fn_codes.update({i['code'] for i in r_issues if i['severity'] == 'Invalid'})
    print(f"== Legalidad: PKHeX inválidos={pkhex_invalid}; pkcore también avisa={both}; "
          f"avisos pkcore sin respaldo de PKHeX (falsos positivos)={len(fp)}; "
          f"inválidos PKHeX sin aviso pkcore (falsos negativos)={len(fn)}")
    print(f"   falsos positivos por código: {dict(fp_codes)}")
    print(f"   falsos negativos, códigos PKHeX: {dict(fn_codes.most_common())}")
    if detail:
        for slot, i, o, r in fp:
            ref_s = ', '.join(f"{x['id']}:{x['code']}" for x in r_issues_of(r)) or '-'
            print(f"   FP {slot} #{r['species']} v{r['version']} loc={r['metLocation']} lv={r['metLevel']} "
                  f"[{r[LEGALITY].get('encounter')}] pkcore: {i['code']}({i['severity']}) {i.get('id')} | pkhex: {ref_s}")
        for slot, o, r in fn:
            ref_s = ', '.join(f"{x['id']}:{x['code']}" for x in r_issues_of(r) if x['severity'] == 'Invalid')
            print(f"   FN {slot} #{r['species']} v{r['version']} pkhex: {ref_s}")
    return 1 if diffs else 0


if __name__ == '__main__':
    sys.exit(main())
