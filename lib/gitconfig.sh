# shellcheck shell=bash
# The global git keys install.sh writes. One list, so the install step,
# `install.sh --check` and cleanup.sh cannot drift apart: each of the three
# iterates these variables rather than repeating the keys.
#
# Format: `key=value`, one per line. The value keeps every character after the
# first `=`, so a value may contain `=`.
#
# shellcheck disable=SC2034
# The variables below look unused here: install.sh and cleanup.sh source this
# file and read them.
#
# $HOME is read when this file is sourced. install.sh writes the global config
# for a real home install only, so a probe run into another directory never
# reaches these values.

GIT_USER_NAME="Ishmael Aqsar"
GIT_USER_EMAIL="ishmael-dev@aqsar.dev"

# Keys that need nothing beyond git itself.
GIT_BASE_CONFIG="user.name=$GIT_USER_NAME
user.email=$GIT_USER_EMAIL
core.excludesfile=$HOME/.gitignore_global
core.attributesfile=$HOME/.gitattributes"

# git needs these keys before it uses delta to render a diff. install.sh writes
# them only when delta is on PATH: a core.pager that is not installed breaks
# every `git diff`.
GIT_DELTA_CONFIG="core.pager=delta
interactive.diffFilter=delta --color-only
delta.navigate=true
delta.side-by-side=true
delta.line-numbers=true
merge.conflictStyle=zdiff3
diff.colorMoved=default"
