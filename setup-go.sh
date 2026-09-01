#!/usr/bin/env bash
set -euo pipefail

# Go toolchain, gopls (LSP) and delve (debugger).
# ~/go/bin is already on PATH via .bash_profile. Idempotent.

# A dry run is all or nothing. lib/pkg.sh honours DOTFILES_DRY_RUN for the
# package steps, but the installers below (curl | sh, git clone, go install,
# sdkman) always act, so a half-planned run would install anyway. -h prints
# the header above.
case "${1:-}" in
    -h|--help)
        sed -n '3,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    -*)
        echo "Unknown option: $1" >&2
        echo "Usage: $(basename "${BASH_SOURCE[0]}") [-h]" >&2
        exit 2
        ;;
esac
if [ "${DOTFILES_DRY_RUN:-0}" = "1" ]; then
    echo "$(basename "${BASH_SOURCE[0]}"): no dry run. It installs, or it does not run." >&2
    exit 2
fi

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
