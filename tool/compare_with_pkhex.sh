#!/usr/bin/env bash
# Compara la lectura y la legalidad de pkcore con PKHeX (oráculo diferencial).
#
#   tool/compare_with_pkhex.sh <save> [--legality-detail]
#
# Requiere .NET SDK 10 y el código de PKHeX en .ref/PKHeX:
#   git clone https://github.com/kwsch/PKHeX .ref/PKHeX
# Los JSON se escriben en .scratch/compare/ (pueden contener datos personales).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SAVE="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
shift || true
if [ ! -d "$ROOT/.ref/PKHeX/PKHeX.Core" ]; then
  echo "Falta PKHeX en .ref/PKHeX. Clónalo con:" >&2
  echo "  git clone https://github.com/kwsch/PKHeX \"$ROOT/.ref/PKHeX\"" >&2
  exit 1
fi
export NUGET_PACKAGES="$ROOT/.ref/nuget" DOTNET_CLI_HOME="$ROOT/.scratch/dotnet-home"
export DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1 TMPDIR="$ROOT/.scratch/tmp"
export PUB_CACHE="${PUB_CACHE:-$ROOT/.pub-cache}"
OUT="$ROOT/.scratch/compare"
mkdir -p "$OUT" "$TMPDIR"
NAME="$(basename "$SAVE")"
NAME="${NAME//[^A-Za-z0-9._-]/_}"
dotnet build "$ROOT/tools/pkhex_oracle" -c Release -o "$OUT/oracle-bin" -v quiet -nologo >/dev/null
dotnet "$OUT/oracle-bin/PkhexOracle.dll" dump "$SAVE" "$OUT/$NAME.pkhex.json"
(cd "$ROOT/packages/pkcore" && dart run tool/pkhex_dump.dart "$SAVE" "$OUT/$NAME.pkcore.json")
python3 "$ROOT/tool/compare_with_pkhex.py" "$OUT/$NAME.pkcore.json" "$OUT/$NAME.pkhex.json" "$@"
