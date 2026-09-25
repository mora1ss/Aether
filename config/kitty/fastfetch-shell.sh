#!/bin/sh
if [ -t 1 ] && command -v fastfetch >/dev/null 2>&1; then
    fastfetch
fi
shell=${SHELL:-/bin/zsh}
exec "$shell" -i
