#!/usr/bin/env bash
set -euo pipefail

# Java via sdkman (multiple JDKs, cross-platform): latest LTS Temurin,
# maven + gradle, and jdtls (LSP) where a package exists. JDWP/jdb debugging
# ships with the JDK. Shell init lands in ~/.bashrc.d/sdkman. Idempotent.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/pkg.sh"
PKG_MGR="$(__detect_pkg_mgr)"

# The sdkman installer refuses to run without zip and unzip. macOS ships both;
# a minimal Arch or Debian does not.
__pkg_install "$PKG_MGR" zip unzip

if [ ! -d "$HOME/.sdkman" ]; then
    echo "Installing sdkman..."
    curl -s "https://get.sdkman.io?rcupdate=false" | bash
fi

# sdkman's shell functions are not nounset-safe; relax set -u for all of them
set +u
# shellcheck disable=SC1091
source "$HOME/.sdkman/bin/sdkman-init.sh"

BASHRC_D="$HOME/.bashrc.d"
mkdir -p "$BASHRC_D"
if [ ! -f "$BASHRC_D/sdkman" ]; then
    cat <<'EOF' > "$BASHRC_D/sdkman"
# managed-by-dotfiles (cleanup.sh removes files carrying this marker)
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
EOF
    echo "Wrote $BASHRC_D/sdkman"
fi

# </dev/null makes sdk's "set as default?" prompt take its default (yes)
command -v java >/dev/null 2>&1 || sdk install java < /dev/null || echo "Warning: java install failed." >&2
command -v mvn >/dev/null 2>&1  || sdk install maven < /dev/null || echo "Warning: maven install failed." >&2
command -v gradle >/dev/null 2>&1 || sdk install gradle < /dev/null || echo "Warning: gradle install failed." >&2
set -u

# jdtls (LSP): packaged for brew and the AUR only
if ! command -v jdtls >/dev/null 2>&1; then
    case "$PKG_MGR" in
        brew|yay|paru) __pkg_raw "$PKG_MGR" jdtls || echo "Warning: jdtls install failed." >&2 ;;
        pacman)   echo "Warning: jdtls is AUR-only and this box has no AUR helper. Run install.sh to bootstrap yay, then re-run this script." >&2 ;;
        *)        echo "Note: no jdtls package for $PKG_MGR — install manually or let the editor manage it." ;;
    esac
fi

echo "Done. $(java -version 2>&1 | head -1)"
