#!/usr/bin/env bash
set -euo pipefail

# Emacs, and the packages init.el selects: emacs-plus@31 on macOS, the distro
# package on Linux. eglot, tree-sitter and use-package ship with Emacs, and
# eglot talks to the servers the other setup-*.sh scripts install. The init is
# dotfiles/.config/emacs/init.el, linked by install.sh. Idempotent.

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

if [[ "$OSTYPE" == darwin* ]]; then
    # emacs-plus builds a real Emacs.app. The core formula has no bundle.
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
        __pkg_raw brew emacs-plus@31
    fi
    # Spotlight indexes both /Applications and ~/Applications. A user outside
    # the admin group cannot write the first, so fall back to the second.
    APP="$(brew --prefix emacs-plus@31 2>/dev/null)/Emacs.app"
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
# activation, hence the explicit package-initialize. --batch also skips
# early-init.el, which sets package-quickstart-file; without it the refresh
# writes a quickstart that a normal start never reads, and a package missing
# from the stale one fails to load.
INIT="$HOME/.config/emacs/init.el"
EARLY_INIT="$HOME/.config/emacs/early-init.el"
if [ -f "$INIT" ]; then
    echo "Installing the packages init.el selects..."
    emacs --batch -l "$EARLY_INIT" --eval '(package-initialize)' -l "$INIT" \
        --eval '(progn (package-refresh-contents) (package-install-selected-packages t) (package-quickstart-refresh))' \
        || echo "Warning: package install failed. Run it from Emacs: M-x package-install-selected-packages" >&2
else
    echo "Note: $INIT is missing. Run ./install.sh to link it, then run this script again." >&2
fi

# Keep the daemon warm across logins. Linux gets it from the systemd user unit
# in dotfiles/.config/systemd/user/emacs.service, which install.sh enables.
# macOS has no such unit, so hand the job to brew services, which writes its
# own LaunchAgent. Both are idempotent, and neither restarts a running daemon.
if [[ "$OSTYPE" == darwin* ]] && command -v brew >/dev/null 2>&1; then
    if brew services list 2>/dev/null | grep -qE "^emacs-plus@31\s+started"; then
        echo "The Emacs daemon is already a brew service."
    else
        echo "Starting the Emacs daemon as a brew service..."
        brew services start emacs-plus@31 \
            || echo "Warning: could not start the service. Start a daemon with 'emacs --daemon'." >&2
    fi
fi

echo "Done. $(emacs --version | head -1)"
echo "emacsclient needs a server. On Linux the systemd user unit starts one, on"
echo "macOS the brew service does, and \`emacsclient -a ''\` starts one when neither has."
