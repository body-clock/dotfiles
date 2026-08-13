#!/usr/bin/env bash
# tinty-tuicr-theme.sh  —  Generate a tuicr local theme from the current tinty scheme
#
# Reads tinty's current-scheme state, finds the palette YAML, maps base16
# colors to tuicr's ~42 UI colour keys, and writes
# ~/.config/tuicr/themes/tinted.toml.
#
# tuicr picks up the local theme when you run:
#   tuicr --theme tinted
# or set `theme = "tinted"` in ~/.config/tuicr/config.toml.
#
# Hook into tinty config.toml:
#   [[items]]
#   name = "tuicr"
#   path = "https://github.com/tinted-theming/base16-schemes"
#   hook = "~/.config/tinted-theming/tinty/scripts/tinty-tuicr-theme.sh"
#   themes-dir = "."

set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────────────
TINTY_DATA="${TINTY_DATA:-$HOME/.local/share/tinted-theming/tinty}"
TINTY_SCHEMES="${TINTY_DATA}/repos/schemes"
TINTY_CUSTOM="${TINTY_DATA}/custom-schemes"
TINTY_STATE="${TINTY_DATA}/current_scheme"

TUICR_THEMES="${HOME}/.config/tuicr/themes"
TUICR_TOML="${TUICR_THEMES}/tinted.toml"
TUICR_TMTHEME="${TUICR_THEMES}/tinted.tmTheme"

# ── Helpers ────────────────────────────────────────────────────────────────
parse_yaml_value() {
  local key="$1"
  grep -E "^[[:space:]]*${key}:" "$SCHEME_YAML" \
    | sed -E 's/^[^:]*:[[:space:]]*"?([^"]*)"?/\1/' \
    | head -1
}

fmt_hex() {
  local v="$1"
  [ -z "$v" ] && { echo ""; return; }
  v="$(echo "$v" | tr -d '"' | xargs)"
  if [[ "$v" == \#* ]]; then echo "$v"
  else echo "#$v"
  fi
}

# Blend two hex colours: blend $base $accent $pct
# pct=0 → 100% base; pct=100 → 100% accent
blend() {
  local base="$1" accent="$2" pct="$3"
  # strip # prefix
  local br bg bb ar ag ab
  br=$((16#${base:1:2}))
  bg=$((16#${base:3:2}))
  bb=$((16#${base:5:2}))
  ar=$((16#${accent:1:2}))
  ag=$((16#${accent:3:2}))
  ab=$((16#${accent:5:2}))
  local inv=$((100 - pct))
  local r=$(( (br * inv + ar * pct) / 100 ))
  local g=$(( (bg * inv + ag * pct) / 100 ))
  local b=$(( (bb * inv + ab * pct) / 100 ))
  printf "#%02x%02x%02x" "$r" "$g" "$b"
}

# Determine if a hex colour is dark (avg < 128)
is_dark() {
  local hex="$1"
  local r g b avg
  r=$((16#${hex:1:2}))
  g=$((16#${hex:3:2}))
  b=$((16#${hex:5:2}))
  avg=$(( (r + g + b) / 3 ))
  [ "$avg" -lt 128 ]
}

# ── Step 1 — grab current scheme name from tinty state ────────────────────
if [ ! -f "$TINTY_STATE" ]; then
  echo "[tinty-tuicr] ERROR: current_scheme not found at $TINTY_STATE" >&2
  exit 1
fi

SCHEME_FULL=$(cat "$TINTY_STATE" | tr -d '\n[:space:]')
if [ -z "$SCHEME_FULL" ]; then
  echo "[tinty-tuicr] ERROR: current_scheme is empty" >&2
  exit 1
fi

echo "[tinty-tuicr] current scheme: $SCHEME_FULL" >&2

# ── Step 2 — locate the scheme YAML file ──────────────────────────────────
SYSTEM="${SCHEME_FULL%%-*}"
NAME="${SCHEME_FULL#*-}"

SCHEME_YAML=""
for dir in "$TINTY_SCHEMES/$SYSTEM" "$TINTY_CUSTOM/$SYSTEM"; do
  cand="$dir/$NAME.yaml"
  if [ -f "$cand" ]; then
    SCHEME_YAML="$cand"
    break
  fi
done

if [ -z "$SCHEME_YAML" ]; then
  echo "[tinty-tuicr] ERROR: scheme YAML not found for $SCHEME_FULL" >&2
  exit 1
fi
echo "[tinty-tuicr] scheme file: $SCHEME_YAML" >&2

# ── Step 3 — extract base16 palette ───────────────────────────────────────
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

if [ -z "$b00" ]; then
  echo "[tinty-tuicr] ERROR: could not parse palette from $SCHEME_YAML" >&2
  exit 1
fi

# ── Step 4 — derive blended/computed colours ──────────────────────────────
# tuicr internal: blend(panel_bg, green, 20) → diff_add_bg
#                 blend(panel_bg, red, 20)   → diff_del_bg
#                 blend(panel_bg, green, 16) → syntax_add_bg
#                 blend(panel_bg, red, 16)   → syntax_del_bg
diff_add_bg="$(blend "$b00" "$b0B" 20)"
diff_del_bg="$(blend "$b00" "$b08" 20)"
syntax_add_bg="$(blend "$b00" "$b0B" 16)"
syntax_del_bg="$(blend "$b00" "$b08" 16)"

# accent foreground for message/mode badges:
#   dark panel → use base00 (dark) for fg on bright badges
#   light panel → use base07 (light) for fg on bright badges
if is_dark "$b00"; then
  accent_fg="$b00"
else
  accent_fg="$b07"
fi

# Variant for mode/message badges: dark bg → light-ish accent text
if is_dark "$b00"; then
  mode_accent_fg="$b00"
else
  mode_accent_fg="$b07"
fi

# ── Step 5 — write tuicr UI theme TOML + syntax .tmTheme ────────────────
mkdir -p "$TUICR_THEMES"

cat > "$TUICR_TOML" << TUICR_EOF
# tuicr local theme generated by tinty-tuicr-theme.sh
# Scheme: ${SCHEME_FULL}

# Base colours
panel_bg = "${b00}"
bg_highlight = "${b01}"
fg_primary = "${b05}"
fg_secondary = "${b04}"
fg_dim = "${b03}"

# Diff colours
diff_add = "${b0B}"
diff_add_bg = "${diff_add_bg}"
diff_del = "${b08}"
diff_del_bg = "${diff_del_bg}"
diff_context = "${b05}"
diff_hunk_header = "${b0D}"
expanded_context_fg = "${b03}"

# Syntax highlight diff backgrounds
syntax_add_bg = "${syntax_add_bg}"
syntax_del_bg = "${syntax_del_bg}"

# Syntax theme (TextMate .tmTheme for code highlighting inside diffs)
syntax_theme = "tinted.tmTheme"

# File status
file_added = "${b0B}"
file_modified = "${b0A}"
file_deleted = "${b08}"
file_renamed = "${b0E}"

# Review status
reviewed = "${b0B}"
pending = "${b0A}"

# Comment types
comment_note = "${b0D}"
comment_suggestion = "${b0C}"
comment_issue = "${b08}"
comment_praise = "${b0B}"

# UI elements
border_focused = "${b0C}"
border_unfocused = "${b02}"
status_bar_bg = "${b01}"
cursor_color = "${b09}"
cursor_line_bg = "${b01}"
branch_name = "${b0C}"
help_indicator = "${b03}"

# Message badges
message_info_fg = "${accent_fg}"
message_info_bg = "${b0D}"
message_warning_fg = "${accent_fg}"
message_warning_bg = "${b0A}"
message_error_fg = "${accent_fg}"
message_error_bg = "${b08}"

# Update badge
update_badge_fg = "${accent_fg}"
update_badge_bg = "${b09}"

# Mode indicator
mode_fg = "${mode_accent_fg}"
mode_bg = "${b0D}"
TUICR_EOF

# ── Step 6 — write syntax .tmTheme ───────────────────────────────────────
# Standard base16 mapping for TextMate scopes
cat > "$TUICR_TMTHEME" << TM_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>name</key>
  <string>tinted (${SCHEME_FULL})</string>
  <key>uuid</key>
  <string>$(uuidgen)</string>
  <key>settings</key>
  <array>
    <dict>
      <key>settings</key>
      <dict>
        <key>foreground</key>
        <string>${b05}</string>
        <key>background</key>
        <string>${b00}</string>
        <key>caret</key>
        <string>${b05}</string>
        <key>selection</key>
        <string>${b02}</string>
        <key>lineHighlight</key>
        <string>${b01}</string>
        <key>invisibles</key>
        <string>${b03}</string>
        <key>gutter</key>
        <string>${b03}</string>
        <key>gutterForeground</key>
        <string>${b04}</string>
      </dict>
    </dict>
    <dict>
      <key>name</key>
      <string>Comment</string>
      <key>scope</key>
      <string>comment, punctuation.definition.comment</string>
      <key>settings</key>
      <dict>
        <key>foreground</key>
        <string>${b03}</string>
        <key>fontStyle</key>
        <string>italic</string>
      </dict>
    </dict>
    <dict>
      <key>name</key>
      <string>Keyword</string>
      <key>scope</key>
      <string>keyword, storage, storage.type, storage.modifier</string>
      <key>settings</key>
      <dict>
        <key>foreground</key>
        <string>${b0E}</string>
      </dict>
    </dict>
    <dict>
      <key>name</key>
      <string>String</string>
      <key>scope</key>
      <string>string, string constant.character.escape, punctuation.definition.string</string>
      <key>settings</key>
      <dict>
        <key>foreground</key>
        <string>${b0B}</string>
      </dict>
    </dict>
    <dict>
      <key>name</key>
      <string>Constant</string>
      <key>scope</key>
      <string>constant, constant.numeric, constant.language, constant.character</string>
      <key>settings</key>
      <dict>
        <key>foreground</key>
        <string>${b09}</string>
      </dict>
    </dict>
    <dict>
      <key>name</key>
      <string>Function / Type</string>
      <key>scope</key>
      <string>entity.name.function, support.function, entity.name.type, support.type</string>
      <key>settings</key>
      <dict>
        <key>foreground</key>
        <string>${b0D}</string>
      </dict>
    </dict>
    <dict>
      <key>name</key>
      <string>Variable</string>
      <key>scope</key>
      <string>variable, variable.parameter, variable.other, support.variable</string>
      <key>settings</key>
      <dict>
        <key>foreground</key>
        <string>${b05}</string>
      </dict>
    </dict>
    <dict>
      <key>name</key>
      <string>Support / Regex / Escape</string>
      <key>scope</key>
      <string>support, support.class, support.constant, entity.name.tag, meta.tag, punctuation.definition.tag, punctuation.separator.key-value, keyword.operator, constant.other.symbol</string>
      <key>settings</key>
      <dict>
        <key>foreground</key>
        <string>${b0C}</string>
      </dict>
    </dict>
    <dict>
      <key>name</key>
      <string>Class / Markup Bold</string>
      <key>scope</key>
      <string>entity.name.class, entity.name.module, markup.bold</string>
      <key>settings</key>
      <dict>
        <key>foreground</key>
        <string>${b0A}</string>
        <key>fontStyle</key>
        <string>bold</string>
      </dict>
    </dict>
    <dict>
      <key>name</key>
      <string>Tag / Attribute</string>
      <key>scope</key>
      <string>entity.name.tag, entity.other.attribute-name, markup.heading</string>
      <key>settings</key>
      <dict>
        <key>foreground</key>
        <string>${b08}</string>
      </dict>
    </dict>
    <dict>
      <key>name</key>
      <string>Deprecated</string>
      <key>scope</key>
      <string>invalid.deprecated</string>
      <key>settings</key>
      <dict>
        <key>foreground</key>
        <string>${b0F}</string>
      </dict>
    </dict>
    <dict>
      <key>name</key>
      <string>Invalid</string>
      <key>scope</key>
      <string>invalid, invalid.illegal</string>
      <key>settings</key>
      <dict>
        <key>foreground</key>
        <string>${b00}</string>
        <key>background</key>
        <string>${b08}</string>
      </dict>
    </dict>
    <dict>
      <key>name</key>
      <string>Diff Inserted</string>
      <key>scope</key>
      <string>markup.inserted, markup.inserted.diff</string>
      <key>settings</key>
      <dict>
        <key>foreground</key>
        <string>${b0B}</string>
      </dict>
    </dict>
    <dict>
      <key>name</key>
      <string>Diff Deleted</string>
      <key>scope</key>
      <string>markup.deleted, markup.deleted.diff</string>
      <key>settings</key>
      <dict>
        <key>foreground</key>
        <string>${b08}</string>
      </dict>
    </dict>
    <dict>
      <key>name</key>
      <string>Diff Changed</string>
      <key>scope</key>
      <string>markup.changed, markup.changed.diff</string>
      <key>settings</key>
      <dict>
        <key>foreground</key>
        <string>${b0E}</string>
      </dict>
    </dict>
  </array>
</dict>
</plist>
TM_EOF

echo "[tinty-tuicr] wrote tuicr theme  → $TUICR_TOML" >&2
echo "[tinty-tuicr] wrote syntax theme → $TUICR_TMTHEME" >&2
echo "[tinty-tuicr] scheme: ${SCHEME_FULL}" >&2
