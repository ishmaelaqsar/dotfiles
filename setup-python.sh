#!/usr/bin/env bash
set -euo pipefail

# Python via uv (which manages interpreters itself — no distro pythons),
# plus ruff (lint/format + LSP), basedpyright (type-checking LSP) and
# debugpy (DAP debugger) as uv tools. Idempotent.

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

if ! command -v uv >/dev/null 2>&1; then
    echo "Installing uv..."
    # --no-modify-path stops the installer from appending to ~/.bashrc and
    # ~/.bash_profile. The dotfiles already put ~/.local/bin on PATH.
    curl -LsSf https://astral.sh/uv/install.sh | sh -s -- --no-modify-path
    export PATH="$HOME/.local/bin:$PATH"
fi

echo "Installing Python tools (ruff, basedpyright, debugpy)..."
uv tool install ruff        || echo "Warning: ruff install failed." >&2
uv tool install basedpyright || echo "Warning: basedpyright install failed." >&2
uv tool install debugpy     || echo "Warning: debugpy install failed." >&2

echo "Done. $(uv --version). Tools land in ~/.local/bin (already on PATH)."
