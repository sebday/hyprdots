#!/usr/bin/env bash
set -euo pipefail

root="${EVOSHELL_ROOT:-$HOME/projects/evoshell}"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

export HOME="${tmpdir}/home"
vault1="${tmpdir}/vault1"
vault2="${tmpdir}/vault2"
mkdir -p "$vault1" "$vault2" \
    "${HOME}/.config/obsidian" \
    "${HOME}/.themes/shared/css" \
    "${HOME}/.themes/current"

cat >"${HOME}/.config/obsidian/obsidian.json" <<EOF
{"vaults":{"a":{"path":"${vault1}"},"b":{"path":"${vault2}"}}}
EOF

printf '/* generated */\n' >"${HOME}/.themes/current/obsidian.css"
printf '/* shared */\n' >"${HOME}/.themes/shared/css/obsidian.css"
printf '{"name":"Modular"}\n' >"${HOME}/.themes/shared/obsidian.conf"

# shellcheck source=/dev/null
source "${root}/bin/evo-theme-lib"
themes_sync_obsidian_modular

for vault in "$vault1" "$vault2"; do
    theme_css="${vault}/.obsidian/themes/Modular/theme.css"
    appearance="${vault}/.obsidian/appearance.json"
    [[ -f "$theme_css" ]] || { echo "missing theme.css in $vault" >&2; exit 1; }
    grep -q 'shared' "$theme_css" || { echo "shared css missing in $theme_css" >&2; exit 1; }
    grep -q 'generated' "$theme_css" || { echo "generated css missing in $theme_css" >&2; exit 1; }
    jq -e '.cssTheme == "Modular"' "$appearance" >/dev/null || {
        echo "appearance.json wrong in $vault: $(cat "$appearance")" >&2
        exit 1
    }
done

echo "ok"
