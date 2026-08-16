# shellcheck shell=bash
# Shared package-manager plumbing for install.sh and setup-*.sh.
# Usage: source this, then PKG_MGR="$(__detect_pkg_mgr)".

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

# Map a tool name to this manager's package name
__pkg_name() {
    local mgr=$1 tool=$2
    case "$mgr:$tool" in
        brew:fd)              echo "fd" ;;
        apt:fd|dnf:fd)        echo "fd-find" ;;
        *:fd)                 echo "fd" ;;
        brew:bash-completion) echo "bash-completion@2" ;;
        *:bash-completion)    echo "bash-completion" ;;
        brew:pinentry)        echo "pinentry-mac" ;;
        apt:pinentry)         echo "pinentry-gnome3" ;;
        *:pinentry)           echo "pinentry" ;;
        apt:pcscd)            echo "pcscd" ;;
        dnf:pcscd)            echo "pcsc-lite" ;;
        *:pcscd)              echo "pcsclite" ;;
        apt:ccid)             echo "libccid" ;;
        dnf:ccid)             echo "pcsc-lite-ccid" ;;
        *:ccid)               echo "ccid" ;;
        dnf:gnupg)            echo "gnupg2" ;;
        *:wl-copy)            echo "wl-clipboard" ;;
        *:paccache)           echo "pacman-contrib" ;;
        apt:go|dnf:go)        echo "golang" ;;
        apt:clangd)           echo "clangd" ;;
        pacman:clangd|yay:clangd|paru:clangd) echo "clang" ;;
        dnf:clangd)           echo "clang-tools-extra" ;;
        *)                    echo "$tool" ;;
    esac
}

# Install tools by command name, skipping ones already present.
# Best-effort: one missing package must not sink the rest.
__pkg_install() {
    local mgr=$1; shift
    local tool pkg failed=""
    for tool in "$@"; do
        command -v "$tool" >/dev/null 2>&1 && continue
        pkg="$(__pkg_name "$mgr" "$tool")"
        echo "  -> Installing $pkg ($mgr)"
        __pkg_raw "$mgr" "$pkg" || failed="$failed $tool"
    done
    if [ -n "$failed" ]; then
        echo "Warning: could not install:$failed — install manually." >&2
    fi
}

# Run privileged: direct when already root (containers, root bootstraps)
__pkg_sudo() {
    if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo "$@"; fi
}

# Install raw package names with no mapping or presence check
__pkg_raw() {
    local mgr=$1; shift
    case "$mgr" in
        brew)     brew install "$@" ;;
        apt)      __pkg_sudo apt-get install -y "$@" ;;
        yay|paru) "$mgr" -S --needed --noconfirm "$@" ;;
        pacman)   __pkg_sudo pacman -S --needed --noconfirm "$@" ;;
        dnf)      __pkg_sudo dnf install -y "$@" ;;
        *)        echo "No supported package manager found." >&2; return 1 ;;
    esac
}

# True when this manager can reach the AUR
__is_aur_helper() {
    [ "$1" = "yay" ] || [ "$1" = "paru" ]
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
