#!/bin/bash
# End-to-end check against the real GitHub: switches to every profile,
# verifies git, ssh and gh, checks the includeIf folder rules, then restores
# the profile that was active before.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
HOP="$ROOT/bin/hop"
PROFILES="${HOP_PROFILES:-$HOME/.config/hop}"
ACTIVE="$HOME/.gitconfig-active"
GH_HOST="github.com"
PROBE_NAME=".hop-test"

fail=0

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

ssh_login() {
  eval "$(git -C "$1" config core.sshCommand) -o ConnectTimeout=5 -T git@$GH_HOST" 2>&1 \
    | sed -n 's/^Hi \([^!]*\)!.*/\1/p'
}

original=$(basename "$(git config -f "$ACTIVE" include.path)" .gitconfig)
ssh_config_before=$(cksum "$HOME/.ssh/config" 2>/dev/null)

for profile in "$PROFILES"/*.gitconfig; do
  name=$(basename "$profile" .gitconfig)
  login=$(field "$profile" github.user)
  (cd "$HOME" && "$HOP" "$name" >/dev/null)
  check "$name: git email" "$(field "$profile" user.email)" "$(git -C "$HOME" config user.email)"
  check "$name: SSH account" "$login" "$(ssh_login "$HOME")"
  check "$name: gh account" "$login" "$(gh api user -q .login)"
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
  check "folder $dir: SSH account" "$(field "$profile" github.user)" "$(ssh_login "$probe")"
  rm -r "$probe"
done < <(git config --global --get-regexp '^includeif\.gitdir:')

check "~/.ssh/config unchanged" "$ssh_config_before" "$(cksum "$HOME/.ssh/config" 2>/dev/null)"

(cd "$HOME" && "$HOP" "$original" >/dev/null)
echo "restored account: $original"
exit $fail
