```
                           h o p !
                        .-~~~~~~~~~-.
           _____      .'             '.          ___
          |_____|    /                 \        (zzz)
           (o_o)    /       \(^o^)/     \       (-_-)
          <|###|>  /           |         \      /|~|\
           _/ \_  /           / \         \     _/ \_
      ~~~~~~~~~~~~~~~~                  ~~~~~~~~~~~~~~~~
         wile@acme                        sleepy@wombat
       "ship it by 5"                   "just one more nap"
```

# hop

Switch between GitHub accounts with one word: git identity, SSH key, gh
CLI and secrets, all at once. macOS, Linux, and Windows through Git Bash.

## Why hop

`gh auth switch` changes the account gh talks to, and stops there. Git
still commits with the same email and pushes with the same SSH key, and
nothing changes when you `cd` into another client's folder. gh's own
[notes on multiple accounts](https://github.com/cli/cli/blob/trunk/docs/multiple-accounts.md)
leave "automatic account switching based on some context (e.g. `pwd`,
`git remote`)" and setting `user.name` and `user.email` out of scope.

hop does all of it per folder: git identity, SSH key, gh, the HTTPS
token, your secrets and Claude Code. It refuses a commit made with the
wrong account, and `hop doctor` tells you what is missing.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/mirkobozzetto/hop/main/install.sh | bash
```

It asks for your accounts (email, SSH key, GitHub login), then sets
everything up. Run it again to update. Your answers stay in `~/.hop/.env`:
edit it, then run `~/.hop/install.sh`.

Needs git, [gh](https://cli.github.com) logged in to every account
(`gh auth login`), and one SSH key per account, added to that account on
GitHub. [fzf](https://github.com/junegunn/fzf) gives a nicer menu, not
required.

## Usage

```bash
hop            # show the current account, then pick one
hop wombat     # switch this terminal to an account
hop -g wombat  # switch the default for the whole machine
hop s          # status only
hop doctor     # check everything, say what to fix
hop secret list        # secrets of every account (names, never values)
hop secret list acme   # secrets of one account
hop secret set NAME    # store a value, one * per character typed or pasted
hop secret set NAME acme
hop ui         # hopla: accounts and secrets in one palette
```

Each switch asks GitHub over SSH who you are and ends with `OK` or
`WARNING`. `hop doctor` checks the shell, the folder's account, and for
every account the SSH key, whether GitHub knows it, the gh login and,
with `HOP_CLAUDE=1`, the Claude login. Each line is `ok`, or `fix` with
what to do. `./test.sh` runs it, then switches through every account.

## One terminal at a time

The account follows the folder. A `.hop` file holding an account name
sets it for that folder and everything below; the nearest one wins.
Elsewhere, the default account applies.

```bash
echo acme > ~/code/acme/.hop
```

Git, the SSH key, gh and the secrets switch for this terminal only, in
zsh and bash (Git Bash included): zsh on every `cd`, bash at the next
prompt, so in bash `cd repo && git push` still uses the account from
before the `cd`. `hop wombat`
changes this terminal until you `cd` into another account's folder, and
leaves the other terminals alone. `hop -g wombat` changes the default:
new terminals, terminals outside a `.hop` folder, and apps started
outside a shell. hopla started in a terminal shows and switches that
terminal's account.

`install.sh` puts a `.hop` file in `HOP_WORK_DIR`, and an `includeIf` so
that git started outside a shell (an editor) follows the same rule.

## Commit guard

git refuses a commit whose author is not the folder's account: the
nearest `.hop`, else this terminal's.

```
hop: this folder commits as acme <wile@acme.example>, not <sleepy@wombat.example>.
hop: run hop acme, or git commit --no-verify to skip the check.
```

It is a config hook (`hook.hop` in `~/.gitconfig`, git 2.54 or later), so
it runs next to a repo's own hooks (husky, lefthook, `.git/hooks`), never
instead of them. `git commit --no-verify` skips it, like any pre-commit
hook.

## HTTPS remotes

Each account's profile hands git its token through
`gh auth git-credential`, so an HTTPS remote is reached as the folder's
account, like an SSH one. The profile drops the helpers set before it
(`store`, `osxkeychain`) for github.com only.

## Claude Code

With `HOP_CLAUDE=1` in `.env`, each account also gets its own Claude Code
login, in `~/.claude-<account>`, switched with the folder through
`CLAUDE_CONFIG_DIR`. That folder links to everything in `~/.claude`, so
settings, skills and history stay shared; only the login differs. Run
`/login` once per account. A session keeps its account and git identity
even after a `cd`. Needs [jq](https://jqlang.org).

## Secrets

On macOS values live in the Keychain, elsewhere in
`~/.config/hop/<account>.secrets`, readable by you only. Every terminal
exports its account's values, and `hop <account>` re-exports them. Apps
started before a switch keep the old values until restarted.

## hopla

[hopla](https://github.com/mirkobozzetto/hopla) puts your accounts and
their secrets in one palette you type into: switch, copy (never shown),
add, replace, delete, even create an account. macOS, Linux and Windows.

```bash
curl -fsSL https://raw.githubusercontent.com/mirkobozzetto/hopla/main/install.sh | sh
hop ui
```

## Changed outside the repo

- `~/.config/hop/`: one git profile per account (email, SSH key, HTTPS
  token), and secrets off macOS
- `~/.local/bin/hop`: runs `bin/hop`
- `~/.gitconfig-active`: includes the default profile
- `$TMPDIR/hop-shell-<pid>.gitconfig`: one terminal's profile, removed when
  it closes
- `~/.gitconfig`: one `include` and one `includeIf` line, and the
  `hook.hop` commit guard
- `.hop` in `HOP_WORK_DIR`, and in this repo with `HOP_REPO_ACCOUNT`
- `~/.zshrc` or `~/.bashrc`: sources `shell/hop.sh`
- `~/.claude-<account>/` with `HOP_CLAUDE=1`
