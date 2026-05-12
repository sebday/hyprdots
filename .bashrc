# If not running interactively, don't do anything
[[ $- != *i* ]] && return

source ~/.config/bash/shell
source ~/.config/bash/aliases
source ~/.config/bash/functions
source ~/.config/bash/prompt
source ~/.config/bash/init
source ~/.config/bash/envs
[[ $- == *i* ]] && bind -f ~/.config/bash/inputrc
