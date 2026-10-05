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
hop wombat     # switch to an account
hop s          # status only
hop secret list        # secrets of every account (names, never values)
hop secret list acme   # secrets of one account
hop secret set NAME    # store a value, one * per character typed or pasted
hop secret set NAME acme
hop ui         # hopla: the vault of secrets, in the terminal (macOS)
```

Each switch asks GitHub over SSH who you are and ends with `OK` or
`WARNING`. Repos under `HOP_WORK_DIR` always use `HOP_WORK_ACCOUNT`.
`./test.sh` checks every account against GitHub.

## Secrets

On macOS values live in the Keychain, elsewhere in
`~/.config/hop/<account>.secrets`, readable by you only. Every new shell
exports the active account's values, and `hop <account>` re-exports them.
Apps started before a switch keep the old values until restarted.

## hopla

A full-screen vault for these secrets, macOS only. Install it once with
[Rust](https://rustup.rs), then open it with `hop ui`:

```bash
cargo install --path ~/.hop/hopla
```

Enter unlocks with Touch ID, or the session password: the vault door
opens and Lapla, the bank's bunny, tips his hat. Each account is a room of
deposit boxes. ← → walk to the next room, ↑ ↓ pick a box, `/` searches.

- `y` copies a value through a slot machine. A value is never shown: it
  skips clipboard history apps and leaves the clipboard after 30 s or when
  hopla quits.
- Enter deposits a value in the selected box, typed blind, one `*` per
  character; `n` adds a new box, `d` empties one. Same rules as
  `hop secret set`.
- `L` locks, and so do 5 minutes without a key.

Lapla has a few surprises. Touch ID guards the screen, not the Keychain:
any of your programs can still read these items.

## Changed outside the repo

- `~/.config/hop/`: one git profile per account, and secrets off macOS
- `~/.local/bin/hop`: runs `bin/hop`
- `~/.gitconfig-active`: includes the active profile
- `~/.gitconfig`: one `include` and one `includeIf` line
- `~/.zshrc` or `~/.bashrc`: sources `shell/hop.sh`
