#!/bin/bash
# Idempotent setup from .env: writes one git profile per account, links hop
# and the active profile, adds the include lines to ~/.gitconfig and the
# source line to ~/.zshrc. Rerun it after editing .env or moving the repo.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$ROOT/.env"
PROFILES="${HOP_PROFILES:-$HOME/.config/hop}"
BIN_DIR="$HOME/.local/bin"
ACTIVE="$HOME/.gitconfig-active"
ZSHRC="$HOME/.zshrc"

if [ ! -f "$ENV_FILE" ]; then
  echo "pas de .env : cp .env.example .env, remplis-le, relance." >&2
  exit 1
fi
. "$ENV_FILE"

mkdir -p "$PROFILES" "$BIN_DIR"
for account in $HOP_ACCOUNTS; do
  prefix=$(echo "$account" | tr '[:lower:]' '[:upper:]')
  email=${prefix}_EMAIL key=${prefix}_SSH_KEY login=${prefix}_GITHUB
  # Only these keys are written: the env.var lines added by hop secret stay.
  f="$PROFILES/$account.gitconfig"
  git config -f "$f" user.email "${!email:?$email manquant dans .env}"
  git config -f "$f" core.sshCommand \
    "ssh -i ${!key:?$key manquant dans .env} -o IdentitiesOnly=yes"
  git config -f "$f" github.user "${!login:?$login manquant dans .env}"
done

ln -sfn "$ROOT/bin/hop" "$BIN_DIR/hop"
# Keep the current account across reinstalls and repo moves.
current=$(basename "$(readlink "$ACTIVE" || echo "$HOP_DEFAULT")" .gitconfig)
[ -f "$PROFILES/$current.gitconfig" ] || current=$HOP_DEFAULT
ln -sfn "$PROFILES/$current.gitconfig" "$ACTIVE"

# include must come before includeIf so the folder rule wins.
if ! git config --global --get-all include.path | grep -qxF '~/.gitconfig-active'; then
  git config --global --add include.path '~/.gitconfig-active'
fi
if [ -n "${HOP_REPO_ACCOUNT:-}" ]; then
  git -C "$ROOT" config include.path "$PROFILES/$HOP_REPO_ACCOUNT.gitconfig"
fi
if [ -n "${HOP_WORK_DIR:-}" ]; then
  git config --global "includeIf.gitdir:$HOP_WORK_DIR.path" \
    "$PROFILES/$HOP_WORK_ACCOUNT.gitconfig"
fi

# Exports the active profile's secrets in every new zsh. A line left by an
# older checkout of the repo is rewritten, not duplicated.
line="source $ROOT/shell/hop.zsh"
touch "$ZSHRC"
sed -i '' "s|^source .*/shell/hop\.zsh\$|$line|" "$ZSHRC"
grep -qxF "$line" "$ZSHRC" || printf '\n# hop account switcher\n%s\n' "$line" >> "$ZSHRC"

echo "hop installé, profil actif : $current"
