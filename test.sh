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
    echo "ECHEC $1 : attendu '$2', obtenu '$3'"
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

original=$(basename "$(readlink "$ACTIVE")" .gitconfig)
ssh_config_before=$(shasum "$HOME/.ssh/config")

for profile in "$PROFILES"/*.gitconfig; do
  name=$(basename "$profile" .gitconfig)
  login=$(field "$profile" github.user)
  (cd "$HOME" && "$HOP" "$name" >/dev/null)
  check "$name : email git" "$(field "$profile" user.email)" "$(git -C "$HOME" config user.email)"
  check "$name : compte SSH" "$login" "$(ssh_login "$HOME")"
  check "$name : compte gh" "$login" "$(gh api user -q .login)"
  for var in $(git config -f "$profile" --get-all env.var); do
    check "$name : variable $var exportée" "1" "$("$HOP" env | grep -c "^export $var=")"
  done
done

while read -r key profile; do
  dir=${key#includeif.gitdir:}
  dir=${dir%.path}
  dir=${dir/#\~/$HOME}
  profile=${profile/#\~/$HOME}
  probe="$dir$PROBE_NAME"
  mkdir -p "$probe" && git -C "$probe" init -q
  check "dossier $dir : email git" "$(field "$profile" user.email)" "$(git -C "$probe" config user.email)"
  check "dossier $dir : compte SSH" "$(field "$profile" github.user)" "$(ssh_login "$probe")"
  trash "$probe"
done < <(git config --global --get-regexp '^includeif\.gitdir:')

check "~/.ssh/config inchangé" "$ssh_config_before" "$(shasum "$HOME/.ssh/config")"

(cd "$HOME" && "$HOP" "$original" >/dev/null)
echo "profil restauré : $original"
exit $fail
