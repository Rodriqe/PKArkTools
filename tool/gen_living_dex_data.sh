#!/usr/bin/env bash
# Regenera la tabla de la Living Dex de pkcore desde PKHeX (oráculo
# tools/pkhex_oracle, comando livingdex): por versión/especie/forma, un Pokémon
# legal de un encuentro real de esa versión y el modo de re-ID que acepta PKHeX.
#
#   tool/gen_living_dex_data.sh
#
# Requiere .NET SDK 10 y PKHeX en .ref/PKHeX (ver tools/pkhex_oracle/README.md).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export NUGET_PACKAGES="$ROOT/.ref/nuget" DOTNET_CLI_HOME="$ROOT/.scratch/dotnet-home"
export DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1 TMPDIR="$ROOT/.scratch/tmp"
OUT="$ROOT/.scratch/livingdex"
mkdir -p "$OUT" "$TMPDIR"
dotnet build "$ROOT/tools/pkhex_oracle" -c Release -o "$ROOT/.scratch/oracle-bin" -v quiet -nologo >/dev/null
dotnet "$ROOT/.scratch/oracle-bin/PkhexOracle.dll" livingdex "$OUT"
python3 "$ROOT/tool/gen_living_dex_data.py" "$OUT/livingdex.jsonl" \
  "$ROOT/packages/pkcore/lib/src/data/generated/living_dex_data.dart"
