#!/usr/bin/env bash
set -euo pipefail

# C / C++ toolchain: compilers, cmake, clangd (LSP), gdb/lldb (debuggers),
# valgrind (Linux). Idempotent; run manually on machines that need it.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/pkg.sh"
PKG_MGR="$(__detect_pkg_mgr)"

if [[ "$OSTYPE" == darwin* ]]; then
    # Xcode CLT provides clang, clangd, lldb and make. gdb needs a code-signing
    # certificate on macOS, so lldb is the debugger there.
    if ! xcode-select -p >/dev/null 2>&1; then
        echo "Installing Xcode Command Line Tools (dialog will appear)..."
        xcode-select --install
        echo "Re-run this script once the CLT install finishes."
        exit 0
    fi
    __pkg_install "$PKG_MGR" cmake
else
    case "$PKG_MGR" in
        apt)        __pkg_raw apt build-essential gdb lldb clangd cmake valgrind ;;
        yay|paru|pacman) __pkg_raw "$PKG_MGR" base-devel gdb lldb clang cmake valgrind ;;
        dnf)        __pkg_raw dnf gcc gcc-c++ make gdb lldb clang-tools-extra cmake valgrind ;;
        *)          echo "No supported package manager found." >&2; exit 1 ;;
    esac
fi

echo "Done. Toolchain: $(cc --version 2>/dev/null | head -1 || echo 'cc not found')"
command -v clangd >/dev/null 2>&1 && echo "LSP: $(clangd --version | head -1)" \
    || echo "Note: clangd not on PATH — on Debian it may be versioned (clangd-XX)."
