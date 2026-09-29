#!/usr/bin/env bash
# Secret gate test: runs the hooks in hooks/ against a scratch repository and
# a local bare remote. Needs bash, git, and python3, and runs from any
# directory:
#
#   bash test/hooks.sh
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
pass() { echo "PASS: $*"; }
flunk(){ echo "FAIL: $*"; FAIL=1; }

# The machine's git config must not change the result: a signing key, a global
# hooksPath, or useConfigOnly would each break a scratch commit.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# The token and the value are built at run time, so this file holds no
# literal that the pre-commit scan of this repository would catch.
TOKEN="ghp_$(printf 'a%.0s' {1..36})"
VALUE="$(printf 'a%.0s' {1..24})"

git init -q --bare -b main "$WORK/remote.git"
git init -q -b main "$WORK/local"
cd "$WORK/local" || exit 1
cp -R "$REPO/hooks" hooks
git config core.hooksPath hooks
git remote add origin "$WORK/remote.git"
git add hooks
git commit -q -m "hooks"
git push -q origin main 2>/dev/null \
    && pass "a clean push passes" || flunk "a clean push failed"

echo "note = clean" > clean.txt
git add clean.txt
git commit -q -m "clean" \
    && pass "a clean commit passes" || flunk "a clean commit failed"
git push -q origin main 2>/dev/null \
    && pass "a clean push to an existing branch passes" || flunk "a clean push to an existing branch failed"

echo "token = $TOKEN" > leak.txt
git add leak.txt
if git commit -q -m "leak" 2>/dev/null; then
    flunk "pre-commit let a token through"
else
    pass "pre-commit stops a token"
fi
git reset -q --hard

# An added line whose content starts with ++ shows as +++ in the diff, the
# same prefix as a file header.
printf '%s\n' "++token: $VALUE" > plus.txt
git add plus.txt
if git commit -q -m "plus" 2>/dev/null; then
    flunk "pre-commit let a +++ line through"
else
    pass "pre-commit stops a +++ line"
fi
git reset -q --hard

echo "token = $TOKEN" > leak.txt
git add leak.txt
git commit -q --no-verify -m "leak past pre-commit"
if git push -q origin main 2>/dev/null; then
    flunk "pre-push let a --no-verify commit through"
else
    pass "pre-push stops a --no-verify commit"
fi

# A second clone moves the remote to a commit this repository never fetched.
# The hook cannot list the commits in that range, so it must refuse the push.
git clone -q "$WORK/remote.git" "$WORK/other" 2>/dev/null
git -C "$WORK/other" commit -q --allow-empty -m "elsewhere"
git -C "$WORK/other" push -q origin main 2>/dev/null
if git push -q --force origin main 2>/dev/null; then
    flunk "pre-push let a force-push over an unknown remote tip through"
else
    pass "pre-push stops a force-push over an unknown remote tip"
fi

exit "$FAIL"
