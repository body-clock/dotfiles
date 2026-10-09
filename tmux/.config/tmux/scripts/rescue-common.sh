#!/usr/bin/env bash
# Shared helpers for the tmux rescue scripts. Sourced, not executed.
#
# Locates the tmux server that spawned us and exposes tm() to talk to it.
# Everything tmux spawns (run-shell jobs, the auto-save daemon) inherits $TMUX
# as "<socket>,<pid>,<session>", so we can address the exact server instead of
# hoping the default socket is the right one.

TMUX_RESCUE_DIR="${TMUX_RESCUE_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/tmux/rescue}"
TMUX_RESCUE_INTERVAL="${TMUX_RESCUE_INTERVAL:-900}"
SNAPSHOT="$TMUX_RESCUE_DIR/snapshot.txt"
LOG="$TMUX_RESCUE_DIR/autostart.log"
LOCKDIR="$TMUX_RESCUE_DIR/.daemon.lock"

TMUX_RESCUE_SOCK="${TMUX_RESCUE_SOCK:-${TMUX%%,*}}"

# Field separator for snapshots. Deliberately NOT a tab: `read` with a
# whitespace IFS collapses runs of delimiters, so an empty field (a pane with no
# start command) would silently shift every later field left. \x1f is
# non-whitespace, so empty fields stay empty.
SEP=$'\x1f'

tm() {
  if [ -n "$TMUX_RESCUE_SOCK" ]; then
    tmux -S "$TMUX_RESCUE_SOCK" "$@"
  else
    tmux "$@"
  fi
}
