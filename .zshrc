# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

source ~/.zsh/powerlevel10k/powerlevel10k.zsh-theme
ZSH_THEME="powerlevel10k/powerlevel10k"

source ~/.zsh/zsh-interactive-cd/zsh-interactive-cd.plugin.zsh
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.zsh/zsh-history-substring-search/zsh-history-substring-search.zsh
source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Bind up and down arrow to history search
if [[ -n "$SSH_CONNECTION" ]]; then
  # SSH session, use terminfo
  zmodload zsh/terminfo
  [[ -n "$terminfo[kcuu1]" ]] && bindkey "$terminfo[kcuu1]" history-substring-search-up
  [[ -n "$terminfo[kcud1]" ]] && bindkey "$terminfo[kcud1]" history-substring-search-down
  [[ -n "$terminfo[kdch1]" ]] && bindkey "$terminfo[kdch1]" delete-char
  [[ -n "$terminfo[kend]"  ]] && bindkey "$terminfo[kend]"  end-of-line
  [[ -n "$terminfo[khome]" ]] && bindkey "$terminfo[khome]" beginning-of-line
else
  # Local session, use hardcoded keys
  bindkey '^[[A' history-substring-search-up
  bindkey '^[[B' history-substring-search-down
  bindkey '^[[3~' delete-char
  bindkey '^[[F' end-of-line
  bindkey '^[[H' beginning-of-line
fi

# Set a compatible terminal type for Ghostty, which may not be known by the server
if [[ "$TERM" == "ghostty" || "$TERM" == "xterm-ghostty" ]]; then
  export TERM=xterm-256color
fi

# History settings
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_SAVE_NO_DUPS

# Paths
export PATH="$HOME/.local/bin:$PATH"
export EDITOR=nvim

# Icons for files/folders in terminal using eza
alias ls='eza -l --icons'
alias ll='eza -al --icons'
alias lt='eza -alr --sort=mod --tree --level=1 --icons'
alias df='df -hT -xtmpfs -xdevtmpfs -xefivarfs'
alias ff='fastfetch'
alias vim='nvim'
alias lg='lazygit'

# Git typos
function git() {
  if [[ "$1" == "add" && "$2" == "," ]]; then
    echo "fixed another typo dumdum"
    command git add .
  else
    command git "$@"
  fi
}

# NVM
[ -s "/usr/share/nvm/init-nvm.sh" ] && source "/usr/share/nvm/init-nvm.sh"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
