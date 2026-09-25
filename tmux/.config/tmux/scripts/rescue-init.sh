#!/usr/bin/env bash
# Start the auto-save daemon for this tmux server, if it isn't already running.
# Invoked once from tmux.conf when a tmux server starts. Safe to run repeatedly:
# rescue-daemon.sh takes an exclusive lock, so at most one loop ever lives.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=rescue-common.sh
. "$SCRIPT_DIR/rescue-common.sh"

# Detach completely so the daemon outlives this run-shell invocation. $TMUX is
# inherited, which is how the daemon keeps addressing this exact server.
nohup "$SCRIPT_DIR/rescue-daemon.sh" </dev/null >/dev/null 2>&1 &
