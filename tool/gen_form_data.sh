#!/usr/bin/env bash
# Regenera los nombres de forma de pkcore y la tabla de verificación
# (especie, forma, juego) desde PKHeX (oráculo tools/pkhex_oracle, comando forms).
#
#   tool/gen_form_data.sh
#
# Requiere .NET SDK 10 y PKHeX en .ref/PKHeX (ver tools/pkhex_oracle/README.md).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ ! -d "$ROOT/.ref/PKHeX/PKHeX.Core" ]; then
  echo "Falta PKHeX en .ref/PKHeX: git clone https://github.com/kwsch/PKHeX \"$ROOT/.ref/PKHeX\"" >&2
  exit 1
fi
export NUGET_PACKAGES="$ROOT/.ref/nuget" DOTNET_CLI_HOME="$ROOT/.scratch/dotnet-home"
export DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1 TMPDIR="$ROOT/.scratch/tmp"
OUT="$ROOT/.scratch/forms"
mkdir -p "$OUT" "$TMPDIR"
dotnet build "$ROOT/tools/pkhex_oracle" -c Release -o "$ROOT/.scratch/oracle-bin" -v quiet -nologo >/dev/null
dotnet "$ROOT/.scratch/oracle-bin/PkhexOracle.dll" forms "$OUT"
python3 "$ROOT/tool/gen_form_data.py" "$OUT" "$ROOT"
