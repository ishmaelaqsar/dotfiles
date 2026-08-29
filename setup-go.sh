#!/usr/bin/env bash
set -euo pipefail

# Go toolchain, gopls (LSP) and delve (debugger).
# ~/go/bin is already on PATH via .bash_profile. Idempotent.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/pkg.sh"
PKG_MGR="$(__detect_pkg_mgr)"
__pkg_refresh "$PKG_MGR"

__pkg_install "$PKG_MGR" go

if ! command -v go >/dev/null 2>&1; then
    echo "Error: go not on PATH after install." >&2
    exit 1
fi

echo "Installing gopls (LSP) and delve (debugger)..."
go install golang.org/x/tools/gopls@latest || echo "Warning: gopls install failed." >&2
go install github.com/go-delve/delve/cmd/dlv@latest || echo "Warning: delve install failed." >&2

echo "Done. $(go version)"
if [[ "$OSTYPE" == darwin* ]]; then
    echo "Note: on macOS dlv needs Xcode CLT for debugserver."
fi
