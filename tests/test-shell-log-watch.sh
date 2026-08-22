#!/usr/bin/env bash
set -euo pipefail

root="${EVOSHELL_ROOT:-$HOME/projects/evoshell}"
bin="${EVOSHELL_BIN:-${root}/bin}"
watch="${bin}/evo-shell-log-watch"
fail=0

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" != "$actual" ]]; then
    echo "FAIL: $label" >&2
    echo "  expected: $expected" >&2
    echo "  actual:   $actual" >&2
    fail=1
  fi
}

binding_msg='  WARN scene: QML MonitorLayoutPicker at qs:/home/seb/projects/evoshell/evosys/settings/SettingsModule.qml[1340:49]: Binding loop detected for property "implicitWidth":'
stack_msg='  WARN scene: qs:/home/seb/projects/evoshell/evosys/menu/Menu.qml[1541888288:-1]: RangeError: Maximum call stack size exceeded.'

json="$("$watch" format "$binding_msg")"
title="$(jq -r '.title' <<< "$json")"
level="$(jq -r '.level' <<< "$json")"
source="$(jq -r '.source' <<< "$json")"
fp1="$(jq -r '.fingerprint' <<< "$json")"
assert_eq "binding loop title" "Binding loop: implicitWidth" "$title"
assert_eq "binding loop level" "warning" "$level"
assert_eq "binding loop source" "shell" "$source"

json2="$("$watch" format "$binding_msg")"
fp2="$(jq -r '.fingerprint' <<< "$json2")"
assert_eq "duplicate fingerprint" "$fp1" "$fp2"

json3="$("$watch" format "$stack_msg")"
assert_eq "stack level" "error" "$(jq -r '.level' <<< "$json3")"

different_msg='  WARN scene: QML TestItem at qs:/tmp/Other.qml[1:2]: Binding loop detected for property "model":'
fp3="$(jq -r '.fingerprint' <<< "$("$watch" format "$different_msg")")"
if [[ "$fp1" == "$fp3" ]]; then
  echo "FAIL: different messages should not share fingerprint" >&2
  fail=1
fi

exec_json="$(jq -nc \
  --arg msg 'evoshell.service: Failed at step EXEC spawning /home/seb/.local/bin/evoshell/evo-system: No such file or directory' \
  '{PRIORITY:"3",SYSLOG_IDENTIFIER:"systemd",_SYSTEMD_USER_UNIT:"evoshell.service",MESSAGE:$msg}')"
journal_json="$("$watch" format-journal "$exec_json")"
assert_eq "journal source" "journal" "$(jq -r '.source' <<< "$journal_json")"
assert_eq "journal level" "error" "$(jq -r '.level' <<< "$journal_json")"
assert_eq "journal title" "evoshell.service" "$(jq -r '.title' <<< "$journal_json")"

exit_json="$(jq -nc \
  --arg msg "evoshell.service: Failed with result 'exit-code'." \
  '{PRIORITY:"4",SYSLOG_IDENTIFIER:"systemd",_SYSTEMD_USER_UNIT:"evoshell.service",MESSAGE:$msg}')"
exit_journal="$("$watch" format-journal "$exit_json" || true)"
if [[ -n "$exit_journal" ]]; then
  echo "FAIL: restart exit-code noise should be filtered" >&2
  fail=1
fi

fp4="$(jq -r '.fingerprint' <<< "$journal_json")"
fp5="$(jq -r '.fingerprint' <<< "$("$watch" format-journal "$exec_json")")"
assert_eq "journal fingerprint stable" "$fp4" "$fp5"

icon_msg='WARN: Could not load icon "/tmp/hyprshot.png?rev=123" at size QSize(102, 102) from request'
icon_json="$("$watch" format "$icon_msg")"
assert_eq "icon load title" "icon load failed" "$(jq -r '.title' <<< "$icon_json")"
assert_eq "icon load body" "hyprshot.png" "$(jq -r '.body' <<< "$icon_json")"

exit "$fail"
