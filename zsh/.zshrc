export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"
ALIAS_CONFIG=~/.zsh_aliases

plugins=(git rails zsh-autosuggestions zsh-syntax-highlighting zsh-vi-mode)

source $ZSH/oh-my-zsh.sh
source $ALIAS_CONFIG

export PATH="/opt/homebrew/opt/curl/bin:$PATH"
export PYENV_ROOT="$HOME/.pyenv"
export PGGSSENCMODE="disable"

eval "$(/opt/homebrew/bin/brew shellenv)"
eval "$(starship init zsh)"
eval "$(~/.local/bin/mise activate zsh)"
