# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"

plugins=(git rails)

source $ZSH/oh-my-zsh.sh

# User configuration
export PATH="$HOME/.rbenv/shims:$PATH"
export PATH="/opt/homebrew/opt/curl/bin:$PATH"
export PYENV_ROOT="$HOME/.pyenv"
export PGGSSENCMODE="disable"

# Aliases
alias zshconfig="nvim ~/.zshrc"
alias work="cd ~/code/w/"
alias apo="cd ~/code/w/apotheca"
alias vc="cd ~/code/w/VisualCollation"
alias pm="cd ~/code/w/pennmarc"
alias ind="cd ~/code/w/catalog-indexing"
alias clg="cd ~/code/w/find"
alias frank="cd ~/code/w/discovery-app"
alias ob="cd ~/code/obsidian"
alias be="bundle exec"
alias brake="bundle exec rake"
alias brails="bundle exec rails"
alias cop="bundle exec rubocop"
alias spec="bundle exec rspec"
alias copspec="bundle exec rubocop; bundle exec rspec"

eval "$(/opt/homebrew/bin/brew shellenv)"
eval "$(starship init zsh)"
eval "$(rbenv init - zsh)"
