#!/usr/bin/env bash
set -euo pipefail

root="${EVOSHELL_ROOT:-$HOME/projects/evoshell}"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

export HOME="${tmpdir}/home"
export EVOSHELL_BIN="${root}/bin"
export EVOSHELL_ROOT="${root}"
export EVOSHELL_CONFIG="${HOME}/.config/evoshell"
export EVOSHELL_STATE="${HOME}/.local/state/evoshell"

args_file="${tmpdir}/notify-args"
stub="${tmpdir}/notify-send"

cat >"$stub" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" >"$args_file"
EOF
chmod +x "$stub"

send="${root}/bin/evo-notification-send"
[[ -x "$send" ]] || { echo "missing evo-notification-send" >&2; exit 1; }

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

PATH="${tmpdir}:${PATH}" \
  "$send" --app-name custom-app -g "K" -u critical --image /tmp/image.png \
  --exec "evo-screenshot edit" "Learn Keybindings" "Body"

grep -q -- '-a' "$args_file" || fail "missing -a"
grep -q 'custom-app' "$args_file" || fail "missing app name"
grep -q 'evoshell-glyph:K' "$args_file" || fail "missing glyph hint"
grep -q 'evoshell-exec:evo-screenshot edit' "$args_file" || fail "missing exec hint"
grep -q 'image-path:/tmp/image.png' "$args_file" || fail "missing image hint"
grep -q -- '-A' "$args_file" && fail "must not register libnotify actions"
grep -q 'Learn Keybindings' "$args_file" || fail "missing headline"
grep -q 'Body' "$args_file" || fail "missing body"

: >"$args_file"
PATH="${tmpdir}:${PATH}" "$send" --silent "ignored" >/dev/null
[[ ! -s "$args_file" ]] || fail "--silent should not call notify-send"

if PATH="${tmpdir}:${PATH}" "$send" "Headline" --exec 2>/dev/null; then
  fail "--exec without command should fail"
fi

PATH="${tmpdir}:${PATH}" "$send" -g "󰂚" "Plain" >/dev/null
grep -q 'evoshell-glyph:' "$args_file" || fail "glyph hint missing on plain send"
grep -q 'evoshell-exec' "$args_file" && fail "exec hint must be omitted without --exec"

: >"$args_file"
PATH="${tmpdir}:${PATH}" "$send" --probe >/dev/null
grep -q -- '-e' "$args_file" || fail "--probe must pass -e to notify-send"
grep -q 'evoshell' "$args_file" || fail "--probe must use evoshell app name"
grep -q '^ok$' "$args_file" || fail "--probe must send ok headline"

echo "ok"
