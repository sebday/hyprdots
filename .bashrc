#
# ~/.bashrc
#

[[ $- == *i* ]] && source /usr/share/blesh/ble.sh --noattach

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

source ~/.config/bash/rc
eval "$(mise activate bash)"

export PATH=/home/seb/.opencode/bin:$PATH

[[ ${BLE_VERSION-} ]] && ble-attach
