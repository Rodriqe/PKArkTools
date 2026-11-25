#!/usr/bin/env bash
# Comprueba con PKHeX los Pokémon de evento que crea pkcore: crea todos los
# eventos creables de cada formato (Gen 3–9) para dos entrenadores distintos
# (idioma, ID, género y petición de variocolor distintos), los escribe como
# archivos sueltos y cuenta los que `LegalityAnalysis` da por inválidos.
#
#   tool/check_events_pkhex.sh            # resumen
#   tool/check_events_pkhex.sh --detail   # además cada Pokémon inválido
#
# Requiere .NET SDK 10 y PKHeX en .ref/PKHeX o en $PKHEX_DIR (ver
# tools/pkhex_oracle/README.md).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKHEX_DIR="${PKHEX_DIR:-$ROOT/.ref/PKHeX}"
BIN="${ORACLE_BIN:-$ROOT/.scratch/oracle-bin}"
export NUGET_PACKAGES="${NUGET_PACKAGES:-$ROOT/.ref/nuget}" DOTNET_CLI_HOME="${DOTNET_CLI_HOME:-$ROOT/.scratch/dotnet-home}"
export DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1 TMPDIR="$ROOT/.scratch/tmp"
OUT="$ROOT/.scratch/events_check"
rm -rf "$OUT" && mkdir -p "$OUT/pk" "$TMPDIR"
dotnet build "$ROOT/tools/pkhex_oracle" -c Release -o "$BIN" -p:PkhexDir="$PKHEX_DIR" -v quiet -nologo >/dev/null
(cd "$ROOT/packages/pkcore" && EVENTS_OUT="$OUT/pk" dart test test/events_test.dart -n "oráculo" >/dev/null)
dotnet "$BIN/PkhexOracle.dll" legal "$OUT/pk" "$OUT/legal.jsonl"
python3 - "$OUT/legal.jsonl" "${1:-}" <<'PY'
import collections, json, sys
rows = [json.loads(l) for l in open(sys.argv[1])]
detail = sys.argv[2] == '--detail'
by = collections.Counter(); bad = collections.Counter(); fishy = 0
for r in rows:
    k = r['file'].split('_')[1]
    by[k] += 1
    if not r['valid']:
        bad[k] += 1
        if detail:
            print('  ' + r['file'] + ': ' + '; '.join(i for i in r.get('issues', []) if i.startswith('Invalid')) + r.get('error', ''))
    elif any(i.startswith('Fishy') for i in r.get('issues', [])):
        fishy += 1
for k in sorted(by):
    print(f'{k}: {by[k]} Pokémon, {bad[k]} inválidos')
print(f'TOTAL: {len(rows)} Pokémon de evento, {sum(bad.values())} inválidos para PKHeX, {fishy} con avisos Fishy')
sys.exit(1 if bad else 0)
PY
