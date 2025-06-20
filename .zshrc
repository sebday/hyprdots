# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

source ~/.zsh/powerlevel10k/powerlevel10k.zsh-theme
ZSH_THEME="powerlevel10k/powerlevel10k"

# Add completions to fpath
fpath=($HOME/.zsh/zsh-completions/src $fpath)
autoload -U compinit && compinit

source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source ~/.zsh/zsh-interactive-cd/zsh-interactive-cd.plugin.zsh
source ~/.zsh/zsh-autocomplete/zsh-autocomplete.plugin.zsh
zstyle ':autocomplete:*' delay 3
zstyle ':autocomplete:*' min-input 3

# History settings
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY

export PATH="$HOME/.local/bin:$PATH"

# Icons for files/folders in terminal using eza
alias ls='eza -l --icons'
alias ll='eza -al --icons'
alias lt='eza -alr --sort=mod --tree --level=1 --icons'
alias df='df -hT -xtmpfs -xdevtmpfs -xefivarfs'
alias ff='fastfetch'
alias cat='batcat'

function git() {
  if [[ "$1" == "add" && "$2" == "," ]]; then
    echo "fixed another typo dumdum"
    command git add .
  else
    command git "$@"
  fi
}

# NVM 
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
