# dotfiles

Mac → Mac developer environment, kept deliberately small and additive.

## Philosophy

One owner per bucket, and nothing installed until you reach for it:

| Bucket | Owner | Examples |
|---|---|---|
| Versioned runtimes | **mise** (`~/.config/mise/config.toml`) | ruby, node, neovim, zoxide |
| System packages + apps | **Homebrew** (`Brewfile`) | git, tmux, fzf, ghostty, postgres, omp |
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

## tmux

**Rebuilding your environment** — `tmux.conf` snapshots every session, window,
pane layout and working directory to `~/.local/share/tmux/rescue/`, refreshed
every 15 minutes by a background loop. Press `prefix C-s` to save on demand and
`prefix C-r` to rebuild from the last snapshot.

To survive a *restart*, install the login agent once:

```sh
~/.config/tmux/scripts/rescue-install-agent.sh      # --status / --uninstall
```

It rebuilds the snapshot at login. Note the honest limit: tmux cannot outlive a
reboot, because the server process dies with the OS. Layout, directories and
window names come back; in-flight process state and scrollback do not, and the
restore deliberately does not re-run commands that happened to be in the
foreground. Real persistence means keeping the tmux server somewhere that does
not restart — a remote host, ideally with `mosh`.

The `tmux` package also carries `scripts/rescue-*.sh` (the snapshot/restore
machinery) and `com.bodyclock.tmux-rescue.plist` (the login agent).

## Layout

Each top-level dir is a stow package (`.config/<tool>` or home dotfiles). `bootstrap.sh` runs `stow` to symlink them into place.

`omp` is the exception that names its own dir: it stows `~/.omp/agent/{config.yml,models.yml,mcp.json}`. Nothing under `~/.omp` is runtime state worth keeping — sessions, logs, caches, `agent.db` and the tinty-generated `themes/tinted.json` all stay local, so only the config surface is versioned. `omp config set` rewrites `config.yml` in place, so a symlinked file keeps its link and `/settings` edits land straight in this repo. `mcp.json` holds no secrets: credentials are shelled out to `pass-cli` at connect time.

## tmuxinator

`tmuxinator` reads `~/.config/tmuxinator/<name>.yml`, which the `tmuxinator`
stow package provides:

```sh
tmuxinator list                 # projects defined
tmuxinator start rails          # launch one
tmuxinator new myapp            # scaffold another
```

`dotfiles.yml` and `rails.yml` are working references — copy one, set `root` and
the window names, then start it. The layouts are declarative, so a project comes
up the same way on every machine; `bootstrap.sh` installs the gem and stows the
package.
