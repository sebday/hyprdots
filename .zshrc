export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="agnoster"
#ZSH_THEME="xiong-chiamiov-plus"
#ZSH_THEME="aussiegeek"

plugins=( 
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh
export PATH="$HOME/.local/bin:$PATH"

# Set-up icons for files/folders in terminal using eza
alias ls='eza -l --icons'
alias ll='eza -al --icons'
alias lt='eza -alr --sort=mod --tree --level=1 --icons'
alias ff='fastfetch'

# Execute fastfetch on shell startup
fastfetch

# NVM as we love js 
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Added by LM Studio CLI (lms)
export PATH="$PATH:/home/seb/.cache/lm-studio/bin"
