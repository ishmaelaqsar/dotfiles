#!/usr/bin/env bash
set -euo pipefail

# Undo what install.sh / setup-*.sh put on this machine.
#
# System packages are never uninstalled (shared dependencies); the list to
# remove by hand is printed at the end.

FORCE=0
ALL=0
ASSUME_YES=0
DRY_RUN=0

__usage() {
    cat <<'EOF'
Usage: ./cleanup.sh [-f] [-a] [-y] [-n]

  -f             Skip the foreign-checkout guard.
  -a             Also remove the language toolchains setup-*.sh installed
                 (sdkman, quicklisp, uv, yk, Emacs packages). ~/go is never
                 touched, because it may hold your code.
  -y, --yes      Do not ask before removing anything.
  -n, --dry-run  Print what would be removed. Change nothing.
  -h, --help     Print this text.

The script asks once before it removes anything. Without a terminal it stops
instead, because it deletes: pass -y to run it from a script.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        -f)            FORCE=1 ;;
        -a)            ALL=1 ;;
        -y|--yes)      ASSUME_YES=1 ;;
        -n|--dry-run)  DRY_RUN=1 ;;
        -h|--help)     __usage; exit 0 ;;
        -*)            echo "Unknown option: $1" >&2; __usage >&2; exit 2 ;;
        *)             echo "cleanup.sh takes no argument: $1" >&2; __usage >&2; exit 2 ;;
    esac
    shift
done

# Exported, so the shared helpers in lib/pkg.sh plan instead of removing.
export DOTFILES_DRY_RUN="$DRY_RUN"
if [ "$DRY_RUN" -eq 1 ]; then
    echo "=== Dry run: nothing on this machine changes. ==="
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF_DIR="$(cd "$SCRIPT_DIR" && pwd -P)"

# The package table, so the summary at the end names what install.sh installs
# today rather than a list that drifts.
source "$SCRIPT_DIR/lib/pkg.sh"

# The global git keys install.sh writes. Sourced rather than repeated, so a key
# added there is unset here as well.
source "$SCRIPT_DIR/lib/gitconfig.sh"

# Same guard as install.sh: if a different checkout owns this home, nothing
# here was installed by this repository, and removing fonts or config would break that setup.
OTHER_DIR="$(cd "$HOME/.dotfiles" 2>/dev/null && pwd -P || true)"
if [ -n "$OTHER_DIR" ] && [ "$OTHER_DIR" != "$SELF_DIR" ] && [ "$FORCE" -ne 1 ]; then
    echo "A different dotfiles checkout owns this home ($OTHER_DIR) — refusing." >&2
    echo "Run with -f to force." >&2
    exit 1
fi

echo "This removes dotfiles symlinks, generated config, fonts$( [ "$ALL" -eq 1 ] && echo ', and language toolchains (sdkman, quicklisp, uv, yk, Emacs packages)')."
if [ "$DRY_RUN" -eq 1 ] || [ "$ASSUME_YES" -eq 1 ]; then
    :
elif read -r -p "Proceed? [y/N] " answer; then
    # An answer arrived, from a terminal or from a pipe. Anything but y stops.
    [[ "$answer" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
else
    # EOF: no terminal, and nothing piped in. This script deletes, so an
    # unanswered question fails rather than passing for a finished run.
    echo "No answer on stdin — pass -y to remove without the question." >&2
    exit 1
fi

removed=0

# Remove a path only if it is a symlink resolving into this repo. Resolve
# the link physically before the compare: install.sh may have linked through
# a checkout path with a symlinked component, and SELF_DIR is physical.
__rm_if_ours() {
    local dest=$1 target
    [ -L "$dest" ] || return 0
    target="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$dest")"
    if [[ "$target" == "$SELF_DIR"/* ]]; then
        __run rm "$dest"
        removed=$((removed + 1))
    fi
}

# GNOME desktop settings — put the saved pre-dotfiles values back
if command -v gsettings >/dev/null 2>&1; then
    echo "Restoring GNOME settings..."
    __run python3 "$SCRIPT_DIR/bin/gnome-settings" restore || true
fi

# GNOME Shell extension installed by install.sh
QUAKE_UUID="quake-terminal@diegodario88.github.io"
if command -v gnome-extensions >/dev/null 2>&1 \
   && gnome-extensions list 2>/dev/null | grep -qx "$QUAKE_UUID"; then
    echo "Removing the Quake Terminal GNOME extension..."
    __run gnome-extensions uninstall "$QUAKE_UUID" >/dev/null 2>&1 || true
    removed=$((removed + 1))
fi

# systemd user units — disable ours while the unit files still exist, and undo
# the SSH-agent handover and the podman socket install.sh set up
if command -v systemctl >/dev/null 2>&1 && [ -d "/run/user/$(id -u)" ]; then
    echo "Disabling systemd user units..."
    UNIT_SRC_DIR="$SCRIPT_DIR/dotfiles/.config/systemd/user"
    for unit_path in "$UNIT_SRC_DIR"/*.service "$UNIT_SRC_DIR"/*.timer "$UNIT_SRC_DIR"/*.socket; do
        [ -e "$unit_path" ] || continue
        grep -q '^\[Install\]' "$unit_path" || continue
        __run systemctl --user disable --now "$(basename "$unit_path")" >/dev/null 2>&1 || true
    done

    __run systemctl --user disable --now gpg-agent-ssh.socket >/dev/null 2>&1 || true
    __run systemctl --user disable --now podman.socket >/dev/null 2>&1 || true
    for unit in gcr-ssh-agent.socket gcr-ssh-agent.service gnome-keyring-ssh.service; do
        if [ "$(systemctl --user is-enabled "$unit" 2>/dev/null)" = "masked" ]; then
            echo "  -> Unmasking $unit"
            __run systemctl --user unmask "$unit" >/dev/null 2>&1 || true
        fi
    done
    __run systemctl --user daemon-reload >/dev/null 2>&1 || true
fi

echo "Removing symlinks into $SELF_DIR..."
while IFS= read -r -d '' src; do
    __rm_if_ours "$HOME/${src#"$SCRIPT_DIR/dotfiles/"}"
done < <(find "$SCRIPT_DIR/dotfiles" -type f -print0)

for src in "$SCRIPT_DIR"/bin/*; do
    [ -e "$src" ] && __rm_if_ours "$HOME/bin/$(basename "$src")"
done

echo "Removing managed ~/.bashrc.d files..."
if [ -d "$HOME/.bashrc.d" ]; then
    for rc in "$HOME/.bashrc.d"/*; do
        if [ -f "$rc" ] && grep -q '^# managed-by-dotfiles' "$rc"; then
            __run rm "$rc"
            removed=$((removed + 1))
        fi
    done
fi

echo "Removing 0xProto fonts..."
if [[ "$OSTYPE" == darwin* ]]; then FONT_DIR="$HOME/Library/Fonts"; else FONT_DIR="$HOME/.local/share/fonts"; fi
for f in "$SCRIPT_DIR"/general/0xProto/*.ttf; do
    dest="$FONT_DIR/$(basename "$f")"
    [ -f "$dest" ] && __run rm "$dest" && removed=$((removed + 1))
done
[[ "$OSTYPE" != darwin* ]] && command -v fc-cache >/dev/null 2>&1 && __run fc-cache -f "$FONT_DIR" || true

# Generated (non-symlink) config
if [ -f "$HOME/.config/ghostty/config.local" ]; then
    __run rm "$HOME/.config/ghostty/config.local"
    removed=$((removed + 1))
fi
if [ -f "$HOME/.gnupg/gpg-agent.conf" ] && grep -q 'Generated by dotfiles/install' "$HOME/.gnupg/gpg-agent.conf"; then
    __run rm "$HOME/.gnupg/gpg-agent.conf"
    removed=$((removed + 1))
    command -v gpg-connect-agent >/dev/null 2>&1 && __run gpg-connect-agent reloadagent /bye >/dev/null 2>&1 || true
fi

# Unset global git config keys, but only if they still hold the values install.sh sets
__git_unset_if() {
    local key=$1 expect=$2
    if [ "$(git config --global --get "$key" 2>/dev/null)" = "$expect" ]; then
        __run git config --global --unset "$key"
        removed=$((removed + 1))
    fi
}
if command -v git >/dev/null 2>&1; then
    echo "Unsetting global git config set by install.sh..."
    # Both lists, so every key install.sh writes comes back out. Leaving
    # core.pager behind would break `git diff` on a machine where the delta
    # package is later removed.
    while IFS='=' read -r key value; do
        __git_unset_if "$key" "$value"
    done <<< "$GIT_BASE_CONFIG
$GIT_DELTA_CONFIG"

    # The clean-gone alias, which this repository does not write. bin/git-gone
    # is the command. The value is a shell pipeline, so match a fragment.
    case "$(git config --global --get alias.clean-gone 2>/dev/null)" in
        *"branch -vv"*)
            __run git config --global --unset alias.clean-gone
            removed=$((removed + 1))
            ;;
    esac

    # The path varies by distro, so match on the helper name
    case "$(git config --global --get credential.helper 2>/dev/null)" in
        */git-credential-libsecret)
            __run git config --global --unset credential.helper
            removed=$((removed + 1))
            ;;
    esac
fi

if [ "$ALL" -eq 1 ]; then
    echo "Removing language toolchains..."
    __run rm -rf "$HOME/.sdkman" "$HOME/quicklisp" "$HOME/.local/share/uv"
    # yk is a clone plus a link into it. __rm_if_ours skips the link, because
    # it does not point into this repository.
    __run rm -rf "$HOME/.local/share/yk"
    case "$(readlink "$HOME/bin/yk" 2>/dev/null)" in
        *"/.local/share/yk/"*) __run rm -f "$HOME/bin/yk" ;;
    esac
    __run rm -f "${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/yk-remind"
    # Emacs: the packages and the state. init.el itself is a symlink, and the
    # symlink pass above removed it. The emacs-plus tap stays.
    __run rm -rf "$HOME/.config/emacs/elpa" "${XDG_STATE_HOME:-$HOME/.local/state}/emacs"
    __run rm -f "$HOME/.local/bin/uv" "$HOME/.local/bin/uvx"
    # uv tool shims are symlinks into ~/.local/share/uv, and the line above
    # left them dangling. Match on the target: deleting every dangling link in
    # ~/.local/bin would take the ones other tools own as well.
    for shim in "$HOME/.local/bin"/*; do
        [ -L "$shim" ] || continue
        case "$(readlink "$shim")" in
            *"/.local/share/uv/"*) __run rm -f "$shim" ;;
        esac
    done
    echo "Note: ~/go left alone (may contain your code) — remove gopls/dlv from ~/go/bin yourself."
    echo "Note: ~/.sbclrc may still reference quicklisp — edit it if you kept SBCL."
fi

echo
if [ "$DRY_RUN" -eq 1 ]; then
    echo "Dry run: $removed item(s) would be removed."
else
    echo "Done: $removed item(s) removed."
fi
echo "System packages are not uninstalled. Installed by these scripts (remove manually if wanted):"
# Every row that install.sh can select on some machine, by its first name.
TABLE_TOOLS="$(while IFS= read -r commands; do printf '%s ' "$(__pkg_primary "$commands")"; done < <(__pkg_select base linux desktop arch))"
echo "  install.sh:    ${TABLE_TOOLS}opencode ghostty, and yay on Arch"
echo "  System units left enabled (disable by hand): pcscd.socket, paccache.timer"
echo "  The podman machine on macOS stays: podman machine rm"
echo "  setup-c.sh:    build-essential/base-devel gdb lldb clangd cmake valgrind"
echo "  setup-go.sh:   go"
echo "  setup-sbcl.sh: sbcl"
echo "  setup-emacs.sh: emacs (emacs-plus@30 on macOS, and its tap)"
echo "  setup-yk.sh:   none — a clone under ~/.local/share/yk, which -a removes"
