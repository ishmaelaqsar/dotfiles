#!/usr/bin/env bash
# Parser parity — lib/pkg.sh and lib/pkgconf.py read packages.conf with two
# independent parsers, and only this test keeps them in step. Both sides
# print the same manager x tool matrix; any drift in row splitting, the `~`
# marker, or override precedence shows up as a diff.
#
# Needs bash and python3 only, and runs from any directory:
#
#   bash test/pkg-parity.sh
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
pass() { echo "PASS: $*"; }
flunk(){ echo "FAIL: $*"; FAIL=1; }

# shellcheck source=../lib/pkg.sh
source "$REPO/lib/pkg.sh"

MANAGERS="brew apt pacman yay paru dnf"

# Every command name in the table, the ~ marker stripped, plus one name no
# row claims: both parsers must fall back to the name itself for it.
TOOLS="$(__pkg_rows | cut -d'|' -f1 | tr ',' '\n' | sed 's/^~//;s/[[:space:]]//g') no-such-tool"

for tool in $TOOLS; do
    for mgr in $MANAGERS; do
        printf '%s %s -> %s\n' "$mgr" "$tool" "$(__pkg_name "$mgr" "$tool")"
    done
done > /tmp/pkg-parity-bash.txt

python3 - "$REPO" $TOOLS <<'PY' > /tmp/pkg-parity-python.txt
import sys
sys.path.insert(0, sys.argv[1] + "/lib")
import pkgconf
for tool in sys.argv[2:]:
    for mgr in "brew apt pacman yay paru dnf".split():
        print(f"{mgr} {tool} -> {pkgconf.package_name(mgr, tool)}")
PY

rows=$(wc -l < /tmp/pkg-parity-bash.txt | tr -d ' ')
if diff /tmp/pkg-parity-bash.txt /tmp/pkg-parity-python.txt; then
    pass "package_name agrees on all $rows manager x tool pairs"
else
    flunk "the two parsers map some tools differently (diff printed)"
fi

# The detection order must match too. Only this host's answer is testable.
bash_mgr="$(__detect_pkg_mgr)"
py_mgr="$(python3 -c "import sys; sys.path.insert(0, '$REPO/lib'); import pkgconf; print(pkgconf.detect_manager())")"
[ "$bash_mgr" = "$py_mgr" ] \
    && pass "manager detection agrees on this host ($bash_mgr)" \
    || flunk "manager detection differs: pkg.sh says $bash_mgr, pkgconf.py says $py_mgr"

if [ "$FAIL" -eq 0 ]; then echo "ALL CHECKS PASSED"; else echo "FAILURES PRESENT"; fi
exit "$FAIL"
