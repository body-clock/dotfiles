#!/usr/bin/env bash
set -euo pipefail

# Additive bootstrap — installs only what a Rails machine + these dotfiles need.
# Everything else is installed on demand (`brew install <x>`, add to mise.toml).

DOTFILES="$HOME/dotfiles"
DOTFILES_REPO="https://github.com/body-clock/dotfiles.git"

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

# 0. Ensure dotfiles are cloned (with submodules)
if [ ! -d "$DOTFILES/.git" ]; then
  step "Cloning dotfiles"
  git clone --recursive "$DOTFILES_REPO" "$DOTFILES"
else
  step "Updating dotfiles"
  git -C "$DOTFILES" pull --ff-only || true
  git -C "$DOTFILES" submodule update --init --recursive
fi

# 1. Xcode Command Line Tools (prereq for brew + native gems)
if ! xcode-select -p &>/dev/null; then
  step "Installing Xcode Command Line Tools"
  xcode-select --install
  echo "Re-run bootstrap.sh once CLT install finishes."
  exit 0
fi

# 2. Homebrew
if ! command -v brew &>/dev/null; then
  step "Installing Homebrew"
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# 3. mise (version manager — via installer, not brew)
if ! command -v mise &>/dev/null; then
  step "Installing mise"
  curl https://mise.run | sh
fi
export PATH="$HOME/.local/bin:$PATH"

# 4. Homebrew packages
step "Installing Homebrew packages (Brewfile)"
brew bundle --file="$DOTFILES/Brewfile"

# 5. Symlink dotfiles (before mise install, so mise reads the linked config)
step "Symlinking dotfiles"
cd "$DOTFILES"
stow --target="$HOME" zsh tmux ghostty kitty aerospace starship ideavim mise tinted-theming git karabiner zed tuicr
ln -sfn "$DOTFILES/bodyclock.nvim/.config/nvim" "$HOME/.config/nvim"

# 6. Runtimes via mise
step "Installing runtimes (mise)"
mise install

# 7. Rails + bundler into the mise-managed ruby
step "Installing Rails + Bundler"
eval "$(mise activate bash)"
gem install --no-document rails bundler

# 8. PostgreSQL as a service
step "Starting PostgreSQL"
brew services start postgresql@17

# 9. pi (coding agent) + extensions
step "Installing pi"
npm install -g @earendil-works/pi-coding-agent
pi install npm:pi-subagents
pi install npm:pi-ask-user

step "Done"
cat <<'EOF'

Manual steps remaining (secrets — deliberately not in this repo):
  gh auth login
  restore SSH keys to ~/.ssh (chmod 600)
  git config --global user.name / user.email   (new job identity)
  npm login                                     (re-create ~/.npmrc token)

EOF
