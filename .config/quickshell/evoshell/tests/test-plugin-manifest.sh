#!/usr/bin/env bash
set -euo pipefail

root="${HOME}/.config/quickshell/evoshell"
manifest="${root}/pluginManifest.js"
fail=0

if [[ ! -f "$manifest" ]]; then
  echo "missing plugin manifest" >&2
  exit 1
fi

required=(
  evo.bar
  evo.sys.menu
  evo.sys.settings
  evo.side
  evo.panel.shopify
  evo.panel.player
  evo.panel.player.monitor
  evo.bar.media.now-playing
  evo.bar.media.library
  evo.bar.popups.notifications
)

for id in "${required[@]}"; do
  rg -q "\"${id}\"" "$manifest" || { echo "missing plugin id: $id" >&2; fail=1; }
done

id_regex='^evo\.(bar|panel|side|sys)(\.[a-z0-9]+(-[a-z0-9]+)*)*$'
while IFS= read -r id; do
  [[ "$id" =~ $id_regex ]] || { echo "invalid plugin id: $id" >&2; fail=1; }
done < <(rg -o '"evo\.[^"]+"' "$manifest" | tr -d '"')

while IFS= read -r path; do
  [[ -f "${root}/${path}" ]] || { echo "missing manifest path: $path" >&2; fail=1; }
done < <(rg -o 'path: "[^"]+"' "$manifest" | sed 's/path: "//;s/"$//')

while IFS= read -r path; do
  [[ -f "${root}/${path}" ]] || { echo "missing manifest servicePath: $path" >&2; fail=1; }
done < <(rg -o 'servicePath: "[^"]+"' "$manifest" | sed 's/servicePath: "//;s/"$//')

[[ -f "${root}/Evopanel/Shopify/Shopify.qml" ]] || { echo "missing Shopify.qml" >&2; fail=1; }
[[ -f "${root}/Evopanel/Shopify/demo.json" ]] || { echo "missing Shopify demo.json" >&2; fail=1; }
[[ -f "${root}/Evopanel/Evoplayer/Player.qml" ]] || { echo "missing Player.qml" >&2; fail=1; }

exit "$fail"
