#!/usr/bin/env bash
set -euo pipefail

# Python via uv (which manages interpreters itself — no distro pythons),
# plus ruff (lint/format + LSP), basedpyright (type-checking LSP) and
# debugpy (DAP debugger) as uv tools. Idempotent.

if ! command -v uv >/dev/null 2>&1; then
    echo "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
fi

echo "Installing Python tools (ruff, basedpyright, debugpy)..."
uv tool install ruff        || echo "Warning: ruff install failed." >&2
uv tool install basedpyright || echo "Warning: basedpyright install failed." >&2
uv tool install debugpy     || echo "Warning: debugpy install failed." >&2

echo "Done. $(uv --version). Tools land in ~/.local/bin (already on PATH)."
