# Sourced from ~/.zshrc or ~/.bashrc. Accounts follow the folder: the nearest
# .hop above it names the account (~/code/acme/.hop says acme), elsewhere the
# active hop account applies. Git, the SSH key, gh and the hop secrets switch
# for this shell only, checked at every prompt. hop -g changes the default
# for the whole machine. HOP_CLAUDE=1 in hop's .env gives every account its
# own Claude Code login as well.
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) PATH="$HOME/.local/bin:$PATH" ;; esac

HOP_PROFILES=${HOP_PROFILES:-$HOME/.config/hop}
# This shell's own include: git reads it, hop switches it, nothing global.
_hop_file=${TMPDIR:-/tmp}
_hop_file=${_hop_file%/}/hop-shell-$$.gitconfig

# zsh gives a sourced file's path in $0, bash in BASH_SOURCE.
_hop_root=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)
_hop_claude=
if [ -f "$_hop_root/.env" ]; then
  while IFS='=' read -r _hop_key _hop_value; do
    [ "$_hop_key" = HOP_CLAUDE ] && _hop_claude=$_hop_value
  done < "$_hop_root/.env"
  unset _hop_key _hop_value
fi

# The account an include file points at, in REPLY. Builtins only: this runs
# at every prompt, and every fork is slow in Git Bash.
_hop_included() {
  REPLY=
  [ -f "$1" ] || return 0
  local line
  while IFS= read -r line; do
    case $line in
      *path\ =*)
        REPLY=${line##*/}
        REPLY=${REPLY%.gitconfig}
        ;;
    esac
  done < "$1"
}

# The account of a folder, in REPLY: the nearest .hop above it, else the
# active hop account.
_hop_account_for() {
  local dir=$1
  while :; do
    if [ -f "$dir/.hop" ]; then
      read -r REPLY < "$dir/.hop"
      return 0
    fi
    [ -n "$dir" ] || break
    dir=${dir%/*}
  done
  _hop_included "$HOME/.gitconfig-active"
}

# Points this shell's git, SSH key, gh and secrets at one hop profile. hop
# and hopla read HOP_ACTIVE, so they switch this shell only.
_hop_github() {
  local profile="$HOP_PROFILES/$1.gitconfig"
  git config -f "$_hop_file" include.path "$profile"
  export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=include.path GIT_CONFIG_VALUE_0="$_hop_file"
  export HOP_ACTIVE="$_hop_file" HOP_GH_ACCOUNT="$1"
  eval "$(command hop env)"
  HOP_GH_USER=$(git config -f "$profile" github.user)
  GH_TOKEN=$(gh auth token -h "${HOP_GH_HOST:-github.com}" -u "$HOP_GH_USER" 2>/dev/null)
  export HOP_GH_USER GH_TOKEN
}

# ~/.claude-<account> holds links to everything in ~/.claude (settings, rules,
# skills, history) plus its own account file, so its login stays separate.
# jq copies ~/.claude.json without the login in it.
# ponytail: a file Claude rewrites in place there (settings.json via /config)
# stops being a link and diverges; delete it and cd again to relink.
_hop_claude_dir() {
  local dir="$HOME/.claude-$1" f
  if [ ! -d "$dir" ]; then
    command -v jq >/dev/null || { echo "hop: HOP_CLAUDE needs jq" >&2; return 1; }
    mkdir -p "$dir"
    if [ -f "$HOME/.claude.json" ]; then
      jq 'del(.oauthAccount)' "$HOME/.claude.json" > "$dir/.claude.json"
      chmod 600 "$dir/.claude.json"
    fi
  fi
  [ -n "${ZSH_VERSION:-}" ] && setopt local_options null_glob
  for f in "$HOME"/.claude/* "$HOME"/.claude/.[!.]*; do
    # bash keeps a pattern that matched nothing.
    [ -e "$f" ] || continue
    case ${f##*/} in .claude.json | .credentials.json | .git) continue ;; esac
    [ -e "$dir/${f##*/}" ] || [ -L "$dir/${f##*/}" ] || ln -s "$f" "$dir/${f##*/}"
  done
  export CLAUDE_CONFIG_DIR="$dir"
}

_hop_follow_dir() {
  # A Claude session keeps the account it was started with, even after a cd.
  [ -n "${CLAUDECODE:-}" ] && return 0
  _hop_account_for "$PWD"
  local account=$REPLY
  if [ -z "$account" ] || [ "$account" = "${HOP_ACCOUNT:-}" ]; then return 0; fi
  if [ -f "$HOP_PROFILES/$account.gitconfig" ]; then
    _hop_github "$account"
  else
    # An account without a hop profile (a client that only lends Claude)
    # keeps the active hop account for GitHub.
    _hop_included "$HOME/.gitconfig-active"
    _hop_github "$REPLY"
  fi
  export HOP_ACCOUNT="$account"
  if [ "$_hop_claude" = 1 ]; then _hop_claude_dir "$account"; fi
}

# Every prompt: a cd into another account's folder, or a switch another
# program made on this shell's include (hopla), takes effect.
_hop_prompt() {
  local rc=$?
  _hop_follow_dir
  if [ -z "${CLAUDECODE:-}" ]; then
    _hop_included "$_hop_file"
    [ -z "$REPLY" ] || [ "$REPLY" = "${HOP_GH_ACCOUNT:-}" ] || _hop_github "$REPLY"
  fi
  return $rc
}

_hop_forget() { rm -f "$_hop_file"; }

if [ -n "${ZSH_VERSION:-}" ]; then
  autoload -Uz add-zsh-hook
  add-zsh-hook precmd _hop_prompt
  add-zsh-hook zshexit _hop_forget
else
  # Ahead of the other hooks, which may read $? and get it back.
  case ${PROMPT_COMMAND:-} in
    *_hop_prompt*) ;;
    *) PROMPT_COMMAND="_hop_prompt${PROMPT_COMMAND:+;$PROMPT_COMMAND}" ;;
  esac
  [ -n "$(trap -p EXIT)" ] || trap _hop_forget EXIT
fi

if [ -z "${CLAUDECODE:-}" ]; then
  # The folder the shell starts in decides, whatever was inherited.
  HOP_ACCOUNT=
  _hop_follow_dir
elif [ -z "${HOP_GH_ACCOUNT:-}" ]; then
  # A Claude session started outside a hop shell: the active account.
  eval "$(command hop env 2>/dev/null)"
fi

# hop switches GitHub for this shell only, until a cd into another account's
# folder. hop -g changes the default for the whole machine.
hop() {
  if [ "${1:-}" = -g ] || [ "${1:-}" = --global ]; then
    shift
    # The shell's own account must not leak into the global switch.
    (unset GH_TOKEN GIT_CONFIG_COUNT HOP_ACTIVE; command hop "$@") || return
    HOP_ACCOUNT=
    _hop_follow_dir
    return
  fi
  if [ ! -f "$_hop_file" ]; then
    _hop_included "$HOME/.gitconfig-active"
    _hop_github "${HOP_GH_ACCOUNT:-$REPLY}"
  fi
  HOP_ACTIVE="$_hop_file" command hop "$@" || return
  # Again even without a switch: hop secret set may have added a value.
  _hop_included "$_hop_file"
  _hop_github "$REPLY"
}

if [ "$_hop_claude" = 1 ]; then
  # Git is pinned for the whole session: a session started for one account
  # that cds into another account's repo still commits and pushes as the first.
  claude() {
    GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=include.path \
      GIT_CONFIG_VALUE_0="$HOP_PROFILES/$HOP_GH_ACCOUNT.gitconfig" command claude "$@"
  }
fi
