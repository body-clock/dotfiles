#!/usr/bin/env bash
# Snapshot the live tmux environment to a flat, greppable file.
#
# Records per pane: session, window index, window name, pane index, working
# directory, the command the pane was started with, and the window layout.
# Called on a timer by rescue-daemon.sh and manually via prefix + C-s.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=rescue-common.sh
. "$SCRIPT_DIR/rescue-common.sh"

mkdir -p "$TMUX_RESCUE_DIR" || exit 1
tm list-sessions >/dev/null 2>&1 || exit 0

tmp="$SNAPSHOT.$$"
: >"$tmp" || exit 1

# sessions, window index, window name, pane index, cwd, start command, layout
while IFS="$SEP" read -r sess win_idx win_name pane_idx cwd start_cmd layout; do
  [ -n "$sess" ] || continue
  # %q keeps directories containing spaces or quotes safe to parse on restore.
  # Built by joining rather than a fixed-count format: an extra argument would
  # make printf re-consume the whole format string and emit a second record.
  printf -v qcwd '%q' "$cwd"
  line="session"
  for field in "$sess" "$win_idx" "$win_name" "$pane_idx" "$qcwd" "$start_cmd" "$layout"; do
    line="$line$SEP$field"
  done
  printf '%s\n' "$line"
done < <(tm list-panes -a -F "#{session_name}${SEP}#{window_index}${SEP}#{window_name}${SEP}#{pane_index}${SEP}#{pane_current_path}${SEP}#{pane_start_command}${SEP}#{window_layout}") >"$tmp"

# An empty snapshot means no sessions; keep the previous one rather than
# clobbering a good snapshot with nothing.
if [ ! -s "$tmp" ]; then
  rm -f "$tmp"
  exit 0
fi

mv -f "$tmp" "$SNAPSHOT"
printf '%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" >"$TMUX_RESCUE_DIR/saved_at"
