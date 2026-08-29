#!/usr/bin/env bash
set -euo pipefail

# yk: guided maintenance for the YubiKey OpenPGP identity. One bash file with
# gpg as its only dependency, so it is a clone and a link, not a package. The
# first shell of each day runs `yk remind` from .bashrc. Idempotent.

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
