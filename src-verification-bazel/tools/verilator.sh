#!/usr/bin/env bash
set -euo pipefail
 
VERILATOR_BIN="$(command -v verilator)"
 
if [[ -z "${VERILATOR_BIN}" ]]; then
  echo "error: verilator not found on PATH. Install it (e.g. apt install verilator)." >&2
  exit 1
fi
 
exec "${VERILATOR_BIN}" "$@"