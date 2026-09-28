# hop

Switch between GitHub accounts on a Mac with one word: git identity, SSH
key, gh CLI and secrets, all at once.

## Setup

Needs macOS, git, [gh](https://cli.github.com) logged in to every account
(`gh auth login`), [fzf](https://github.com/junegunn/fzf), and one SSH key
per account, added to that account on GitHub.

```bash
cp .env.example .env   # your accounts, stays on your machine
./install.sh           # idempotent, rerun after editing .env
./test.sh              # checks every account against GitHub
```

## Usage

```bash
hop            # show the current account, then pick one
hop wombat     # switch to an account
hop s          # status only
hop secret             # secrets of the active account (names, never values)
hop secret set NAME    # store a value, hidden prompt
hop secret set NAME acme
```

Each switch asks GitHub over SSH who you are and ends with `OK` or
`ATTENTION`.

Repos under `HOP_WORK_DIR` always use `HOP_WORK_ACCOUNT`, whatever the
active account is.

## Secrets

Values live in the macOS Keychain (`hop:<account>:<NAME>`), profiles only
list their names. Every zsh exports the active account's values, and
`hop <account>` re-exports them in the current shell. Apps started before
a switch keep the old values until restarted.

## Changed outside the repo

- `~/.config/hop/<account>.gitconfig`: one profile per account, from `.env`
- `~/.local/bin/hop` -> `bin/hop`
- `~/.gitconfig-active` -> the active profile
- `~/.gitconfig`: one `include` and one `includeIf` line
- `~/.zshrc`: sources `shell/hop.zsh`
- macOS Keychain: one item per secret

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
