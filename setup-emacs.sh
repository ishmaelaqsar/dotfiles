#!/usr/bin/env bash
set -euo pipefail

# Emacs 30 with the two packages that are not in core: Sly for Common Lisp and
# Magit. eglot, tree-sitter and use-package ship with Emacs, and eglot talks to
# the servers the other setup-*.sh scripts install. The init is
# dotfiles/.config/emacs/init.el, linked by install.sh. Idempotent.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/pkg.sh"
PKG_MGR="$(__detect_pkg_mgr)"

if [[ "$OSTYPE" == darwin* ]]; then
    # emacs-plus builds a real Emacs.app. The core formula is a daemon build with
    # no proper bundle, and one major version ahead of every Linux package.
    if ! brew tap | grep -qx 'd12frosted/emacs-plus'; then
        echo "Adding the emacs-plus tap..."
        brew tap d12frosted/emacs-plus
    fi
    # Homebrew refuses a formula from a third-party tap until the tap is
    # trusted. Older Homebrew has no `brew trust`, and needs none.
    if brew trust --help >/dev/null 2>&1; then
        brew trust d12frosted/emacs-plus >/dev/null 2>&1 || true
    fi
    # Native compilation is the default of this formula, so no option.
    if ! command -v emacs >/dev/null 2>&1; then
        __pkg_raw brew emacs-plus@30
    fi
    # Spotlight indexes both /Applications and ~/Applications. A user outside
    # the admin group cannot write the first, so fall back to the second.
    APP="$(brew --prefix emacs-plus@30 2>/dev/null)/Emacs.app"
    APP_DIR=/Applications
    [ -w "$APP_DIR" ] || APP_DIR="$HOME/Applications"
    if [ -d "$APP" ] && [ ! -e "$APP_DIR/Emacs.app" ]; then
        mkdir -p "$APP_DIR"
        if ln -sfn "$APP" "$APP_DIR/Emacs.app"; then
            echo "Linked Emacs.app into $APP_DIR."
        else
            echo "Note: could not link $APP into $APP_DIR. Do it by hand." >&2
        fi
    fi
else
    __pkg_install "$PKG_MGR" emacs
fi

if ! command -v emacs >/dev/null 2>&1; then
    echo "Error: emacs not on PATH after install." >&2
    exit 1
fi

# init.el names the packages in package-selected-packages, so the list lives in
# one place. --batch makes Emacs exit when the form returns, and skips package
# activation, hence the explicit package-initialize.
INIT="$HOME/.config/emacs/init.el"
if [ -f "$INIT" ]; then
    echo "Installing the packages init.el selects..."
    emacs --batch --eval '(package-initialize)' -l "$INIT" \
        --eval '(progn (package-refresh-contents) (package-install-selected-packages t))' \
        || echo "Warning: package install failed. Run it from Emacs: M-x package-install-selected-packages" >&2
else
    echo "Note: $INIT is missing. Run ./install.sh to link it, then run this script again." >&2
fi

echo "Done. $(emacs --version | head -1)"
echo "emacsclient needs a server. The init starts one in the first graphical Emacs,"
echo "and \`emacsclient -a ''\` starts a daemon when none runs."
