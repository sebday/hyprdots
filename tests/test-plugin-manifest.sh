#!/usr/bin/env bash
set -euo pipefail

root="${EVOSHELL_ROOT:-$HOME/projects/evoshell}"
manifest="${root}/pluginManifest.js"
skip_evoplayer="${EVO_SKIP_EVOPLAYER:-0}"
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
  evo.panels.player
  evo.panels.player.monitor
  evo.sys.media.audio
  evo.panels.media.now-playing
  evo.panels.media.library
  evo.panels.notifications
)

for id in "${required[@]}"; do
  rg -q "\"${id}\"" "$manifest" || { echo "missing plugin id: $id" >&2; fail=1; }
done

if rg -q 'evo\.panels\.shopify' "$manifest"; then
  echo "shopify must not ship in public pluginManifest.js" >&2
  fail=1
fi

id_regex='^evo\.(bar|panels|side|sys)(\.[a-z0-9]+(-[a-z0-9]+)*)*$'
while IFS= read -r id; do
  [[ "$id" =~ $id_regex ]] || { echo "invalid plugin id: $id" >&2; fail=1; }
done < <(rg -o '"evo\.[^"]+"' "$manifest" | tr -d '"')

while IFS= read -r path; do
  [[ -f "${root}/${path}" ]] || { echo "missing manifest path: $path" >&2; fail=1; }
done < <(rg -o 'path: "[^"]+"' "$manifest" | sed 's/path: "//;s/"$//')

while IFS= read -r path; do
  [[ -f "${root}/${path}" ]] || { echo "missing manifest servicePath: $path" >&2; fail=1; }
done < <(rg -o 'servicePath: "[^"]+"' "$manifest" | sed 's/servicePath: "//;s/"$//')

[[ -f "${root}/config/plugins/manifest.example.json" ]] || { echo "missing plugin overlay example" >&2; fail=1; }

if [[ "$skip_evoplayer" != "1" ]]; then
  [[ -f "${root}/evoplayer/Player.qml" ]] || { echo "missing Evoplayer Player.qml" >&2; fail=1; }
fi

exit "$fail"
