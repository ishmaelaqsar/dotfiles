#!/usr/bin/env bash
set -euo pipefail

# Common Lisp: SBCL + Quicklisp. No LSP on purpose — CL tooling speaks
# Swank/Slynk (Slime/Sly in Emacs; Lem has native CL support), both loaded
# via Quicklisp by the editor. SBCL's debugger is built in; gdb also works
# on native code. Idempotent.

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
