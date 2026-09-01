#!/usr/bin/env bash
set -euo pipefail

# Common Lisp: SBCL + Quicklisp. No LSP on purpose — CL tooling speaks
# Swank/Slynk (Slime/Sly in Emacs; Lem has native CL support), both loaded
# via Quicklisp by the editor. SBCL's debugger is built in; gdb also works
# on native code. Idempotent.

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

__pkg_install "$PKG_MGR" sbcl

if ! command -v sbcl >/dev/null 2>&1; then
    echo "Error: sbcl not on PATH after install." >&2
    exit 1
fi

if [ -d "$HOME/quicklisp" ]; then
    echo "Quicklisp already installed."
else
    echo "Bootstrapping Quicklisp..."
    QL_FILE="$(mktemp -t quicklisp.XXXXXX.lisp)"
    curl -fsSL -o "$QL_FILE" https://beta.quicklisp.org/quicklisp.lisp
    sbcl --non-interactive \
         --load "$QL_FILE" \
         --eval '(quicklisp-quickstart:install)' \
         --eval '(ql-util:without-prompting (ql:add-to-init-file))'
    rm -f "$QL_FILE"
fi

echo "Done. $(sbcl --version)"
