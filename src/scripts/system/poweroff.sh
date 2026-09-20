#!/usr/bin/env bash

_aether_sddm_sync() {
    local sync_script
    sync_script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../sddm/sync.sh"
    if [ ! -f "$sync_script" ]; then
        return 0
    fi
    if command -v timeout >/dev/null 2>&1; then
        timeout 2s bash "$sync_script" >/dev/null 2>&1 || true
    else
        bash "$sync_script" >/dev/null 2>&1 || true
    fi
}
_aether_sddm_sync

rm -f /tmp/aetherd.lock /tmp/aetherd.pid 2>/dev/null

if command -v systemctl &>/dev/null && [ -d /run/systemd/system ]; then
    systemctl poweroff -i && exit 0
fi

if command -v loginctl &>/dev/null; then
    loginctl poweroff && exit 0
fi

if command -v dbus-send &>/dev/null; then
    dbus-send --system --print-reply --dest=org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager.PowerOff boolean:true 2>/dev/null && exit 0
fi

if command -v openrc-shutdown &>/dev/null; then
    openrc-shutdown -p now && exit 0
fi

if command -v dinitctl &>/dev/null; then
    dinitctl shutdown && exit 0
fi

if command -v poweroff &>/dev/null; then
    poweroff
fi
