# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"

plugins=(git rails asdf)

source $ZSH/oh-my-zsh.sh

# User configuration
export PATH="/opt/homebrew/opt/curl/bin:$PATH"
export PYENV_ROOT="$HOME/.pyenv"
export PGGSSENCMODE="disable"

# Import aliases
. ~/.zsh_aliases

eval "$(/opt/homebrew/bin/brew shellenv)"
eval "$(starship init zsh)"
