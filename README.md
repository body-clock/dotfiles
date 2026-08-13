# dotfiles

Mac → Mac developer environment, kept deliberately small and additive.

## Philosophy

One owner per bucket, and nothing installed until you reach for it:

| Bucket | Owner | Examples |
|---|---|---|
| Versioned runtimes | **mise** (`~/.config/mise/config.toml`) | ruby, node, neovim, zoxide |
| System packages + apps | **Homebrew** (`Brewfile`) | git, tmux, fzf, ghostty, postgres |
| Ecosystem CLIs | native `-g` installers | pi (npm) |

Tiebreaker: *would I ever want two versions, or pin it per-project? → mise. Otherwise → brew.*

## Setup (new machine)

```sh
git clone --recursive https://github.com/body-clock/dotfiles.git ~/dotfiles
~/dotfiles/bootstrap.sh
```

`bootstrap.sh` installs Xcode CLT, Homebrew, mise, the Brewfile, rails + bundler, starts postgres, symlinks everything via stow, and installs pi.

## Manual steps (not in the repo — secrets)

- `gh auth login`
- Restore SSH keys → `~/.ssh` (chmod 600)
- `git config --global user.name "..."` / `user.email "..."` (new job identity)
- `npm login` (re-creates `~/.npmrc` token)
- App Store apps: install `mas`, run `mas list` on the old machine → `mas install <ids>` on the new one
- Maccy (clipboard history): enable "Launch at login" in its preferences

## Adding a tool (additive)

Reach for it first, then:

```sh
brew install <formula>      # system tool → add to Brewfile if it sticks
mise use -g <tool>@<ver>    # runtime → lands in mise.toml
```

## Layout

Each top-level dir is a stow package (`.config/<tool>` or home dotfiles). `bootstrap.sh` runs `stow` to symlink them into place.
