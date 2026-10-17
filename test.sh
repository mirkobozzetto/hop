#!/bin/bash
# End-to-end check against the real GitHub: hop doctor checks every account's
# key and gh login, then this switches to every profile, verifies git and gh,
# checks the includeIf folder rules, and restores the profile that was active
# before.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
HOP="$ROOT/bin/hop"
PROFILES="${HOP_PROFILES:-$HOME/.config/hop}"
ACTIVE="$HOME/.gitconfig-active"
PROBE_NAME=".hop-test"

fail=0
# In this shell's own account, before leaving it for the machine's.
"$HOP" doctor || fail=1
echo
# Run from a hop shell, check the machine, not that shell's account.
unset GH_TOKEN GIT_CONFIG_COUNT HOP_ACTIVE

check() {
  if [ "$2" = "$3" ]; then
    echo "ok    $1"
  else
    echo "FAIL  $1: expected '$2', got '$3'"
    fail=1
  fi
}

field() {
  git config -f "$1" "$2"
}

original=$(basename "$(git config -f "$ACTIVE" include.path)" .gitconfig)
ssh_config_before=$(cksum "$HOME/.ssh/config" 2>/dev/null)

for profile in "$PROFILES"/*.gitconfig; do
  name=$(basename "$profile" .gitconfig)
  (cd "$HOME" && "$HOP" "$name" >/dev/null)
  check "$name: git email" "$(field "$profile" user.email)" "$(git -C "$HOME" config user.email)"
  check "$name: gh account" "$(field "$profile" github.user)" "$(gh api user -q .login)"
  for var in $(git config -f "$profile" --get-all env.var); do
    check "$name: $var exported" "1" "$("$HOP" env | grep -c "^export $var=")"
  done
done

while read -r key profile; do
  dir=${key#includeif.gitdir:}
  dir=${dir%.path}
  dir=${dir/#\~/$HOME}
  profile=${profile/#\~/$HOME}
  probe="$dir$PROBE_NAME"
  mkdir -p "$probe" && git -C "$probe" init -q
  check "folder $dir: git email" "$(field "$profile" user.email)" "$(git -C "$probe" config user.email)"
  rm -r "$probe"
done < <(git config --global --get-regexp '^includeif\.gitdir:')

check "~/.ssh/config unchanged" "$ssh_config_before" "$(cksum "$HOME/.ssh/config" 2>/dev/null)"

(cd "$HOME" && "$HOP" "$original" >/dev/null)
echo "restored account: $original"
exit $fail
