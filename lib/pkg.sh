# shellcheck shell=bash
# Shared package-manager plumbing for install.sh and setup-*.sh.
# Usage: source this, then PKG_MGR="$(__detect_pkg_mgr)".
#
# What to install lives in packages.conf, not here. This file is the driver.

PKG_MANIFEST="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/packages.conf"

# Run a command, or print it when a dry run is in progress. install.sh
# --dry-run exports DOTFILES_DRY_RUN=1, so these helpers plan the work instead
# of changing the machine.
__run() {
    if [ "${DOTFILES_DRY_RUN:-0}" = "1" ]; then
        printf '  [dry-run] %s\n' "$*"
        return 0
    fi
    "$@"
}

# Report a problem, and keep it for the summary install.sh prints at the end.
# A warning in the middle of a long package run scrolls past unread.
WARNING_LIST=""
WARNING_COUNT=0
__warn() {
    echo "Warning: $*" >&2
    WARNING_LIST="${WARNING_LIST}  - $*"$'\n'
    WARNING_COUNT=$((WARNING_COUNT + 1))
}

# Prefer the native manager over linuxbrew, and an AUR helper over pacman on
# Arch. yay/paru must not run under sudo (they escalate themselves), hence
# per-manager sudo.
__detect_pkg_mgr() {
    if [[ "$OSTYPE" == darwin* ]] && command -v brew >/dev/null 2>&1; then
        echo brew; return
    fi
    if command -v apt-get >/dev/null 2>&1; then echo apt
    elif command -v yay >/dev/null 2>&1; then echo yay
    elif command -v paru >/dev/null 2>&1; then echo paru
    elif command -v pacman >/dev/null 2>&1; then echo pacman
    elif command -v dnf >/dev/null 2>&1; then echo dnf
    elif command -v brew >/dev/null 2>&1; then echo brew
    else echo none
    fi
}

# -----------------------------
# The package table
# -----------------------------

# Strip the whitespace around a field
__trim() {
    local text
    read -r text <<< "$1" || true
    printf '%s' "$text"
}

# Print every row of packages.conf as: commands|tags|overrides
__pkg_rows() {
    local line commands tags overrides
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%%#*}"
        [ -z "${line//[[:space:]]/}" ] && continue
        IFS='|' read -r commands tags overrides <<< "$line"
        printf '%s|%s|%s\n' \
            "$(__trim "$commands")" "$(__trim "${tags:-}")" "$(__trim "${overrides:-}")"
    done < "$PKG_MANIFEST"
}

# Print the row a tool belongs to as commands|tags|overrides, else nothing
__pkg_row() {
    local tool=$1 commands tags overrides cmd
    while IFS='|' read -r commands tags overrides; do
        for cmd in ${commands//,/ }; do
            if [ "${cmd#\~}" = "$tool" ]; then
                printf '%s|%s|%s' "$commands" "$tags" "$overrides"
                return
            fi
        done
    done < <(__pkg_rows)
}

# Print the commands field of the row a tool belongs to, else the tool itself
__pkg_commands() {
    local commands tags overrides
    IFS='|' read -r commands tags overrides <<< "$(__pkg_row "$1")"
    printf '%s' "${commands:-$1}"
}

# The identity of a commands field: the first name, without the ~ marker
__pkg_primary() {
    local first=${1%%,*}
    printf '%s' "${first#\~}"
}

# Is this row's tool on the machine?
#   0 present   1 absent   2 unverifiable (~ prefix — no command answers to it)
__pkg_present() {
    local commands=$1 cmd
    case "$commands" in \~*) return 2 ;; esac
    for cmd in ${commands//,/ }; do
        command -v "$cmd" >/dev/null 2>&1 && return 0
    done
    return 1
}

# Print the commands field of every row whose tags are all in the active set
__pkg_select() {
    local active=" $* "
    local commands tags overrides tag wanted
    while IFS='|' read -r commands tags overrides; do
        wanted=1
        for tag in $tags; do
            [[ "$active" == *" $tag "* ]] || { wanted=0; break; }
        done
        # An `if`, not an `&&` list: a non-matching last row would otherwise
        # leave the loop with a non-zero status, and set -e would abort here.
        if [ "$wanted" -eq 1 ]; then printf '%s\n' "$commands"; fi
    done < <(__pkg_rows)
}

# Map a tool name to this manager's package name
__pkg_name() {
    local mgr=$1 tool=$2
    local commands tags overrides token
    IFS='|' read -r commands tags overrides <<< "$(__pkg_row "$tool")"
    for token in $overrides; do
        [ "${token%%=*}" = "$mgr" ] && { printf '%s' "${token#*=}"; return; }
    done
    for token in $overrides; do
        [ "${token%%=*}" = "*" ] && { printf '%s' "${token#*=}"; return; }
    done
    __pkg_primary "${commands:-$tool}"
}

# Install tools by command name, skipping ones already present.
# Best-effort: one missing package must not sink the rest.
__pkg_install() {
    local mgr=$1; shift
    local tool pkg failed=""
    for tool in "$@"; do
        __pkg_present "$(__pkg_commands "$tool")" && continue
        pkg="$(__pkg_name "$mgr" "$tool")"
        echo "  -> Installing $pkg ($mgr)"
        __pkg_raw "$mgr" "$pkg" || failed="$failed $tool"
    done
    if [ -n "$failed" ]; then
        __warn "could not install:$failed — install manually."
    fi
}

# Install every row of packages.conf whose tags are all active
__pkg_install_tagged() {
    local mgr=$1; shift
    local commands tools=()
    while IFS= read -r commands; do
        tools+=("$(__pkg_primary "$commands")")
    done < <(__pkg_select "$@")
    if [ ${#tools[@]} -gt 0 ]; then
        __pkg_install "$mgr" "${tools[@]}"
    fi
}

# Run privileged: direct when already root (containers, root bootstraps)
__pkg_sudo() {
    if [ "$(id -u)" -eq 0 ]; then __run "$@"; else __run sudo "$@"; fi
}

# Bring the package database up to date before an install. Arch needs the
# full -Syu: a plain -S installs the versions the local database lists, which
# every mirror has dropped once the database is stale, so each download is a
# 404; and -Sy alone leaves a partial upgrade. dnf refreshes on its own, and
# brew updates itself on install.
__pkg_refresh() {
    case "$1" in
        apt)      __pkg_sudo apt-get update || __warn "apt-get update failed." ;;
        yay|paru) __run "$1" -Syu --noconfirm || __warn "$1 -Syu failed." ;;
        pacman)   __pkg_sudo pacman -Syu --noconfirm || __warn "pacman -Syu failed." ;;
        *)        ;;
    esac
}

# Install raw package names with no mapping or presence check
__pkg_raw() {
    local mgr=$1; shift
    case "$mgr" in
        brew)     __run brew install "$@" ;;
        apt)      __pkg_sudo apt-get install -y "$@" ;;
        yay|paru) __run "$mgr" -S --needed --noconfirm "$@" ;;
        pacman)   __pkg_sudo pacman -S --needed --noconfirm "$@" ;;
        dnf)      __pkg_sudo dnf install -y "$@" ;;
        *)        echo "No supported package manager found." >&2; return 1 ;;
    esac
}

# Bootstrap an AUR helper on Arch. The AUR holds packages the official repos do
# not (jdtls), and no repo packages a helper — so build yay-bin by hand once.
# makepkg refuses to run as root, hence the uid check. Best-effort: a failure
# here must not sink the install, it only means pacman-only packages.
__bootstrap_aur_helper() {
    command -v yay >/dev/null 2>&1 && return 0
    command -v paru >/dev/null 2>&1 && return 0
    if [ "$(id -u)" -eq 0 ]; then
        echo "Note: skipping AUR helper bootstrap — makepkg refuses to run as root."
        return 1
    fi
    if [ "${DOTFILES_DRY_RUN:-0}" = "1" ]; then
        echo "  [dry-run] build yay-bin from the AUR (pacman base-devel git, then makepkg -si)"
        return 0
    fi

    echo "Bootstrapping yay (AUR helper)..."
    __pkg_sudo pacman -S --needed --noconfirm base-devel git || return 1

    local tmp
    tmp="$(mktemp -d)"
    if git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin" \
        && ( cd "$tmp/yay-bin" && makepkg -si --noconfirm ); then
        rm -rf "$tmp"
        return 0
    fi
    rm -rf "$tmp"
    return 1
}
