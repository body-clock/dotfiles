#!/usr/bin/env bash
# Periodic auto-save loop for the tmux rescue snapshot.
#
# Started once per tmux server by rescue-init.sh. Exits on its own when the
# server goes away (reboot, kill-server); tmux.conf starts a fresh one the next
# time a server comes up.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=rescue-common.sh
. "$SCRIPT_DIR/rescue-common.sh"

SAVE="$SCRIPT_DIR/rescue-save.sh"

mkdir -p "$TMUX_RESCUE_DIR" || exit 1

# --- one loop only, ever ----------------------------------------------------
if ! mkdir "$LOCKDIR" 2>/dev/null; then
  # Reclaim a lock left behind by a hard reboot, without racing another daemon
  # that is doing the same thing: mv is atomic, so only one of us can win it.
  stale=""
  if [ -f "$LOCKDIR/pid" ] && ! kill -0 "$(cat "$LOCKDIR/pid" 2>/dev/null)" 2>/dev/null; then
    stale="$LOCKDIR.stale.$$"
    if mv "$LOCKDIR" "$stale" 2>/dev/null; then
      rm -rf "$stale"
      mkdir "$LOCKDIR" 2>/dev/null || exit 0
    else
      exit 0
    fi
  else
    exit 0
  fi
fi
printf '%s\n' "$$" >"$LOCKDIR/pid"

cleanup() { rm -rf "$LOCKDIR"; }
trap cleanup EXIT INT TERM

# Save immediately so a crash right after login can't lose the session.
[ -x "$SAVE" ] && "$SAVE"

# Sleep in short hops so a signal is noticed promptly, and re-check that the
# server is still alive on each hop.
while tm list-sessions >/dev/null 2>&1; do
  slept=0
  while [ "$slept" -lt "$TMUX_RESCUE_INTERVAL" ]; do
    sleep 1
    slept=$((slept + 1))
    tm list-sessions >/dev/null 2>&1 || break 2
  done
  [ -x "$SAVE" ] && "$SAVE"
done

# Server is gone: fall through and let the EXIT trap release the lock. No
# self-restart — tmux.conf runs rescue-init.sh every time a server starts, and
# a second respawn path here just races it into overlapping daemons.
