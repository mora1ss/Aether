#!/usr/bin/env bash
set -euo pipefail

THEME_DIR="/usr/share/sddm/themes/material-you"
STAMP_PATH="$THEME_DIR/.aether-sync-stamp"
APPLY_BIN="/usr/lib/aether/sddm-apply"

STATE_DIR="${QS_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/aether}"
CACHE_DIR="${QS_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/aether}"
COLORS_SRC="$STATE_DIR/qs_colors.json"

file_hash() {
    local path="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$path" | awk '{print $1}'
    elif command -v openssl >/dev/null 2>&1; then
        openssl dgst -sha256 "$path" | awk '{print $NF}'
    else
        cksum "$path" | awk '{print $1"-"$2}'
    fi
}

is_regular_file() {
    [ -f "$1" ] && [ ! -L "$1" ]
}

resolve_wallpaper() {
    local candidate
    local cache_wp="$CACHE_DIR/wallpaper"
    local old_nullglob
    old_nullglob="$(shopt -p nullglob)"
    shopt -s nullglob

    for candidate in \
        "$cache_wp/current_wallpaper.png" \
        "$cache_wp"/current_wallpaper_*.png
    do
        if is_regular_file "$candidate" && [ "$(stat -c '%s' "$candidate" 2>/dev/null || echo 0)" -gt 64 ]; then
            eval "$old_nullglob"
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    if [ -d "$cache_wp" ]; then
        local path_file
        for path_file in "$cache_wp"/current_*; do
            [ -f "$path_file" ] || continue
            case "$path_file" in
                *.png|*.jpg|*.jpeg|*.webp) continue ;;
            esac
            candidate="$(tr -d '\n' < "$path_file" 2>/dev/null || true)"
            if is_regular_file "$candidate" && [ "$(stat -c '%s' "$candidate" 2>/dev/null || echo 0)" -gt 64 ]; then
                eval "$old_nullglob"
                printf '%s\n' "$candidate"
                return 0
            fi
        done
    fi

    eval "$old_nullglob"
    return 1
}

if ! is_regular_file "$COLORS_SRC"; then
    exit 0
fi

wallpaper_src=""
if wallpaper_src="$(resolve_wallpaper)"; then
    :
else
    wallpaper_src=""
fi

colors_hash="$(file_hash "$COLORS_SRC")"
if [ -n "$wallpaper_src" ]; then
    wallpaper_meta="$(stat -c '%s %Y' "$wallpaper_src") $wallpaper_src"
else
    wallpaper_meta="0 0 -"
fi

expected="$colors_hash $wallpaper_meta"

if [ -r "$STAMP_PATH" ] && [ "$(tr -d '\n' < "$STAMP_PATH" 2>/dev/null || true)" = "$expected" ]; then
    exit 0
fi

if [ ! -x "$APPLY_BIN" ]; then
    exit 0
fi

run_apply() {
    if [ "$(id -u)" -eq 0 ]; then
        "$APPLY_BIN" "$@"
        return
    fi
    if [ -n "${AETHER_SDDM_APPLY_CMD:-}" ]; then
        # Intentional word splitting so installer can pass "sudo".
        # shellcheck disable=SC2086
        $AETHER_SDDM_APPLY_CMD "$APPLY_BIN" "$@"
        return
    fi
    if command -v pkexec >/dev/null 2>&1; then
        pkexec --disable-internal-agent "$APPLY_BIN" "$@"
        return
    fi
    return 1
}

args=(--colors "$COLORS_SRC" --stamp "$expected")
if [ -n "$wallpaper_src" ]; then
    args+=(--wallpaper "$wallpaper_src")
fi

run_apply "${args[@]}" >/dev/null 2>&1 || true
