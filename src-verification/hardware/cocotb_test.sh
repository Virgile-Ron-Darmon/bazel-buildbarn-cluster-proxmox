#!/usr/bin/env bash
set -euo pipefail

# Args: <vtop rlocationpath> <obj_dir rlocationpath> <python3 rlocationpath> <test_dir> <test_module> <toplevel>
VTOP="$PWD/$1"
OBJ_DIR="$PWD/$2"
PYBIN="$PWD/$3"
TEST_DIR="$PWD/$4"
TEST_MODULE="$5"
TOPLEVEL="$6"

PYLIB="$(cd "$(dirname "$PYBIN")/../lib" && pwd)"
SITEPKG="$(dirname "$(dirname "$(find -L "$TEST_SRCDIR" -path "*site-packages/cocotb/__init__.py" | head -1)")")"
RESULTS="${TEST_UNDECLARED_OUTPUTS_DIR:-$TEST_TMPDIR}/results.xml"

export LD_LIBRARY_PATH="$OBJ_DIR:$PYLIB"
export PYGPI_PYTHON_BIN="$PYBIN"
export COCOTB_TEST_MODULES="$TEST_MODULE"
export COCOTB_TOPLEVEL="$TOPLEVEL"
export PYTHONPATH="$TEST_DIR:$SITEPKG"
export COCOTB_RESULTS_FILE="$RESULTS"

"$VTOP"

[[ -f "$RESULTS" ]] || { echo "FAIL: no results.xml" >&2; exit 1; }
grep -q "<failure" "$RESULTS" && { echo "FAIL: failures in results.xml" >&2; exit 1; }
exit 0