#!/usr/bin/env bash
# Install (or remove) the "restore tmux on login" LaunchAgent.
#
# The agent is what closes the reboot gap: the auto-save daemon keeps a snapshot
# fresh while you work, but after a restart nothing is running to rebuild the
# sessions until you log in. This loads a per-user agent that does exactly that.
#
# Usage: rescue-install-agent.sh [--uninstall] [--status]
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLIST_SRC="$(cd "$SCRIPT_DIR/.." && pwd)/com.bodyclock.tmux-rescue.plist"
LABEL="com.bodyclock.tmux-rescue"
PLIST_DST="$HOME/Library/LaunchAgents/$LABEL.plist"
DOMAIN="gui/$(id -u)"

usage() {
  printf 'Usage: %s [--uninstall] [--status]\n' "$(basename "$0")"
  exit "${1:-0}"
}

case "${1:-}" in
  --uninstall) ACTION=uninstall ;;
  --status) ACTION=status ;;
  "") ACTION=install ;;
  -h | --help) usage 0 ;;
  *) usage 2 ;;
esac

if [ "$ACTION" = "status" ]; then
  if launchctl print "$DOMAIN/$LABEL" >/dev/null 2>&1; then
    echo "$LABEL is loaded"
    launchctl print "$DOMAIN/$LABEL" 2>/dev/null | grep -E 'state|program|path' | head -5
  else
    echo "$LABEL is not loaded"
  fi
  [ -f "$PLIST_DST" ] && echo "installed at $PLIST_DST" || echo "not installed at $PLIST_DST"
  exit 0
fi

if [ "$ACTION" = "uninstall" ]; then
  launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null ||
    launchctl bootout "$DOMAIN" "$PLIST_DST" 2>/dev/null || true
  rm -f "$PLIST_DST"
  echo "removed $LABEL"
  exit 0
fi

# --- install ----------------------------------------------------------------
if [ ! -f "$PLIST_SRC" ]; then
  printf 'rescue-install-agent: missing %s\n' "$PLIST_SRC" >&2
  exit 1
fi

command -v launchctl >/dev/null 2>&1 || {
  printf 'rescue-install-agent: launchctl not found (this is macOS-only)\n' >&2
  exit 1
}

mkdir -p "$HOME/Library/LaunchAgents"
cp "$PLIST_SRC" "$PLIST_DST"

# Reload cleanly whether or not it was already loaded.
launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true

if ! launchctl bootstrap "$DOMAIN" "$PLIST_DST" 2>/dev/null; then
  printf 'rescue-install-agent: could not load the agent into %s\n' "$DOMAIN" >&2
  printf '  This usually means the shell is sandboxed or there is no GUI session.\n' >&2
  printf '  The file is in place at %s; run this in Terminal.app:\n' "$PLIST_DST" >&2
  printf '    launchctl bootstrap %s %s\n' "$DOMAIN" "$PLIST_DST" >&2
  exit 1
fi

printf 'installed and loaded %s\n' "$LABEL"
printf '  restores the last tmux environment at login (see\n'
printf '  %s/autostart.log)\n' "${TMUX_RESCUE_DIR:-$HOME/.local/share/tmux/rescue}"
