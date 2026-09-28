# Sourced from ~/.zshrc. Exports the active hop profile's secrets at shell
# start, and again after every switch made with hop in this shell.
eval "$(command hop env 2>/dev/null)"
hop() { command hop "$@" && eval "$(command hop env)"; }
