#!/usr/bin/env bash
set -euo pipefail

# yk: guided maintenance for the YubiKey OpenPGP identity. One bash file with
# gpg as its only dependency, so it is a clone and a link, not a package. The
# first shell of each day runs `yk remind` from .bashrc. Idempotent.

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

YK_REPO="https://github.com/ishmaelaqsar/yk"
YK_DIR="$HOME/.local/share/yk"

if [ -d "$YK_DIR/.git" ]; then
    echo "Updating yk in $YK_DIR..."
    git -C "$YK_DIR" pull --ff-only
else
    echo "Cloning yk into $YK_DIR..."
    git clone "$YK_REPO" "$YK_DIR"
fi

mkdir -p "$HOME/bin"
ln -sf "$YK_DIR/yk" "$HOME/bin/yk"
chmod +x "$YK_DIR/yk"

# The tool's own environment report. It names each missing program and what
# that program is for. --no-card, because a daily machine runs remind and
# status only, and both read the public key rather than the card.
"$HOME/bin/yk" check --no-card || echo "Note: yk check found gaps. Read the lines above." >&2

echo "Done. yk is at $HOME/bin/yk. Run 'yk status' for the expiry report."
