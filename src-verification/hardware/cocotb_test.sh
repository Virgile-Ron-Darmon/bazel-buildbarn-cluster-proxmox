#!/usr/bin/env bash
set -euo pipefail

# Args: <vtop rlocationpath> <obj_dir rlocationpath> <python3 rlocationpath> <package> <test_module> <toplevel>
VTOP="$TEST_SRCDIR/$1"
OBJ_DIR="$TEST_SRCDIR/$2"
PYBIN="$TEST_SRCDIR/$3"
TEST_DIR="$TEST_SRCDIR/_main/$4"
TEST_MODULE="$5"
TOPLEVEL="$6"

# cocotb's gpi dlopens the literal name "libpython3.12.so", which the hermetic
# toolchain ships only as libpython3.12.so.1.0. Expose it under the expected
# name in a scratch dir.
PYLIB_SRC="$(dirname "$(dirname "$PYBIN")")/lib"
PYLIB="$TEST_TMPDIR/pylib"
mkdir -p "$PYLIB"
ln -sf "$PYLIB_SRC"/libpython3.12.so.1.0 "$PYLIB/libpython3.12.so"

# The cocotb pip repo directory name contains a version hash, so locate it
# rather than hardcoding the path.
COCOTB_INIT="$(find -L "$TEST_SRCDIR" -path "*site-packages/cocotb/__init__.py" -print -quit 2>/dev/null || true)"
[[ -n "$COCOTB_INIT" ]] || { echo "FAIL: cocotb not found in runfiles" >&2; exit 1; }
SITEPKG="$(dirname "$(dirname "$COCOTB_INIT")")"

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