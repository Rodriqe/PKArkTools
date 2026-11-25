#!/usr/bin/env bash
# Comprueba con PKHeX la Living Dex que genera pkcore: la genera completa
# (normal con un entrenador, variocolor con otro) en saves sintéticos de cada
# versión de los juegos principales, la lee de vuelta del save, escribe cada
# Pokémon como archivo suelto y cuenta los que `LegalityAnalysis` da por inválidos.
#
#   tool/check_living_dex_pkhex.sh            # resumen por juego
#   tool/check_living_dex_pkhex.sh --detail   # además cada Pokémon inválido
#
# Requiere .NET SDK 10 y PKHeX en .ref/PKHeX (ver tools/pkhex_oracle/README.md).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export NUGET_PACKAGES="$ROOT/.ref/nuget" DOTNET_CLI_HOME="$ROOT/.scratch/dotnet-home"
export DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1 TMPDIR="$ROOT/.scratch/tmp"
OUT="$ROOT/.scratch/livingdex_check"
rm -rf "$OUT" && mkdir -p "$OUT/pk" "$TMPDIR"
dotnet build "$ROOT/tools/pkhex_oracle" -c Release -o "$ROOT/.scratch/oracle-bin" -v quiet -nologo >/dev/null
(cd "$ROOT/packages/pkcore" && LIVINGDEX_OUT="$OUT/pk" dart test test/living_dex_test.dart -n "oráculo" >/dev/null)
dotnet "$ROOT/.scratch/oracle-bin/PkhexOracle.dll" legal "$OUT/pk" "$OUT/legal.jsonl"
python3 - "$OUT/legal.jsonl" "${1:-}" <<'PY'
import collections, json, sys
rows = [json.loads(l) for l in open(sys.argv[1])]
detail = sys.argv[2] == '--detail'
by = collections.Counter(); bad = collections.Counter(); fishy = collections.Counter(); shiny = collections.Counter()
for r in rows:
    k = r['file'].split('_')[1] + ('/variocolor' if r['file'].split('_')[2] == '1' else '/normal')
    by[k] += 1
    if r.get('shiny'): shiny[k] += 1
    if not r['valid']:
        bad[k] += 1
        if detail:
            print('  ' + r['file'] + ': ' + '; '.join(i for i in r.get('issues', []) if i.startswith('Invalid')) + r.get('error', ''))
    elif any(i.startswith('Fishy') for i in r.get('issues', [])):
        fishy[k] += 1
        if detail:
            print('  (fishy) ' + r['file'] + ': ' + '; '.join(i for i in r.get('issues', []) if i.startswith('Fishy')))
for k in sorted(by):
    print(f'{k}: {by[k]} Pokémon ({shiny[k]} variocolor), {bad[k]} inválidos, {fishy[k]} Fishy')
print(f'TOTAL: {len(rows)} Pokémon, {sum(bad.values())} inválidos para PKHeX, {sum(fishy.values())} con avisos Fishy')
sys.exit(1 if bad else 0)
PY
