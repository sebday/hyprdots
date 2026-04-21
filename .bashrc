#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

source ~/.config/bash/rc

export PATH=/home/seb/.opencode/bin:$PATH

# Added by LM Studio CLI (lms)
export PATH="$PATH:/home/seb/.lmstudio/bin"
# End of LM Studio CLI section

