# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="$HOME/.oh-my-zsh"
export TERM="xterm-256color"

ZSH_THEME="robbyrussell"
ALIAS_CONFIG=~/.zsh_aliases

plugins=(
	git
	rails
	zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh
source $ALIAS_CONFIG

export PATH="/opt/homebrew/opt/curl/bin:$PATH"
export PYENV_ROOT="$HOME/.pyenv"
export PGGSSENCMODE="disable"
export TINTED_TMUX_OPTION_ACTIVE=1
export TINTED_TMUX_OPTION_STATUSBAR=1

eval "$(/opt/homebrew/bin/brew shellenv)"
# eval "$(starship init zsh)"
eval "$(~/.local/bin/mise activate zsh)"
source $(brew --prefix)/share/powerlevel10k/powerlevel10k.zsh-theme

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
