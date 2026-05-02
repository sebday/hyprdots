#!/bin/sh
# Wait until systemd-networkd reports connectivity (matches enabled wait-online unit).
# If there is no network (e.g. offline), exit after --timeout so Hyprland still starts.
/usr/lib/systemd/systemd-networkd-wait-online --timeout=120 || true
exec /usr/bin/start-hyprland
