#!/usr/bin/env bash
set -euo pipefail

THEME_DIR="/usr/share/sddm/themes/material-you"
COLORS_DEST="$THEME_DIR/colors.json"
CONF_DEST="$THEME_DIR/theme.conf"
BG_DEST="$THEME_DIR/bg.png"
STAMP_DEST="$THEME_DIR/.aether-sync-stamp"

MAX_COLORS_BYTES=8192
MAX_WALLPAPER_BYTES=20971520

usage() {
    echo "usage: sddm-apply --colors FILE [--wallpaper FILE] [--stamp TEXT]" >&2
    exit 2
}

if [ "$(id -u)" -ne 0 ]; then
    echo "sddm-apply must run as root" >&2
    exit 1
fi

colors_src=""
wallpaper_src=""
stamp_text=""

while [ $# -gt 0 ]; do
    case "$1" in
        --colors)
            [ $# -ge 2 ] || usage
            colors_src="$2"
            shift 2
            ;;
        --wallpaper)
            [ $# -ge 2 ] || usage
            wallpaper_src="$2"
            shift 2
            ;;
        --stamp)
            [ $# -ge 2 ] || usage
            stamp_text="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            usage
            ;;
    esac
done

[ -n "$colors_src" ] || usage

if [ ! -f "$colors_src" ] || [ -L "$colors_src" ]; then
    echo "colors source must be a regular file" >&2
    exit 1
fi

colors_size="$(stat -c '%s' "$colors_src" 2>/dev/null || echo 0)"
if [ "$colors_size" -le 0 ] || [ "$colors_size" -gt "$MAX_COLORS_BYTES" ]; then
    echo "colors file size out of range" >&2
    exit 1
fi

if [ ! -d "$THEME_DIR" ]; then
    echo "SDDM theme directory missing: $THEME_DIR" >&2
    exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 is required to apply SDDM colors" >&2
    exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

if ! python3 - "$colors_src" "$tmp_dir/colors.json" "$CONF_DEST" "$tmp_dir/theme.conf" <<'PY'
import json
import os
import re
import sys

src, colors_out, conf_src, conf_out = sys.argv[1:5]
key_re = re.compile(r"^[A-Za-z][A-Za-z0-9_]*$")
hex_re = re.compile(r"^#?[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$")

with open(src, "r", encoding="utf-8") as handle:
    raw = json.load(handle)

if not isinstance(raw, dict):
    raise SystemExit("colors JSON must be an object")

clean = {}
for key, value in raw.items():
    if not isinstance(key, str) or not key_re.match(key):
        continue
    if not isinstance(value, str):
        continue
    token = value.strip()
    if not hex_re.match(token):
        continue
    if not token.startswith("#"):
        token = "#" + token
    clean[key] = token.lower() if len(token) != 9 else token

if not clean:
    raise SystemExit("no valid hex colors found")

existing = {}
font = "Google-Sans"
conf_type = "color"
if os.path.isfile(conf_src):
    with open(conf_src, "r", encoding="utf-8") as handle:
        for line in handle:
            stripped = line.strip()
            if not stripped or stripped.startswith("#") or stripped.startswith("["):
                continue
            if "=" not in stripped:
                continue
            key, value = stripped.split("=", 1)
            key = key.strip()
            value = value.strip()
            existing[key] = value

if "font" in existing and existing["font"]:
    font = existing["font"]
if "type" in existing and existing["type"]:
    conf_type = existing["type"]

with open(colors_out, "w", encoding="utf-8") as handle:
    json.dump(clean, handle, indent=2, sort_keys=True)
    handle.write("\n")

preferred = [
    "type",
    "color",
    "font",
    "base",
    "mantle",
    "crust",
    "text",
    "subtext0",
    "subtext1",
    "surface0",
    "surface1",
    "surface2",
    "overlay0",
    "mauve",
    "sapphire",
    "red",
    "green",
]
lines = ["[General]", f"type={conf_type}", f"color={clean.get('base', existing.get('color', '#eef6f0'))}", f"font={font}"]
written = {"type", "color", "font"}
for key in preferred:
    if key in clean and key not in written:
        lines.append(f"{key}={clean[key]}")
        written.add(key)
for key in sorted(clean):
    if key not in written:
        lines.append(f"{key}={clean[key]}")
        written.add(key)

with open(conf_out, "w", encoding="utf-8") as handle:
    handle.write("\n".join(lines) + "\n")
PY
then
    echo "failed to sanitize colors" >&2
    exit 1
fi

install -m 644 "$tmp_dir/colors.json" "$COLORS_DEST"
install -m 644 "$tmp_dir/theme.conf" "$CONF_DEST"

wallpaper_meta="0 0 -"

if [ -n "$wallpaper_src" ]; then
    if [ -f "$wallpaper_src" ] && [ ! -L "$wallpaper_src" ]; then
        wallpaper_size="$(stat -c '%s' "$wallpaper_src" 2>/dev/null || echo 0)"
        if [ "$wallpaper_size" -gt 0 ] && [ "$wallpaper_size" -le "$MAX_WALLPAPER_BYTES" ]; then
            if python3 - "$wallpaper_src" <<'PY'
import sys

path = sys.argv[1]
with open(path, "rb") as handle:
    header = handle.read(16)

ok = (
    header.startswith(b"\x89PNG\r\n\x1a\n")
    or header.startswith(b"\xff\xd8\xff")
    or header.startswith(b"GIF87a")
    or header.startswith(b"GIF89a")
    or (header.startswith(b"RIFF") and header[8:12] == b"WEBP")
    or header.startswith(b"BM")
)
raise SystemExit(0 if ok else 1)
PY
            then
                if [ -f "$BG_DEST" ] && cmp -s "$wallpaper_src" "$BG_DEST"; then
                    :
                else
                    install -m 644 "$wallpaper_src" "$BG_DEST"
                fi
                wallpaper_meta="$(stat -c '%s %Y' "$wallpaper_src") $wallpaper_src"
            fi
        fi
    fi
fi

if [ -z "$stamp_text" ]; then
    colors_hash="$(sha256sum "$colors_src" | awk '{print $1}')"
    stamp_text="$colors_hash $wallpaper_meta"
fi
printf '%s\n' "$stamp_text" > "$tmp_dir/stamp"
install -m 644 "$tmp_dir/stamp" "$STAMP_DEST"
chmod 755 "$THEME_DIR"
chmod 644 "$COLORS_DEST" "$CONF_DEST" "$STAMP_DEST" 2>/dev/null || true
if [ -f "$BG_DEST" ]; then
    chmod 644 "$BG_DEST"
fi
