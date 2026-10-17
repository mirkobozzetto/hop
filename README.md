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
hop secret list        # secrets of every account (names, never values)
hop secret list acme   # secrets of one account
hop secret set NAME    # store a value, one * per character typed or pasted
hop secret set NAME acme
hop ui         # hopla: accounts and secrets in one palette
```

Each switch asks GitHub over SSH who you are and ends with `OK` or
`WARNING`. `./test.sh` checks every account against GitHub.

## One terminal at a time

The account follows the folder. A `.hop` file holding an account name
sets it for that folder and everything below; the nearest one wins.
Elsewhere, the default account applies.

```bash
echo acme > ~/code/acme/.hop
```

Git, the SSH key, gh and the secrets switch for this terminal only,
checked at every prompt, in zsh and bash (Git Bash included). `hop wombat`
changes this terminal until you `cd` into another account's folder, and
leaves the other terminals alone. `hop -g wombat` changes the default:
new terminals, terminals outside a `.hop` folder, and apps started
outside a shell. hopla started in a terminal shows and switches that
terminal's account.

`install.sh` puts a `.hop` file in `HOP_WORK_DIR`, and an `includeIf` so
that git started outside a shell (an editor) follows the same rule.

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

- `~/.config/hop/`: one git profile per account, and secrets off macOS
- `~/.local/bin/hop`: runs `bin/hop`
- `~/.gitconfig-active`: includes the default profile
- `$TMPDIR/hop-shell-<pid>.gitconfig`: one terminal's profile, removed when
  it closes
- `~/.gitconfig`: one `include` and one `includeIf` line
- `.hop` in `HOP_WORK_DIR`
- `~/.zshrc` or `~/.bashrc`: sources `shell/hop.sh`
- `~/.claude-<account>/` with `HOP_CLAUDE=1`
