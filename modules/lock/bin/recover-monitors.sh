#!/bin/bash
# Heal Hyprland outputs stuck at 0x0 after overnight lock / KMS modeset failures.

set -euo pipefail

uid="${UID:-$(id -u)}"
: "${XDG_RUNTIME_DIR:=/run/user/${uid}}"
export XDG_RUNTIME_DIR

valid_name() {
  case "$1" in
    ''|.*|*/*|*..*) return 1 ;;
  esac
  [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]]
}

if [[ -z ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
  his_dir=$(find "$XDG_RUNTIME_DIR/hypr" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1 || true)
  [[ -n $his_dir ]] || exit 0
  export HYPRLAND_INSTANCE_SIGNATURE=$(basename "$his_dir")
fi

[[ -x /usr/bin/hyprctl ]] || exit 0
[[ -x /usr/bin/jq ]] || exit 0

list_broken() {
  local json
  json=$(/usr/bin/timeout -k 2 5 /usr/bin/hyprctl -j monitors all 2>/dev/null | /usr/bin/head -c 262145) || return 0
  [ ${#json} -le 262144 ] || return 0
  /usr/bin/jq -r '.[] | select((.width // 0) == 0 or (.height // 0) == 0) | .name' <<<"$json" || true
}

# Emit hyprctl eval expressions from monitors.lua. Tokens only.
layout_evals() {
  local lua="${HOME}/.config/hypr/monitors.lua"
  [[ -f $lua ]] || return 0
  /usr/bin/python3 -I - "$lua" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
try:
    text = path.read_text(encoding="utf-8")
except OSError:
    sys.exit(0)
if len(text) > 65536:
    sys.exit(0)

pat = re.compile(
    r"hl\.monitor\(\{\s*"
    r'output\s*=\s*"([A-Za-z0-9._-]+)"\s*,\s*'
    r'mode\s*=\s*"([0-9]+x[0-9]+(?:@[0-9.]+)?)"\s*,\s*'
    r'position\s*=\s*"(-?[0-9]+x-?[0-9]+)"\s*,\s*'
    r"scale\s*=\s*([0-9]+(?:\.[0-9]+)?)\s*"
    r"\}\)"
)
name_re = re.compile(r"^[A-Za-z0-9._-]+$")
for match in pat.finditer(text):
    name, mode, pos, scale = match.groups()
    if not name_re.fullmatch(name):
        continue
    print(
        f'hl.monitor({{ output = "{name}", mode = "{mode}", '
        f'position = "{pos}", scale = {scale} }})'
    )
PY
}

apply_user_layout() {
  local expr
  while IFS= read -r expr; do
    [[ -n $expr ]] || continue
    /usr/bin/hyprctl eval "$expr" >/dev/null 2>&1 || true
  done < <(layout_evals || true)
}

disable_outputs() {
  local name
  for name in "$@"; do
    valid_name "$name" || continue
    /usr/bin/hyprctl eval "hl.monitor({ output = \"$name\", disabled = true })" >/dev/null 2>&1 || true
  done
}

mapfile -t broken < <(list_broken)
((${#broken[@]} > 0)) || exit 0

echo "evo.lock recover-monitors: healing ${broken[*]}" >&2

# DPMS enable first. A 0x0 after panel sleep is sometimes just a stalled
# enable, and disable/enable is the amdgpu modeset that wedges this card.
/usr/bin/hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })' >/dev/null 2>&1 || true
sleep 1
mapfile -t broken < <(list_broken)
((${#broken[@]} > 0)) || exit 0

echo "evo.lock recover-monitors: still 0x0 after dpms (${broken[*]}); cycling" >&2

disable_outputs "${broken[@]}"
sleep 1

# Restore the user's layout instead of preferred/auto (that scrambled positions).
/usr/bin/hyprctl reload >/dev/null 2>&1 || true
sleep 1

mapfile -t still < <(list_broken)
if ((${#still[@]} > 0)); then
  echo "evo.lock recover-monitors: still broken (${still[*]}); applying monitors.lua" >&2
  apply_user_layout
  sleep 1
  mapfile -t still < <(list_broken)
fi

if ((${#still[@]} > 0)); then
  echo "evo.lock recover-monitors: still broken (${still[*]}); disable then layout" >&2
  disable_outputs "${still[@]}"
  sleep 1
  apply_user_layout
  sleep 1
  mapfile -t still < <(list_broken)
fi

if ((${#still[@]} > 0)); then
  echo "evo.lock recover-monitors: still 0x0 after layout (${still[*]})" >&2
fi

# Seat can sit on another TTY after a wedged lock. Activate only — never
# unlock-session; this script also runs while the lock is held.
session=$(/usr/bin/loginctl show-user "${USER:-seb}" -p Display --value 2>/dev/null || true)
if [[ $session =~ ^[0-9]+$ ]]; then
  /usr/bin/loginctl activate "$session" >/dev/null 2>&1 || true
fi
