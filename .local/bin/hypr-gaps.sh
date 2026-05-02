#!/usr/bin/env bash
# Toggle gaps on/off for the current workspace only

id=$(hyprctl -j activeworkspace | jq -r '.id')
rid="r[$id-$id]"

# Match gaps_in from looks.conf
gaps_in_default=10

gaps_in_current=$(hyprctl workspacerules -j | jq -r --arg rid "$rid" '[.[] | select(.workspaceString | startswith($rid)) | .gapsIn[0]] | .[0]')

# Toggle: if no rule or default gaps, set gapsin to 0; else restore default
if [[ ("$gaps_in_current" == "null" || "$gaps_in_current" == "$gaps_in_default") ]]; then
  hyprctl keyword workspace "$rid, gapsin:0"
else
  hyprctl keyword workspace "$rid, gapsin:$gaps_in_default"
fi
