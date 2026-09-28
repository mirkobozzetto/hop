#!/bin/bash
# Installs or updates hop on macOS, Linux and Windows (Git Bash):
#   curl -fsSL https://raw.githubusercontent.com/mirkobozzetto/hop/main/install.sh | bash
# or ./install.sh from a clone. Asks for the accounts when .env is missing,
# writes one git profile per account, then wires git and the shell. Rerun it
# after editing .env or moving the repo.
set -euo pipefail

REPO_URL="${HOP_REPO:-https://github.com/mirkobozzetto/hop.git}"
HOP_HOME="${HOP_HOME:-$HOME/.hop}"
PROFILES="${HOP_PROFILES:-$HOME/.config/hop}"
BIN_DIR="$HOME/.local/bin"
ACTIVE="$HOME/.gitconfig-active"

# Piped into bash there is no script file: fetch the repo, rerun from it.
bootstrap() {
  command -v git >/dev/null || { echo "git introuvable, installe-le d'abord." >&2; exit 1; }
  if [ -d "$HOP_HOME/.git" ]; then
    git -C "$HOP_HOME" pull -q --ff-only
  else
    git clone -q "$REPO_URL" "$HOP_HOME"
  fi
  exec bash "$HOP_HOME/install.sh"
}

# ask VAR "question" [default]. Without a default the answer is required.
# Reads the terminal, since stdin is the script itself under curl | bash.
ask() {
  local answer
  while :; do
    printf '%s%s : ' "$2" "${3:+ [$3]}" >/dev/tty
    read -r answer </dev/tty || exit 1
    answer=${answer:-${3:-}}
    [ -n "$answer" ] || [ $# -ge 3 ] && break
  done
  printf -v "$1" '%s' "$answer"
}

write_env() {
  local accounts account prefix email key login work_dir work_account
  echo "Configuration de hop. Entrée garde la valeur entre crochets." >/dev/tty
  while :; do
    ask accounts "Noms des comptes, séparés par des espaces (ex. work perso)"
    printf '%s\n' $accounts | grep -qv '^[a-z][a-z0-9]*$' || break
    echo "minuscules et chiffres uniquement, sans tiret." >/dev/tty
  done
  ask work_dir "Dossier dont les dépôts gardent toujours le même compte (vide : aucun)" ""
  work_account=""
  if [ -n "$work_dir" ]; then
    work_dir="${work_dir%/}/"
    while :; do
      ask work_account "Compte de ce dossier" "${accounts%% *}"
      case " $accounts " in *" $work_account "*) break ;; esac
    done
  fi
  {
    echo "HOP_ACCOUNTS=\"$accounts\""
    echo "HOP_DEFAULT=${accounts%% *}"
    echo "HOP_REPO_ACCOUNT="
    printf 'HOP_WORK_DIR=%q\n' "$work_dir"
    printf 'HOP_WORK_ACCOUNT=%q\n' "$work_account"
  } > "$1"
  for account in $accounts; do
    echo "Compte $account" >/dev/tty
    ask email "  Email git"
    ask key "  Clé SSH" "~/.ssh/id_ed25519_$account"
    ask login "  Login GitHub"
    prefix=$(echo "$account" | tr '[:lower:]' '[:upper:]')
    printf '\n%s_EMAIL=%q\n%s_SSH_KEY=%q\n%s_GITHUB=%q\n' \
      "$prefix" "$email" "$prefix" "$key" "$prefix" "$login" >> "$1"
  done
  echo "Réponses enregistrées dans $1, modifiable à tout moment." >/dev/tty
}

rc_file() {
  case "${SHELL:-}" in
    */zsh) echo "$HOME/.zshrc" ;;
    *) echo "$HOME/.bashrc" ;;
  esac
}

main() {
  local src="${BASH_SOURCE[0]:-}"
  [ -n "$src" ] && [ -f "$(dirname "$src")/bin/hop" ] || bootstrap
  local root account prefix email key login keyfile current rc line
  root="$(cd "$(dirname "$src")" && pwd)"

  [ -f "$root/.env" ] || write_env "$root/.env"
  . "$root/.env"

  mkdir -p "$PROFILES" "$BIN_DIR"
  for account in $HOP_ACCOUNTS; do
    prefix=$(echo "$account" | tr '[:lower:]' '[:upper:]')
    email=${prefix}_EMAIL key=${prefix}_SSH_KEY login=${prefix}_GITHUB
    : "${!email:?$email manquant dans .env}" "${!key:?$key manquant dans .env}"
    : "${!login:?$login manquant dans .env}"
    # Only these keys are written: the env.var lines added by hop secret stay.
    git config -f "$PROFILES/$account.gitconfig" user.email "${!email}"
    git config -f "$PROFILES/$account.gitconfig" core.sshCommand \
      "ssh -i ${!key} -o IdentitiesOnly=yes"
    git config -f "$PROFILES/$account.gitconfig" github.user "${!login}"
    keyfile=${!key}
    [ -f "${keyfile/#\~/$HOME}" ] || echo "clé absente pour $account :" \
      "ssh-keygen -t ed25519 -f ${!key}, puis ajoute ${!key}.pub au compte" \
      "GitHub ${!login}." >&2
  done

  # A wrapper, not a symlink: Git Bash on Windows copies symlinks.
  rm -f "$BIN_DIR/hop"
  printf '#!/bin/bash\nexec "%s/bin/hop" "$@"\n' "$root" > "$BIN_DIR/hop"
  chmod +x "$BIN_DIR/hop"

  # include must come before includeIf so the folder rule wins.
  if ! git config --global --get-all include.path | grep -qxF '~/.gitconfig-active'; then
    git config --global --add include.path '~/.gitconfig-active'
  fi
  if [ -n "${HOP_REPO_ACCOUNT:-}" ]; then
    git -C "$root" config include.path "$PROFILES/$HOP_REPO_ACCOUNT.gitconfig"
  fi
  if [ -n "${HOP_WORK_DIR:-}" ]; then
    git config --global "includeIf.gitdir:$HOP_WORK_DIR.path" \
      "$PROFILES/$HOP_WORK_ACCOUNT.gitconfig"
  fi

  # Exports the active profile's secrets in every new shell. A line left by
  # an older install or another checkout is rewritten, not duplicated.
  rc=$(rc_file)
  line="source $root/shell/hop.sh"
  touch "$rc"
  if ! grep -qxF "$line" "$rc"; then
    sed -i.bak "s|^source .*/shell/hop\.z\{0,1\}sh\$|$line|" "$rc" && rm -f "$rc.bak"
    grep -qxF "$line" "$rc" || printf '\n# hop account switcher\n%s\n' "$line" >> "$rc"
  fi

  command -v gh >/dev/null || echo "gh introuvable, installe-le : https://cli.github.com" >&2

  # Keep the current account across reinstalls.
  current=$(git config -f "$ACTIVE" include.path 2>/dev/null || true)
  current=$(basename "${current:-$HOP_DEFAULT}" .gitconfig)
  [ -f "$PROFILES/$current.gitconfig" ] || current=$HOP_DEFAULT
  "$root/bin/hop" "$current"
  echo
  echo "hop est installé. Ouvre un nouveau terminal, puis tape hop."
}

main "$@"
