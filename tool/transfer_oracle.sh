#!/usr/bin/env bash
# Pasa los casos de transferencia de pkcore por PKHeX (EntityConverter + LegalityAnalysis)
# y regenera packages/pkcore/test/data/transfer_oracle.json.
#
#   tool/transfer_oracle.sh            usa los orígenes versionados
#   tool/transfer_oracle.sh --sources  los vuelve a generar con PKHeX
#
# Requiere .NET SDK 10 y PKHeX en .ref/PKHeX (ver tools/pkhex_oracle/README.md).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export NUGET_PACKAGES="$ROOT/.ref/nuget" DOTNET_CLI_HOME="$ROOT/.scratch/dotnet-home"
export DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1 TMPDIR="$ROOT/.scratch/tmp"
export PUB_CACHE="${PUB_CACHE:-$ROOT/.pub-cache}"
OUT="$ROOT/.scratch/transfer"
mkdir -p "$OUT/cases" "$TMPDIR"
dotnet build "$ROOT/tools/pkhex_oracle" -c Release -o "$OUT/oracle-bin" -v quiet -nologo >/dev/null
cd "$ROOT/packages/pkcore"
if [ "${1:-}" = "--sources" ]; then
  dart run tool/transfer_oracle.dart cases "$OUT/sources.json"
  dotnet "$OUT/oracle-bin/PkhexOracle.dll" transfersrc "$OUT/sources.json" test/data/transfer
fi
dart run tool/transfer_oracle.dart gen "$OUT/cases"
cp test/data/transfer/*.src.* "$OUT/cases/"
dotnet "$OUT/oracle-bin/PkhexOracle.dll" transfer "$OUT/cases/manifest.json" "$OUT/cases/oracle.json"
dart run tool/transfer_oracle.dart collect "$OUT/cases/oracle.json" test/data/transfer_oracle.json
