#!/usr/bin/env bash
# Rebuild the tmux environment from the snapshot written by rescue-save.sh.
#
# Recreates sessions, windows, per-pane working directories and window layouts.
# Existing sessions are never touched, so running this when tmux is already
# running is a no-op.
#
# Deliberately does NOT re-run commands that were in the foreground at save
# time: replaying a half-finished `rails server` or a database console after a
# reboot is more likely to cause harm than to help. The layouts and directories
# come back; the shell history is right there for the rest.
#
# Usage: rescue-restore.sh [--dry-run] [--force]
#   --dry-run  print what would be created, change nothing
#   --force    restore even if tmux already has sessions
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=rescue-common.sh
. "$SCRIPT_DIR/rescue-common.sh"

DRY_RUN=0
FORCE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --force) FORCE=1 ;;
    -h | --help) sed -n '2,15p' "$0"; exit 0 ;;
    *) printf 'rescue-restore: unknown option %s\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

if [ ! -s "$SNAPSHOT" ]; then
  printf 'rescue-restore: no snapshot at %s\n' "$SNAPSHOT" >&2
  exit 0
fi

if [ "$DRY_RUN" -eq 0 ] && [ "$FORCE" -eq 0 ] && tm list-sessions >/dev/null 2>&1; then
  printf 'rescue-restore: tmux already has sessions, nothing to do (use --force to override)\n' >&2
  exit 0
fi

printf 'rescue-restore: rebuilding from %s\n\n' "$SNAPSHOT"

# --- pass 1: sessions, windows, working directories -------------------------
# Snapshot order is preserved, so a session always exists before its later
# windows are appended to it.
current_session=""
while IFS="$SEP" read -r kind sess win_idx win_name pane_idx cwd start_cmd layout; do
  [ "$kind" = "session" ] || continue
  [ -n "$sess" ] || continue

  # shellcheck disable=SC2086  # $cwd is %q-quoted at save time
  eval "cwd=$cwd"

  if [ "$sess" != "$current_session" ]; then
    current_session="$sess"
    if [ "$DRY_RUN" -eq 1 ]; then
      printf 'session %s -> window "%s" (%s)\n' "$sess" "$win_name" "$cwd"
    elif ! tm new-session -d -s "$sess" -n "$win_name" -c "$cwd" 2>/dev/null; then
      printf '  ! could not create session %s\n' "$sess" >&2
    fi
  else
    if [ "$DRY_RUN" -eq 1 ]; then
      printf '  + window "%s" (%s)\n' "$win_name" "$cwd"
    elif ! tm new-window -d -t "$sess" -n "$win_name" -c "$cwd" 2>/dev/null; then
      printf '  ! could not add window "%s" to %s\n' "$win_name" "$sess" >&2
    fi
  fi
done <"$SNAPSHOT"

# --- pass 2: pane layouts ---------------------------------------------------
# Exactly one select-layout per window restores its split structure. De-duped
# with awk rather than trusting pane numbering, which base-index can change.
# pass 1: kind=1 sess=2 win=3 name=4 pane=5 cwd=6 start=7 layout=8
while IFS="$SEP" read -r sess win_idx layout; do
  [ -n "$sess" ] || continue
  [ -n "$layout" ] || continue
  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'layout %s:%s (%s)\n' "$sess" "$win_idx" "$layout"
  else
    tm select-layout -t "$sess:$win_idx" "$layout" 2>/dev/null ||
      printf '  ! could not set layout on %s:%s\n' "$sess" "$win_idx" >&2
  fi
done < <(awk -F"$SEP" -v OFS="$SEP" '$1=="session" && !seen[$2 ":" $3]++ { print $2, $3, $8 }' "$SNAPSHOT")

if [ "$DRY_RUN" -eq 1 ]; then
  printf '\nrescue-restore: dry run, nothing was changed\n'
  exit 0
fi

# Attach only when there is a real terminal to attach to; the login agent runs
# without a tty and must not try. A pane already inside tmux gets switched
# instead, so `prefix C-r` lands you in the restored session rather than a
# nested one.
first_session="$(awk -F"$SEP" '$1=="session"{print $2; exit}' "$SNAPSHOT")"
if [ -n "$first_session" ]; then
  if [ -n "${TMUX:-}" ]; then
    tm switch-client -t "$first_session" 2>/dev/null || true
  elif [ -t 0 ] && [ -t 1 ]; then
    exec tm attach-session -t "$first_session"
  fi
fi
