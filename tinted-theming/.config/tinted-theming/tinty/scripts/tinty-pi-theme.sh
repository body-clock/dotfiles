#!/usr/bin/env bash
# tinty-pi-theme.sh  —  Generate a pi agent theme from the current tinty scheme
#
# Reads tinty's current-scheme state, finds the palette YAML, maps base16/base24
# colors to pi's 51 semantic colour tokens, and writes ~/.pi/agent/themes/tinted.json.
# Pi hot-reloads the theme automatically when the file changes.
#
# Hook into tinty config.toml:
#   [[items]]
#   name = "pi-agent"
#   path = "https://github.com/tinted-theming/base16-schemes"
#   hook = "~/.config/tinted-theming/tinty/scripts/tinty-pi-theme.sh"
#   themes-dir = "."
#
# Or simpler: chain it onto an existing hook in config.toml, e.g. the ghostty hook:
#   hook = "cp -f %f … && … && ~/.config/tinted-theming/tinty/scripts/tinty-pi-theme.sh"

set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────────────
TINTY_DATA="${TINTY_DATA:-$HOME/.local/share/tinted-theming/tinty}"
TINTY_SCHEMES="${TINTY_DATA}/repos/schemes"
TINTY_CUSTOM="${TINTY_DATA}/custom-schemes"
TINTY_STATE="${TINTY_DATA}/current_scheme"

PI_THEMES="${HOME}/.pi/agent/themes"
PI_THEME_FILE="${PI_THEMES}/tinted.json"

# ── Step 1 — grab current scheme name from tinty state ────────────────────
if [ ! -f "$TINTY_STATE" ]; then
  echo "[tinty-pi-theme] ERROR: current_scheme not found at $TINTY_STATE" >&2
  exit 1
fi

SCHEME_FULL=$(cat "$TINTY_STATE" | tr -d '\n[:space:]')
if [ -z "$SCHEME_FULL" ]; then
  echo "[tinty-pi-theme] ERROR: current_scheme is empty" >&2
  exit 1
fi

echo "[tinty-pi-theme] current scheme: $SCHEME_FULL" >&2

# ── Step 2 — locate the scheme YAML file ──────────────────────────────────
# scheme names:  base16-<name>   or   base24-<name>
SYSTEM="${SCHEME_FULL%%-*}"        # "base16" or "base24"
NAME="${SCHEME_FULL#*-}"          # everything after first dash

SCHEME_YAML=""
for dir in "$TINTY_SCHEMES/$SYSTEM" "$TINTY_CUSTOM/$SYSTEM"; do
  cand="$dir/$NAME.yaml"
  if [ -f "$cand" ]; then
    SCHEME_YAML="$cand"
    break
  fi
done

if [ -z "$SCHEME_YAML" ]; then
  echo "[tinty-pi-theme] ERROR: scheme YAML not found for $SCHEME_FULL" >&2
  exit 1
fi
echo "[tinty-pi-theme] scheme file: $SCHEME_YAML" >&2

# ── Step 3 — extract palette colours from YAML ────────────────────────────
parse_yaml_value() {
  local key="$1"
  grep -E "^[[:space:]]*${key}:" "$SCHEME_YAML" \
    | sed -E 's/^[^:]*:[[:space:]]*"?([^"]*)"?/\1/' \
    | head -1
}

# Normalize: strip # prefix if present, or add it
fmt_hex() {
  local v="$1"
  [ -z "$v" ] && { echo ""; return; }
  v="$(echo "$v" | tr -d '"' | xargs)"
  if [[ "$v" == \#* ]]; then echo "$v"
  else echo "#$v"
  fi
}

# Read variant (dark/light) — not currently used but useful metadata
VARIANT="$(parse_yaml_value "variant")"
[ -z "$VARIANT" ] && VARIANT="dark"

# Extract base16 colours — stored in simple indexed variables
# Backing array approach: use positional variables via eval to avoid
# associative-array requirement on macOS bash <4.
b00="$(fmt_hex "$(parse_yaml_value "base00")")"
b01="$(fmt_hex "$(parse_yaml_value "base01")")"
b02="$(fmt_hex "$(parse_yaml_value "base02")")"
b03="$(fmt_hex "$(parse_yaml_value "base03")")"
b04="$(fmt_hex "$(parse_yaml_value "base04")")"
b05="$(fmt_hex "$(parse_yaml_value "base05")")"
b06="$(fmt_hex "$(parse_yaml_value "base06")")"
b07="$(fmt_hex "$(parse_yaml_value "base07")")"
b08="$(fmt_hex "$(parse_yaml_value "base08")")"
b09="$(fmt_hex "$(parse_yaml_value "base09")")"
b0A="$(fmt_hex "$(parse_yaml_value "base0A")")"
b0B="$(fmt_hex "$(parse_yaml_value "base0B")")"
b0C="$(fmt_hex "$(parse_yaml_value "base0C")")"
b0D="$(fmt_hex "$(parse_yaml_value "base0D")")"
b0E="$(fmt_hex "$(parse_yaml_value "base0E")")"
b0F="$(fmt_hex "$(parse_yaml_value "base0F")")"

# Verify we got at least the critical colour (base00 / background)
if [ -z "$b00" ]; then
  echo "[tinty-pi-theme] ERROR: could not parse palette from $SCHEME_YAML" >&2
  exit 1
fi

# Named aliases — makes the mapping block below readable
bg0="$b00"    # Default Background
bg1="$b01"    # Lighter Background (panels, surfaces)
bg2="$b02"    # Selection Background
cmt="$b03"    # Comments, Invisibles
fg3="$b04"    # Dark Foreground / status text
fg0="$b05"    # Default Foreground
fg1="$b06"    # Light Foreground
bg3="$b07"    # Light Background (light themes)

red="$b08"    # Red: variables, XML tags, diff-deleted
org="$b09"    # Orange: numbers, constants, link URL
ylw="$b0A"    # Yellow: classes, markup bold
grn="$b0B"    # Green: strings, diff-inserted
cyn="$b0C"    # Cyan: support, regexp, quotes
blu="$b0D"    # Blue: functions, headings, links
pur="$b0E"    # Purple: keywords, storage
brn="$b0F"    # Brown: deprecated

# ── Step 4 — build the pi theme JSON ──────────────────────────────────────
mkdir -p "$PI_THEMES"

cat > "$PI_THEME_FILE" << THEME_EOF
{
  "\$schema": "https://raw.githubusercontent.com/earendil-works/pi-mono/main/packages/coding-agent/src/modes/interactive/theme/theme-schema.json",
  "name": "tinted",
  "version": "${SCHEME_FULL}",
  "vars": {
    "red":    "${red}",
    "orange": "${org}",
    "yellow": "${ylw}",
    "green":  "${grn}",
    "cyan":   "${cyn}",
    "blue":   "${blu}",
    "purple": "${pur}",
    "brown":  "${brn}",
    "bg":     "${bg0}",
    "bgLight": "${bg1}",
    "bgSelect": "${bg2}",
    "comment": "${cmt}",
    "fgDim":  "${fg3}",
    "fg":     "${fg0}",
    "fgLight": "${fg1}"
  },
  "colors": {
    "accent": "blue",
    "border": "comment",
    "borderAccent": "cyan",
    "borderMuted": "bgSelect",
    "success": "green",
    "error": "red",
    "warning": "yellow",
    "muted": "comment",
    "dim": "fgDim",
    "text": "",
    "thinkingText": "comment",

    "selectedBg": "bgSelect",
    "userMessageBg": "bgLight",
    "userMessageText": "",
    "customMessageBg": "bgLight",
    "customMessageText": "",
    "customMessageLabel": "purple",
    "toolPendingBg": "bgLight",
    "toolSuccessBg": "bgLight",
    "toolErrorBg": "bgLight",
    "toolTitle": "",
    "toolOutput": "fgDim",

    "mdHeading": "yellow",
    "mdLink": "blue",
    "mdLinkUrl": "orange",
    "mdCode": "cyan",
    "mdCodeBlock": "green",
    "mdCodeBlockBorder": "comment",
    "mdQuote": "comment",
    "mdQuoteBorder": "cyan",
    "mdHr": "comment",
    "mdListBullet": "cyan",

    "toolDiffAdded": "green",
    "toolDiffRemoved": "red",
    "toolDiffContext": "comment",

    "syntaxComment": "comment",
    "syntaxKeyword": "purple",
    "syntaxFunction": "blue",
    "syntaxVariable": "red",
    "syntaxString": "green",
    "syntaxNumber": "orange",
    "syntaxType": "yellow",
    "syntaxOperator": "",
    "syntaxPunctuation": "",

    "thinkingOff": "comment",
    "thinkingMinimal": "fgDim",
    "thinkingLow": "blue",
    "thinkingMedium": "cyan",
    "thinkingHigh": "yellow",
    "thinkingXhigh": "red",

    "bashMode": "green"
  }
}
THEME_EOF

echo "[tinty-pi-theme] wrote pi theme → $PI_THEME_FILE" >&2
echo "[tinty-pi-theme] scheme: ${SCHEME_FULL}  variant: ${VARIANT}" >&2
