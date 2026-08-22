#!/usr/bin/env bash
set -euo pipefail

root="${EVOSHELL_ROOT:-$HOME/projects/evoshell}"
bin="${EVOSHELL_BIN:-${root}/bin}"
tmp="$(mktemp -d)"
export EVOSHELL_ROOT="$root"
export EVOSHELL_BIN="$bin"
export EVOSHELL_CONFIG="${tmp}/config"
export XDG_CONFIG_HOME="${tmp}"
export HOME="${tmp}"

mkdir -p "$EVOSHELL_CONFIG"

config="${bin}/evo-config"
fail=0

assert_json() {
    jq -e "$1" >/dev/null 2>&1 || {
        echo "assert failed: $1" >&2
        fail=1
    }
}

"$config" panel set right >/dev/null
side="$("$config" panel get)"
assert_json '.side == "right"' <<<"$side"

"$config" dashboards set evo.panels.player on >/dev/null
dash="$("$config" dashboards get)"
assert_json '(.openOnStart | index("evo.panels.player")) != null' <<<"$dash"

"$config" shopify set-paths "/tmp/sqlite" "user@host:/data" "Europe/London" >/dev/null
shopify="$("$config" shopify get)"
assert_json '.sqliteDir == "/tmp/sqlite" and .remote == "user@host:/data" and .timezone == "Europe/London"' <<<"$shopify"

"$config" homeassistant set-fields "Living Room" "climate.living_room" >/dev/null
ha="$("$config" homeassistant get)"
assert_json '(.lightAreas | index("Living Room")) != null and (.climateEntities | index("climate.living_room")) != null' <<<"$ha"

areas="$("$config" homeassistant areas)"
assert_json '.ok == false and (.enabledLightAreas | type) == "array" and (.enabledClimateEntities | type) == "array"' <<<"$areas"

"$config" idle set-fields 10 >/dev/null
idle="$("$config" idle get)"
assert_json '.lock == 600' <<<"$idle"

"$config" wallpaper set-personal-dir "/tmp/personal-wallpapers" >/dev/null
wallpaper="$("$config" wallpaper get)"
assert_json '.personalDir == "/tmp/personal-wallpapers"' <<<"$wallpaper"

"$config" wallpaper set-personal-dir "" >/dev/null
wallpaper="$("$config" wallpaper get)"
assert_json '.personalDir == ""' <<<"$wallpaper"

mkdir -p "$EVOSHELL_CONFIG/plugins"
cat >"${EVOSHELL_CONFIG}/plugins/manifest.json" <<'EOF'
{
  "trayWidgets": {
    "exampleExt": {
      "label": "Example extension"
    }
  }
}
EOF

"$config" tray set exampleExt enabled on >/dev/null
ext_tray="$("$config" tray set stocks enabled off)"
assert_json '.widgets.github.enabled == true and .widgets.exampleExt.enabled == true and .widgets.stocks.enabled == false' <<<"$ext_tray"
tray="$("$config" tray get)"
assert_json '.widgets.exampleExt.enabled == true and .widgets.stocks.enabled == false and (.order | type) == "array"' <<<"$tray"

"$config" tray order set '["weather","volume","github","cursor","notifications","stocks","cloudflare","homeAssistant","exampleExt","network","media"]' >/dev/null
ordered="$("$config" tray get)"
assert_json '.order[0] == "weather" and .order[1] == "volume"' <<<"$ordered"
assert_json '(.bar.trayWidgetOrder | type) == "array"' <<<"$(jq -c . "${EVOSHELL_CONFIG}/overrides.json")"

[[ -f "${EVOSHELL_CONFIG}/overrides.json" ]] || {
    echo "missing overrides.json" >&2
    fail=1
}

if ! jq -e '.panel.side == "right"' "${EVOSHELL_CONFIG}/overrides.json" >/dev/null 2>&1; then
    echo "overrides.json missing panel.side patch" >&2
    fail=1
fi

rm -rf "$tmp"
[[ "$fail" -eq 0 ]] || exit 1
echo "evo-config ok"
