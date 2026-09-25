#!/usr/bin/env bash

set -u

HOME_DIR="${HOME}"
GTK3="${HOME_DIR}/.config/gtk-3.0/gtk.css"
GTK4="${HOME_DIR}/.config/gtk-4.0/gtk.css"
KITTY_COLORS="${HOME_DIR}/.config/kitty/colors.conf"
QS_COLORS="${HOME_DIR}/.local/state/aether/qs_colors.json"
CURSOR_SETTINGS="${HOME_DIR}/.config/Cursor/User/settings.json"
KITTY_SOCKET="unix:/tmp/kitty_live_socket"

file_size() {
    stat -c '%s' "$1" 2>/dev/null || echo 0
}

wait_stable() {
    local file="$1"
    local attempt size_a size_b

    for attempt in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
        if [ -f "$file" ]; then
            size_a="$(file_size "$file")"
            if [ "$size_a" -gt 0 ]; then
                sleep 0.05
                size_b="$(file_size "$file")"
                if [ "$size_a" = "$size_b" ] && [ "$size_b" -gt 0 ]; then
                    return 0
                fi
            fi
        fi
        sleep 0.05
    done
    return 1
}

apply_kitty() {
    command -v kitten >/dev/null 2>&1 || return 0
    [ -S /tmp/kitty_live_socket ] || return 0
    kitten @ --to="$KITTY_SOCKET" set-colors --all "$KITTY_COLORS" >/dev/null 2>&1 || true
}

apply_cursor() {
    command -v python3 >/dev/null 2>&1 || return 0
    command -v jq >/dev/null 2>&1 || return 0
    [ -s "$QS_COLORS" ] || return 0

    mkdir -p "$(dirname "$CURSOR_SETTINGS")"
    if [ ! -s "$CURSOR_SETTINGS" ]; then
        printf '%s\n' '{}' > "$CURSOR_SETTINGS"
    fi

    local cleaned custom
    cleaned="$(mktemp)"
    custom="$(mktemp)"

    python3 - "$QS_COLORS" "$CURSOR_SETTINGS" "$cleaned" "$custom" <<'PY'
import json, re, sys

colors_path, settings_path, cleaned_path, custom_path = sys.argv[1:5]

def strip_jsonc(text):
    out = []
    i = 0
    n = len(text)
    in_str = False
    esc = False
    while i < n:
        c = text[i]
        nxt = text[i + 1] if i + 1 < n else ""
        if in_str:
            out.append(c)
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_str = False
            i += 1
            continue
        if c == '"':
            in_str = True
            out.append(c)
            i += 1
            continue
        if c == "/" and nxt == "/":
            i += 2
            while i < n and text[i] not in "\r\n":
                i += 1
            continue
        if c == "/" and nxt == "*":
            i += 2
            while i + 1 < n and not (text[i] == "*" and text[i + 1] == "/"):
                i += 1
            i = min(n, i + 2)
            continue
        out.append(c)
        i += 1
    cleaned = "".join(out).strip()
    cleaned = re.sub(r",(\s*[}\]])", r"\1", cleaned)
    return cleaned or "{}"

with open(colors_path, "r", encoding="utf-8") as handle:
    palette = json.load(handle)

def pick(*keys):
    for key in keys:
        value = palette.get(key)
        if isinstance(value, str) and value:
            return value
    return "#000000"

custom = {
    "editor.background": pick("base", "crust"),
    "editor.foreground": pick("text"),
    "editorCursor.foreground": pick("blue", "mauve"),
    "editor.selectionBackground": pick("surface2", "surface1"),
    "editor.lineHighlightBackground": pick("surface0"),
    "sideBar.background": pick("mantle", "crust"),
    "sideBar.foreground": pick("text"),
    "activityBar.background": pick("crust", "mantle"),
    "activityBar.foreground": pick("text"),
    "statusBar.background": pick("blue", "mauve"),
    "statusBar.foreground": pick("crust", "base"),
    "titleBar.activeBackground": pick("mantle", "crust"),
    "titleBar.activeForeground": pick("text"),
    "tab.activeBackground": pick("surface0"),
    "tab.activeForeground": pick("text"),
    "tab.inactiveBackground": pick("crust", "mantle"),
    "tab.inactiveForeground": pick("subtext0", "subtext1"),
    "focusBorder": pick("blue", "mauve"),
    "button.background": pick("blue", "mauve"),
    "button.foreground": pick("crust", "base"),
}

with open(settings_path, "r", encoding="utf-8") as handle:
    raw = handle.read()
if not raw.strip():
    raw = "{}"
with open(cleaned_path, "w", encoding="utf-8") as handle:
    handle.write(strip_jsonc(raw))
    handle.write("\n")
with open(custom_path, "w", encoding="utf-8") as handle:
    json.dump(custom, handle)
    handle.write("\n")
PY

    jq --argjson colors "$(cat "$custom")" '.["workbench.colorCustomizations"] = $colors' "$cleaned" > "${CURSOR_SETTINGS}.tmp" \
        && mv "${CURSOR_SETTINGS}.tmp" "$CURSOR_SETTINGS"
    rm -f "$cleaned" "$custom"
}

if ! wait_stable "$GTK3"; then
    exit 0
fi
if ! wait_stable "$GTK4"; then
    exit 0
fi
if ! wait_stable "$KITTY_COLORS"; then
    exit 0
fi
if ! wait_stable "$QS_COLORS"; then
    exit 0
fi

apply_kitty
apply_cursor
