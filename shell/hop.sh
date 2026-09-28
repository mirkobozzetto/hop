# Sourced from ~/.zshrc or ~/.bashrc. Exports the active hop profile's
# secrets at shell start, and again after every switch made with hop.
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) PATH="$HOME/.local/bin:$PATH" ;; esac
eval "$(command hop env 2>/dev/null)"
hop() { command hop "$@" && eval "$(command hop env)"; }
