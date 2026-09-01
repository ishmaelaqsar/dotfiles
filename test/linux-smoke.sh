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

say "install.sh --dry-run (must plan everything and change nothing)"
./install.sh --dry-run > /tmp/dry.log 2>&1 || flunk "--dry-run exited non-zero"
grep -q '\[dry-run\]' /tmp/dry.log && pass "--dry-run printed a plan" || flunk "--dry-run printed no plan"
[ ! -L "$HOME/.bashrc" ] && pass "--dry-run created no symlinks" || flunk "--dry-run linked .bashrc"
[ -z "$(git config --global user.email 2>/dev/null)" ] && pass "--dry-run set no git config" || flunk "--dry-run wrote git config"
command -v eza >/dev/null 2>&1 && flunk "--dry-run installed packages" || pass "--dry-run installed nothing"

# The desktop flags override the headless detection, so the plan must differ.
# Redirect to a file rather than piping: grep -q closes the pipe on its first
# match, install.sh dies of SIGPIPE, and pipefail reports the whole pipeline
# as failed even though the match succeeded.
./install.sh --dry-run --desktop > /tmp/dry-desktop.log 2>&1
grep -q "wl-clipboard" /tmp/dry-desktop.log \
    && pass "--desktop plans the clipboard package" || flunk "--desktop did not plan wl-clipboard"
./install.sh --dry-run --no-desktop > /tmp/dry-nodesktop.log 2>&1
grep -q "wl-clipboard" /tmp/dry-nodesktop.log \
    && flunk "--no-desktop still planned wl-clipboard" || pass "--no-desktop skips the clipboard package"

# Nothing is installed yet, so the doctor must not report a healthy box.
./install.sh --check > /tmp/check-before.log 2>&1 \
    && flunk "--check passed before anything was installed" \
    || pass "--check fails on a bare box"

say "install.sh (home install, container detection overridden)"
# stdin closed, as under the dev-container hook: the script must not ask, must
# say so, and must still install everything the detection selected.
./install.sh < /dev/null > /tmp/install.log 2>&1 || flunk "install.sh exited non-zero"
cat /tmp/install.log
grep -q "No terminal on stdin" /tmp/install.log \
    && pass "no terminal: the script says it asks nothing" || flunk "no terminal, and no note about it"

say "install.sh --check (must pass right after an install)"
if ./install.sh --check > /tmp/check.log 2>&1; then
    pass "--check passed after install"
else
    flunk "--check failed after install"
    cat /tmp/check.log
fi

for t in eza rg fzf delta starship tmux; do check "$t"; done
{ command -v fd || command -v fdfind; } >/dev/null 2>&1 && pass "fd/fdfind" || flunk "fd/fdfind missing"
# Arch upkeep tools. wl-clipboard is desktop-only and a container is headless,
# so check the package name instead of the binary.
if command -v pacman >/dev/null 2>&1; then
    check paccache
    pacman -Si wl-clipboard >/dev/null 2>&1 && pass "pacman knows 'wl-clipboard'" || flunk "no 'wl-clipboard' package in pacman repos"
    [ -L "$HOME/.makepkg.conf" ] && pass ".makepkg.conf symlinked" || flunk ".makepkg.conf not a symlink"
fi
[ -L "$HOME/.config/environment.d/10-gpg-ssh.conf" ] && pass "environment.d gpg-ssh symlinked" || flunk "environment.d gpg-ssh missing"
# environment.d expands $VAR only. A systemd specifier such as %t would reach
# the session as literal characters, and every graphical app would then get a
# socket path that does not exist. Read the assignment alone: the comments in
# that file name the specifier to explain why it is not used.
SOCK_LINE="$(grep '^SSH_AUTH_SOCK=' "$HOME/.config/environment.d/10-gpg-ssh.conf")"
case "$SOCK_LINE" in
    *'${XDG_RUNTIME_DIR}'*) pass "environment.d uses a variable, not a specifier" ;;
    *%*) flunk "environment.d holds a specifier: SSH_AUTH_SOCK stays literal" ;;
    *) flunk "environment.d SSH_AUTH_SOCK is unexpected: $SOCK_LINE" ;;
esac
# Debian ships fd as fdfind, so the fuzzy-find helpers call __fd
bash -lic '__fd --version' >/dev/null 2>&1 \
    && pass "__fd resolves on this distro" || flunk "__fd does not resolve"
[ -L "$HOME/.config/fontconfig/fonts.conf" ] && pass "fontconfig symlinked" || flunk "fontconfig missing"
python3 ./bin/gnome-settings dump >/dev/null 2>&1 && pass "gnome-settings runs without GNOME" || flunk "gnome-settings failed on a non-GNOME box"
[ -f "$HOME/.local/share/fonts/0xProtoNerdFont-Regular.ttf" ] && pass "fonts installed" || flunk "fonts missing"
[ -L "$HOME/.bashrc" ] && pass ".bashrc symlinked" || flunk ".bashrc not a symlink"
# Python's byte-code cache sits next to the scripts in bin/, and must not follow
# them into ~/bin
[ ! -e "$HOME/bin/__pycache__" ] && pass "no __pycache__ in ~/bin" || flunk "__pycache__ linked into ~/bin"
[ "$(git config --global user.email)" = "ishmael-dev@aqsar.dev" ] && pass "git identity set" || flunk "git identity wrong"
# delta is wired in only when the package landed, so gate the assertion the
# same way install.sh does
if command -v delta >/dev/null 2>&1; then
    [ "$(git config --global core.pager)" = "delta" ] && pass "delta is the diff pager" || flunk "core.pager is not delta"
    [ "$(git config --global interactive.diffFilter)" = "delta --color-only" ] \
        && pass "delta filters interactive diffs" || flunk "interactive.diffFilter not set"
    # git skips the pager when stdout is not a tty, so feed delta a real diff
    # by hand. Two steps, not a pipeline: `git diff --no-index` exits 1 when the
    # files differ, and pipefail would report that as the whole test failing.
    printf 'one\n' > /tmp/delta-a
    printf 'two\n' > /tmp/delta-b
    git diff --no-index /tmp/delta-a /tmp/delta-b > /tmp/delta-in.diff 2>/dev/null
    delta < /tmp/delta-in.diff >/dev/null 2>&1 \
        && pass "delta renders a real diff" || flunk "delta failed on a real diff"
else
    echo "note: delta absent — pager wiring skipped, as install.sh does"
fi
bash -lic 'type ll' >/dev/null 2>&1 && pass "aliases load in interactive shell" || flunk "aliases failed to load"
# `dotfiles` must be the shell function, not the alias earlier versions wrote:
# an alias expands first and would hide the function
[ ! -f "$HOME/.bashrc.d/dotfiles_alias" ] \
    && pass "no stale dotfiles alias file" || flunk "the old dotfiles alias file survived"
[ "$(bash -lic 'type -t dotfiles' 2>/dev/null | tr -d '\r')" = "function" ] \
    && pass "dotfiles is a shell function" || flunk "dotfiles is not a function"
[ "$(dotfiles path)" = "$HOME/dotfiles" ] \
    && pass "dotfiles path finds the repository" || flunk "dotfiles path is wrong"
dotfiles status >/dev/null 2>&1 \
    && pass "dotfiles status passes after an install" || flunk "dotfiles status failed"
dotfiles doctor >/dev/null 2>&1 \
    && pass "dotfiles doctor passes after an install" || flunk "dotfiles doctor failed"
dotfiles sync --check >/dev/null 2>&1 \
    && pass "dotfiles sync --check passes" || flunk "dotfiles sync --check failed"
# The sync engine lives in lib/ now, so nothing links it into ~/bin
[ ! -e "$HOME/bin/sync-dotfiles" ] \
    && pass "the sync engine is not linked into ~/bin" || flunk "\$HOME/bin/sync-dotfiles still exists"

say "parser parity (lib/pkg.sh vs lib/pkgconf.py)"
bash test/pkg-parity.sh > /tmp/parity.log 2>&1 \
    && pass "both parsers read packages.conf the same way" \
    || { flunk "the parsers disagree"; tail -20 /tmp/parity.log; }

say "setup-*.sh refuse a dry run rather than half honouring it"
DOTFILES_DRY_RUN=1 ./setup-go.sh >/dev/null 2>&1 \
    && flunk "setup-go.sh ran under DOTFILES_DRY_RUN" \
    || pass "setup-go.sh stops under DOTFILES_DRY_RUN"

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
    # and proven natively elsewhere, so verify the package name only
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

say "setup-emacs.sh (package name only; the install is large)"
# The emacs row carries a per-distro override, so prove each distro knows it.
if command -v pacman >/dev/null 2>&1; then
    pacman -Si emacs-wayland >/dev/null 2>&1 && pass "pacman knows 'emacs-wayland'" || flunk "no 'emacs-wayland' package in pacman repos"
elif command -v apt-cache >/dev/null 2>&1; then
    apt-cache show emacs-pgtk >/dev/null 2>&1 && pass "apt knows 'emacs-pgtk'" || flunk "no 'emacs-pgtk' package in apt"
elif command -v dnf >/dev/null 2>&1; then
    dnf info emacs >/dev/null 2>&1 && pass "dnf knows 'emacs'" || flunk "no 'emacs' package in dnf"
fi
[ -L "$HOME/.config/emacs/init.el" ] && pass "emacs init symlinked" || flunk "emacs init missing"
if [ "$MODE" = "full" ]; then
    ./setup-emacs.sh || flunk "setup-emacs.sh exited non-zero"
    # The init must load with no network and no grammar installed.
    emacs --batch --eval '(package-initialize)' -l "$HOME/.config/emacs/init.el" --eval '(kill-emacs)' >/dev/null 2>&1 \
        && pass "init.el loads in batch" || flunk "init.el failed to load"
fi

say "cleanup.sh -a"
# printf, not `yes`: yes dies of SIGPIPE when cleanup stops reading, and
# under pipefail that masquerades as a cleanup failure
printf 'y\n' | ./cleanup.sh -a || flunk "cleanup.sh exited non-zero"
[ ! -L "$HOME/.bashrc" ] && pass ".bashrc symlink removed" || flunk ".bashrc symlink survived cleanup"
[ ! -L "$HOME/.config/environment.d/10-gpg-ssh.conf" ] && pass "environment.d gpg-ssh removed" || flunk "environment.d gpg-ssh survived cleanup"
[ ! -f "$HOME/.local/share/fonts/0xProtoNerdFont-Regular.ttf" ] && pass "fonts removed" || flunk "fonts survived cleanup"
[ ! -d "$HOME/quicklisp" ] && pass "quicklisp removed" || flunk "quicklisp survived cleanup"

[ -z "$(git config --global user.email 2>/dev/null)" ] && pass "git identity unset" || flunk "git identity survived cleanup"
[ -z "$(git config --global core.pager 2>/dev/null)" ] \
    && pass "delta pager wiring unset" || flunk "core.pager survived cleanup"
./install.sh --check >/dev/null 2>&1 \
    && flunk "--check still passes after cleanup" \
    || pass "--check reports the removed install"
if [ "$MODE" = "full" ]; then
    [ ! -d "$HOME/.sdkman" ] && pass "sdkman removed" || flunk "sdkman survived cleanup"
fi

say "result"
if [ "$FAIL" -eq 0 ]; then echo "ALL CHECKS PASSED"; else echo "FAILURES PRESENT"; fi
exit "$FAIL"
