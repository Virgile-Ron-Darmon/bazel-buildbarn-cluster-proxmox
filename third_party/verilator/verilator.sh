#!/usr/bin/env bash
set -euo pipefail

# Runfiles root: when a sh_binary runs, its runfiles tree sits at $0.runfiles.
RUNFILES="${RUNFILES_DIR:-$0.runfiles}"

VERILATOR_BIN="${RUNFILES}/_main/third_party/verilator/verilator_build/bin/verilator_bin"

if [[ ! -x "${VERILATOR_BIN}" ]]; then
  echo "error: hermetic verilator not found at ${VERILATOR_BIN}" >&2
  exit 1
fi

export VERILATOR_ROOT="$(dirname "$(dirname "${VERILATOR_BIN}")")/share/verilator"

exec "${VERILATOR_BIN}" "$@"