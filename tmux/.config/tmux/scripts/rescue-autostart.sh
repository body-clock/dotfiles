#!/usr/bin/env bash
# Restore the last tmux environment on login. Installed as a LaunchAgent by
# rescue-install-agent.sh, or run by hand.
#
# Restore-only: this never starts the periodic saver. The saver is started by
# tmux.conf when a tmux server actually comes up, so nothing here can race it.
set -uo pipefail

# launchd hands us a minimal environment; make sure brew and tmux are findable.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${HOME}/.local/bin:${PATH:-}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=rescue-common.sh
. "$SCRIPT_DIR/rescue-common.sh"

mkdir -p "$TMUX_RESCUE_DIR" 2>/dev/null

# Already running (e.g. this fired on a re-login, or the terminal won the race)
# — leave the live session alone.
if tm list-sessions >/dev/null 2>&1; then
  printf '%s: tmux already running, skipping restore\n' "$(date '+%Y-%m-%d %H:%M:%S')" >>"$LOG"
  exit 0
fi

if [ ! -s "$SNAPSHOT" ]; then
  printf '%s: no snapshot yet, nothing to restore\n' "$(date '+%Y-%m-%d %H:%M:%S')" >>"$LOG"
  exit 0
fi

printf '%s: restoring\n' "$(date '+%Y-%m-%d %H:%M:%S')" >>"$LOG"
# Claim the restore for this login before doing it, so a tmux server that comes
# up concurrently does not also try via tmux.conf.
tm set-environment -g TMUX_RESCUE_STARTED 1 2>/dev/null || true
"$SCRIPT_DIR/rescue-restore.sh" </dev/null >>"$LOG" 2>&1
printf '%s: restore finished (exit %s)\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$?" >>"$LOG"
