# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"
ALIAS_CONFIG=~/.zsh_aliases

plugins=(git rails asdf)

# Source files
source $ZSH/oh-my-zsh.sh
source $ALIAS_CONFIG

# User configuration
export PATH="/opt/homebrew/opt/curl/bin:$PATH"
export PYENV_ROOT="$HOME/.pyenv"
export PGGSSENCMODE="disable"

eval "$(/opt/homebrew/bin/brew shellenv)"
eval "$(starship init zsh)"
