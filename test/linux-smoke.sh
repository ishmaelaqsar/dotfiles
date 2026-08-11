#!/usr/bin/env bash
# Linux smoke test — runs INSIDE a throwaway container. From the repo root:
#
#   docker run --rm -v "$PWD":/repo:ro debian:stable    bash /repo/test/linux-smoke.sh full
#   docker run --rm -v "$PWD":/repo:ro fedora:latest    bash /repo/test/linux-smoke.sh quick
#   docker run --rm --platform linux/amd64 -v "$PWD":/repo:ro archlinux:latest bash /repo/test/linux-smoke.sh quick
#
# full:  everything, including setup-java.sh (large downloads).
# quick: skips java; stubs opencode/ghostty binaries and checks their package
#        names against the distro metadata instead of installing them.
set -uo pipefail

MODE="${1:-quick}"
FAIL=0
say()  { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }
pass() { echo "PASS: $*"; }
flunk(){ echo "FAIL: $*"; FAIL=1; }
check() { command -v "$1" >/dev/null 2>&1 && pass "$1 on PATH" || flunk "$1 missing"; }

say "container prep (machine prerequisites, not part of the dotfiles)"
if command -v apt-get >/dev/null 2>&1; then
    apt-get update -qq
    apt-get install -y -qq --no-install-recommends curl ca-certificates python3 git unzip zip fontconfig >/dev/null
elif command -v dnf >/dev/null 2>&1; then
    dnf install -y -q curl ca-certificates python3 git unzip zip fontconfig findutils gawk >/dev/null
elif command -v pacman >/dev/null 2>&1; then
    # pacman's download sandbox breaks under qemu emulation (docker on arm
    # macs); disable it here only — real Arch hardware doesn't need this
    echo "DisableSandbox" >> /etc/pacman.conf
    pacman -Sy --noconfirm >/dev/null
    pacman -S --noconfirm --needed curl ca-certificates python3 git unzip zip fontconfig >/dev/null
fi

cp -r /repo "$HOME/dotfiles"
cd "$HOME/dotfiles" || exit 1
export DOTFILES_FORCE_HOST=1
export PATH="$HOME/.local/bin:$HOME/bin:$HOME/go/bin:$PATH"

if [ "$MODE" = "quick" ]; then
    say "quick mode: stubbing opencode/ghostty; verifying package names via metadata"
    for stub in opencode ghostty; do
        printf '#!/bin/sh\n' > "/usr/local/bin/$stub" && chmod +x "/usr/local/bin/$stub"
    done
    if command -v pacman >/dev/null 2>&1; then
        pacman -Si opencode >/dev/null 2>&1 && pass "pacman knows 'opencode'" || flunk "no 'opencode' package in pacman repos"
        pacman -Si ghostty  >/dev/null 2>&1 && pass "pacman knows 'ghostty'"  || flunk "no 'ghostty' package in pacman repos"
    fi
fi

say "install.sh (home install, container detection overridden)"
./install.sh || flunk "install.sh exited non-zero"

for t in eza rg fzf delta starship; do check "$t"; done
# zellij is only packaged for pacman/brew; elsewhere install.sh warns and
# continues, so absence is a note, not a failure
if command -v zellij >/dev/null 2>&1; then pass "zellij on PATH"
elif command -v pacman >/dev/null 2>&1; then flunk "zellij missing (packaged on Arch)"
else echo "note: zellij not packaged here — best-effort, skipped"
fi
{ command -v fd || command -v fdfind; } >/dev/null 2>&1 && pass "fd/fdfind" || flunk "fd/fdfind missing"
[ -f "$HOME/.local/share/fonts/0xProtoNerdFont-Regular.ttf" ] && pass "fonts installed" || flunk "fonts missing"
[ -L "$HOME/.bashrc" ] && pass ".bashrc symlinked" || flunk ".bashrc not a symlink"
[ "$(git config --global user.email)" = "ishmael-dev@aqsar.dev" ] && pass "git identity set" || flunk "git identity wrong"
bash -lic 'type ll' >/dev/null 2>&1 && pass "aliases load in interactive shell" || flunk "aliases failed to load"

say "setup-c.sh"
./setup-c.sh || flunk "setup-c.sh exited non-zero"
for t in cc gdb cmake; do check "$t"; done
command -v clangd >/dev/null 2>&1 && pass "clangd" || echo "note: clangd not on PATH (may be versioned)"

say "setup-python.sh"
./setup-python.sh || flunk "setup-python.sh exited non-zero"
for t in uv ruff basedpyright debugpy; do check "$t"; done

say "setup-go.sh"
./setup-go.sh || flunk "setup-go.sh exited non-zero"
check go
# Go binaries crash compiling under qemu user emulation; the driver sets
# SMOKE_EMULATED=1 for such runs and gopls/dlv absence becomes a note
for t in gopls dlv; do
    if command -v "$t" >/dev/null 2>&1; then pass "$t on PATH"
    elif [ "${SMOKE_EMULATED:-0}" = "1" ]; then echo "note: $t missing (go-under-qemu crash — verify on real hardware)"
    else flunk "$t missing"
    fi
done

say "setup-sbcl.sh"
if [ "${SMOKE_EMULATED:-0}" = "1" ]; then
    # SBCL hangs compiling ASDF under qemu; bootstrap is distro-independent
    # and proven natively elsewhere — just verify the package name here
    echo "note: skipping SBCL/quicklisp under emulation; checking package name only"
    if command -v pacman >/dev/null 2>&1; then
        pacman -Si sbcl >/dev/null 2>&1 && pass "pacman knows 'sbcl'" || flunk "no 'sbcl' package in pacman repos"
    fi
else
    ./setup-sbcl.sh || flunk "setup-sbcl.sh exited non-zero"
    check sbcl
    [ -d "$HOME/quicklisp" ] && pass "quicklisp installed" || flunk "quicklisp missing"
fi

if [ "$MODE" = "full" ]; then
    say "setup-java.sh"
    ./setup-java.sh || flunk "setup-java.sh exited non-zero"
    export SDKMAN_DIR="$HOME/.sdkman"
    set +u; source "$HOME/.sdkman/bin/sdkman-init.sh" 2>/dev/null; set -u
    for t in java mvn gradle; do check "$t"; done
    [ -f "$HOME/.bashrc.d/sdkman" ] && pass "sdkman bashrc.d entry" || flunk "sdkman bashrc.d entry missing"
fi

say "cleanup.sh -a"
# printf, not `yes`: yes dies of SIGPIPE when cleanup stops reading, and
# under pipefail that masquerades as a cleanup failure
printf 'y\n' | ./cleanup.sh -a || flunk "cleanup.sh exited non-zero"
[ ! -L "$HOME/.bashrc" ] && pass ".bashrc symlink removed" || flunk ".bashrc symlink survived cleanup"
[ ! -f "$HOME/.local/share/fonts/0xProtoNerdFont-Regular.ttf" ] && pass "fonts removed" || flunk "fonts survived cleanup"
[ ! -d "$HOME/quicklisp" ] && pass "quicklisp removed" || flunk "quicklisp survived cleanup"

[ -z "$(git config --global user.email 2>/dev/null)" ] && pass "git identity unset" || flunk "git identity survived cleanup"
if [ "$MODE" = "full" ]; then
    [ ! -d "$HOME/.sdkman" ] && pass "sdkman removed" || flunk "sdkman survived cleanup"
fi

say "result"
if [ "$FAIL" -eq 0 ]; then echo "ALL CHECKS PASSED"; else echo "FAILURES PRESENT"; fi
exit "$FAIL"
