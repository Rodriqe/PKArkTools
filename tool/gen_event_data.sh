#!/usr/bin/env bash
# Regenera la base de eventos (Mystery Gift) de pkcore desde PKHeX (oráculo
# tools/pkhex_oracle, comando events): datos fijos, tarjeta en bruto y
# plantillas legales con variantes PID/IV.
#
#   tool/gen_event_data.sh
#
# Requiere .NET SDK 10 y PKHeX en .ref/PKHeX (ver tools/pkhex_oracle/README.md).
# Commit de PKHeX usado: el que figura en .ref/PKHeX (ver NOTICE).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ ! -d "$ROOT/.ref/PKHeX/PKHeX.Core" ]; then
  echo "Falta PKHeX en .ref/PKHeX: git clone https://github.com/kwsch/PKHeX \"$ROOT/.ref/PKHeX\"" >&2
  exit 1
fi
export NUGET_PACKAGES="$ROOT/.ref/nuget" DOTNET_CLI_HOME="$ROOT/.scratch/dotnet-home"
export DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1 TMPDIR="$ROOT/.scratch/tmp"
OUT="$ROOT/.scratch/events"
mkdir -p "$OUT" "$TMPDIR"
dotnet build "$ROOT/tools/pkhex_oracle" -c Release -o "$ROOT/.scratch/oracle-bin" -v quiet -nologo >/dev/null
dotnet "$ROOT/.scratch/oracle-bin/PkhexOracle.dll" events "$OUT"
python3 "$ROOT/tool/gen_event_data.py" "$OUT/events.jsonl" \
  "$ROOT/packages/pkcore/lib/src/data/generated/event_data.dart"
