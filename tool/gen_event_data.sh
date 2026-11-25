#!/usr/bin/env bash
# Regenera la base de eventos (Mystery Gift) desde PKHeX (oráculo
# tools/pkhex_oracle, comando events): datos fijos, tarjeta en bruto y
# plantillas legales con variantes PID/IV. Escribe:
#   * data/events/events.json (la app la descarga; la actualiza
#     .github/workflows/events-data.yml)
#   * packages/pkcore/lib/src/data/generated/event_data.dart (copia integrada)
#
#   tool/gen_event_data.sh
#   PKHEX_DIR=/otra/copia/de/PKHeX tool/gen_event_data.sh
#   EVENTS_FRESH=1 tool/gen_event_data.sh   # sin reutilizar entradas anteriores
#
# Requiere .NET SDK 10 y PKHeX en .ref/PKHeX o en $PKHEX_DIR (ver
# tools/pkhex_oracle/README.md). El commit y la fecha de PKHeX salen de git
# si $PKHEX_DIR es un clon; si no, de $PKHEX_COMMIT y $PKHEX_DATE.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKHEX_DIR="${PKHEX_DIR:-$ROOT/.ref/PKHeX}"
if [ ! -d "$PKHEX_DIR/PKHeX.Core" ]; then
  echo "Falta PKHeX en $PKHEX_DIR: git clone https://github.com/kwsch/PKHeX \"$ROOT/.ref/PKHeX\"" >&2
  exit 1
fi
if git -C "$PKHEX_DIR" rev-parse --show-toplevel 2>/dev/null | grep -qx "$(cd "$PKHEX_DIR" && pwd -P)"; then
  PKHEX_COMMIT="${PKHEX_COMMIT:-$(git -C "$PKHEX_DIR" log -1 --format=%H)}"
  PKHEX_DATE="${PKHEX_DATE:-$(git -C "$PKHEX_DIR" log -1 --format=%cs)}"
fi
export NUGET_PACKAGES="${NUGET_PACKAGES:-$ROOT/.ref/nuget}" DOTNET_CLI_HOME="${DOTNET_CLI_HOME:-$ROOT/.scratch/dotnet-home}"
export DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1 TMPDIR="$ROOT/.scratch/tmp"
OUT="$ROOT/.scratch/events"
BIN="${ORACLE_BIN:-$ROOT/.scratch/oracle-bin}"
mkdir -p "$OUT" "$TMPDIR"
dotnet build "$ROOT/tools/pkhex_oracle" -c Release -o "$BIN" -p:PkhexDir="$PKHEX_DIR" -v quiet -nologo >/dev/null
dotnet "$BIN/PkhexOracle.dll" events "$OUT"
# Sin commit de PKHeX conocido solo se regenera la copia integrada.
JSON_ARGS=()
if [ -n "${PKHEX_COMMIT:-}" ]; then
  JSON_ARGS=(--json "$ROOT/data/events/events.json" --commit "$PKHEX_COMMIT" --date "$PKHEX_DATE")
  if [ "${EVENTS_FRESH:-0}" = 1 ]; then JSON_ARGS+=(--fresh); fi
else
  echo "Aviso: sin commit de PKHeX (no es un clon de git); data/events/events.json no se toca." >&2
fi
python3 "$ROOT/tool/gen_event_data.py" "$OUT/events.jsonl" \
  "$ROOT/packages/pkcore/lib/src/data/generated/event_data.dart" "${JSON_ARGS[@]}"
