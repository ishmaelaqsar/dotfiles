"""Read packages.conf from Python, the way lib/pkg.sh reads it from bash.

The table maps one tool to the package name each manager uses. lib/pkg.sh
drives install.sh with it. This module gives the scripts in bin/ the same
mapping, so a message that names a package stays right on every distro.

Keep the two parsers in step. The precedence here matches __pkg_name, and the
detection order matches __detect_pkg_mgr.
"""

import shutil
import sys
from pathlib import Path

MANIFEST = Path(__file__).resolve().parent / "packages.conf"

# Managers that escalate on their own. The rest need sudo.
_NO_SUDO = ("brew", "yay", "paru")

_INSTALL_VERB = {
    "brew": "brew install",
    "apt": "apt install",
    "dnf": "dnf install",
    "pacman": "pacman -S",
    "yay": "yay -S",
    "paru": "paru -S",
}


def detect_manager():
    """Return the package manager of this host, or "none"."""
    # Prefer brew on macOS, then the native manager, then linuxbrew.
    if sys.platform == "darwin" and shutil.which("brew"):
        return "brew"
    for command, name in (
        ("apt-get", "apt"),
        ("yay", "yay"),
        ("paru", "paru"),
        ("pacman", "pacman"),
        ("dnf", "dnf"),
        ("brew", "brew"),
    ):
        if shutil.which(command):
            return name
    return "none"


def _rows():
    """Yield each row of the table as (commands, tags, overrides)."""
    if not MANIFEST.is_file():
        return
    for line in MANIFEST.read_text(encoding="utf-8").splitlines():
        line = line.split("#", 1)[0]
        if not line.strip():
            continue
        fields = [field.strip() for field in line.split("|")]
        fields += [""] * (3 - len(fields))
        yield fields[0], fields[1], fields[2]


def _row_of(tool):
    """Return the row a tool belongs to, or None."""
    for commands, tags, overrides in _rows():
        # A `~` marks a row no command answers to. It is not part of the name.
        if any(name.lstrip("~") == tool for name in commands.split(",")):
            return commands, tags, overrides
    return None


def package_name(manager, tool):
    """Return the package this manager installs to provide a tool."""
    row = _row_of(tool)
    if row is None:
        return tool
    commands, _tags, overrides = row

    tokens = [token.split("=", 1) for token in overrides.split() if "=" in token]
    for key in (manager, "*"):
        for token_key, value in tokens:
            if token_key == key:
                return value

    # No override: the identity of the row is its first command name.
    return commands.split(",")[0].lstrip("~")


def install_hint(tool, manager=None):
    """Return the command that installs a tool on this host."""
    manager = manager or detect_manager()
    package = package_name(manager, tool)
    verb = _INSTALL_VERB.get(manager)
    if verb is None:
        return f"install {package} with your package manager"
    sudo = "" if manager in _NO_SUDO else "sudo "
    return f"{sudo}{verb} {package}"
