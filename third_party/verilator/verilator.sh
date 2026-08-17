#!/usr/bin/env bash
set -euo pipefail

VERILATOR_INSTALL="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

VERILATOR_BIN="$(find "${VERILATOR_INSTALL}" -path '*/verilator_build/bin/verilator_bin' 2>/dev/null | head -n1)"

if [[ -z "${VERILATOR_BIN}" ]]; then
  echo "error: hermetic verilator not found." >&2
  exit 1
fi

ROOT="$(dirname "$(dirname "${VERILATOR_BIN}")")/share/verilator"
export VERILATOR_ROOT="${ROOT}"

exec "${VERILATOR_BIN}" "$@"