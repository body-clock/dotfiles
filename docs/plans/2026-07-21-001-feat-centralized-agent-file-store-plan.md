---
title: "Centralized Agent File Store — Implementation Plan"
type: feat
status: completed
date: 2026-07-21
origin: docs/brainstorms/2026-07-21-centralized-agent-file-store-requirements.md
---

# Centralized Agent File Store — Implementation Plan

## Summary

A bash sync tool (`agent-sync`) lives in a new `agents/` dir in dotfiles, reads a simple line-based manifest, and projects each canonical agent file from a separate private `agent-store` repo into its project as a symlink that's gitignored via `.git/info/exclude`. Migration of the 3 existing tracked AGENTS.md files is an explicit per-project untrack step, never a silent tool action.

---

## Problem Frame

The brainstorm (origin doc) establishes the full problem context: project agent files living inside repos get lost to LLM-driven git operations across all vectors. This plan implements the agreed solution — a private store + explicit sync tool — and resolves the one open product question the brainstorm didn't settle: how to handle projects where AGENTS.md is currently git-tracked (all 3 are).

---

## Requirements

- R1. A dedicated, private, version-controlled git repo is the single source of truth for all project agent files. (origin)
- R2. The store organizes files per-project and is filename-agnostic. (origin)
- R3. Each canonical file is projected as a symlink (not a copy). (origin)
- R4. Projected symlinks are gitignored (not committed). (origin)
- R5. The canonical file never lives inside any project repo's git tree. (origin)
- R6. An explicit, one-command sync reconciles the store against project repos. (origin)
- R7. Sync is idempotent and safe to re-run. (origin)
- R8. Sync is driven by an explicit manifest of project→file mappings. (origin)

- R9. The sync tool refuses to replace a git-tracked target (safety gate for tracked AGENTS.md files).

---

## Scope Boundaries

- No `cd` hook / direnv auto-linking (origin — explicit sync chosen).
- No auto-discovery scanning of `~/code` (origin — explicit manifest chosen).
- No versioning/backup of per-tool global files (`~/.pi`, `~/.codex`, etc.) in v1 (origin).
- No `bats` test framework wired into dotfiles in v1 (verification is by scenario; adding a test runner is tangential).
- TOML manifest format rejected for v1 in favor of a simple line-based format (shell-parseable, no deps). Redirect to brainstorm if TOML is preferred.
- If any of the 3 existing project AGENTS.md files are team-shared (not personal), those projects are excluded from symlink protection in v1 — the tool skips them and logs a warning.

---

## Context & Research

### Relevant Code and Patterns

- **dotfiles PATH convention**: `export PATH=/path/to/bin:$PATH` in `.zshrc` for each tool (opencode, antigravity, lmstudio, mimicode). New `agents/bin/` dir follows this pattern.
- **TOML house style**: mise config, starship, tinted-theming all use TOML. Manifest format deliberately diverged to shell-parseability; TOML alternative noted as deferred.
- **No existing `bin/` or tooling dir** in dotfiles — greenfield `agents/` directory.

### Institutional Learnings

None in `docs/solutions/` — this is a new category of personal tooling.

### External References

Not required — the technical surface (symlinks, gitignore, bash scripting) is well-understood and low-risk.

---

## Key Technical Decisions

- **Store repo**: `agent-store`, hosted under `body-clock` GitHub org (where `dotfiles` and `bodyclock.nvim` already live), checked out at `~/.agent-store`. *Flag if personal-account preferred.*
- **Gitignore mechanism**: `.git/info/exclude` (local-only, never committed, doesn't collide with project `.gitignore`). Sync ensures the exclude entry idempotently.
- **Manifest format**: simple line-based — one entry per line: `<name>  <absolute-path-to-repo>  <filename>`. Parsed with `read` in bash. Rejected TOML (would require a parser dep). *Flag if TOML preferred.*
- **Tracked-file safety**: `agent-sync` checks `git ls-files --error-unmatch <target>` before creating a symlink. If tracked, it refuses and prints a warning naming the file and suggesting explicit migration. This is the safety gate for all 3 existing projects (their AGENTS.md is tracked).
- **Migration is manual/explicit**: moving a tracked AGENTS.md into the store requires: (1) `git rm --cached AGENTS.md` in the project repo, (2) commit, (3) run `agent-sync` to create the symlink. The tool never does this automatically.

---

## Open Questions

### Resolved During Planning

- **Manifest format**: Resolved to line-based (shell-parseable). TOML rejected for v1.
- **Gitignore mechanism**: Resolved to `.git/info/exclude` (not project `.gitignore`).

### Deferred to Implementation

- **Final command name**: `agent-sync` is the working name. If it collides with an existing command, rename.
- **Store repo URL**: exact GitHub URL depends on org choice (body-clock vs personal). Set during U1.

---

## Output Structure

```
dotfiles/
  agents/
    bin/
      agent-sync          # the sync script
    manifest.txt           # line-based project→file mappings

~/.agent-store/          # checked-out private store repo
  milkcrate/
    AGENTS.md
  bodyclock.fm/
    AGENTS.md
  clover-iiif/
    AGENTS.md
```

---

## Implementation Units

### U1. Create private store repo + local checkout

**Goal:** Establish the private repo that holds canonical agent files.

**Requirements:** R1, R9

**Dependencies:** None

**Files:**
- Create: `~/.agent-store/` (checked-out repo)
- Create: `milkcrate/AGENTS.md`, `bodyclock-fm/AGENTS.md`, `clover-iiif/AGENTS.md` (canonical files, migrated from project repos during U4)

**Approach:**
1. Create a private GitHub repo named `agent-store` under the `body-clock` org.
2. Clone it to `~/.agent-store`.
3. Create the directory structure (`milkcrate/`, `bodyclock-fm/`, `clover-iiif/`).
4. Add a `README.md` explaining the repo's purpose.
5. Commit + push.

**Verification:**
- `ls ~/.agent-store/` shows the 3 project dirs.
- `git -C ~/.agent-store remote -v` shows the correct GitHub URL.

---

### U2. Build the `agent-sync` tool

**Goal:** A bash script that reads the manifest, creates/repairs symlinks, and ensures gitignore entries — idempotent and safe.

**Requirements:** R3, R4, R5, R6, R7, R8, R10

**Dependencies:** U1 (store repo exists)

**Files:**
- Create: `agents/bin/agent-sync`
- Modify: `zsh/.zshrc` (add `export PATH="/Users/pperkins/dotfiles/agents/bin:$PATH"`)
- Create: `agents/manifest.txt`

**Approach:**

The script handles 4 modes:
1. **No args** — reconcile all entries in the manifest.
2. **`<name>`** — sync only the named project.
3. **`--dry-run`** — print what would change without applying.
4. **`--list`** — print all manifest entries.

Core logic per manifest entry:
1. Read name, repo path, filename from manifest.
2. Resolve: `STORE_FILE=~/.agent-store/$name/$filename`, `REPO_TARGET=$repo_path/$filename`.
3. Check if `REPO_TARGET` is git-tracked (`git ls-files --error-unmatch`). If tracked: refuse, warn, skip.
4. If `STORE_FILE` doesn't exist: warn, skip.
5. If `REPO_TARGET` is a real file (not a symlink): warn, skip (protects against accidental overwrite).
6. If `REPO_TARGET` symlink already points to `STORE_FILE`: done (idempotent).
7. Otherwise: `ln -sf $STORE_FILE $REPO_TARGET`.
8. Ensure `.git/info/exclude` in the repo contains an entry for `$filename` (idempotent append if missing).

**Patterns to follow:**
- Existing PATH-export pattern in `zsh/.zshrc` (one line per tool bin dir).
- Simplicity and debuggability (no subshell forests, prints each action).

**Test scenarios:**

- **Happy path**: Manifest has one entry, store file exists, repo target doesn't exist → symlink created, exclude entry added. Run again → no-op (idempotent).
- **Edge case**: `REPO_TARGET` already a correct symlink → detected, skipped (idempotent).
- **Edge case**: `REPO_TARGET` is a real file (not a symlink) → warning printed, no action taken.
- **Error path**: `STORE_FILE` doesn't exist → warning printed, entry skipped.
- **Error path**: `REPO_TARGET` is git-tracked → refusal warning printed, entry skipped. This is the safety gate for all 3 existing projects.
- **Integration**: After `git clean -fdx` in a project repo, the symlink (gitignored) survives and still points to the store file.

**Verification:**
- `agent-sync --list` prints all manifest entries.
- `agent-sync --dry-run` prints planned actions without applying them.
- `agent-sync` (no args) creates all symlinks and reports what it did.
- Re-running `agent-sync` produces no actions (idempotent).
- `agent-sync milkcrate` syncs only the milkcrate entry.

---

### U3. Migrate existing project AGENTS.md files into the store

**Goal:** Move the 3 existing tracked AGENTS.md files into the store and replace them with symlinks — explicit per-project step.

**Requirements:** R1, R3, R5 (covers AE1–AE4 from origin)

**Dependencies:** U1, U2

**Files:**
- Modify: `~/.agent-store/milkcrate/AGENTS.md` (copied from repo)
- Modify: `~/.agent-store/bodyclock-fm/AGENTS.md` (copied from repo)
- Modify: `~/.agent-store/clover-iiif/AGENTS.md` (copied from repo)
- Modify: Each project repo's `AGENTS.md` (replaced with symlink after `git rm --cached`)

**Approach (per project):**
1. Copy the existing `AGENTS.md` from the project repo into `~/.agent-store/<project>/AGENTS.md`.
2. In the project repo: `git rm --cached AGENTS.md` (untracks it — this commits a removal to the repo, so collaborators stop receiving AGENTS.md via git).
3. Commit the removal with a message like `chore: move AGENTS.md to centralized store`.
4. Run `agent-sync <project>` to create the symlink and exclude entry.
5. Verify: `cat AGENTS.md` in the repo shows the store file's content; `git status` shows the symlink as untracked but excluded.

**Decision point**: If any AGENTS.md is team-shared (not purely personal), **skip that project** — it stays as-is (tracked, vulnerable to git ops, but intentionally so). The tool will warn about tracked files and name them; use that to decide pre-migration.

**Test scenarios (covers origin AE1–AE4):**

- **AE1**: Given a project repo, after `agent-sync` creates the symlink and exclude entry, `git clean -fdx` leaves the symlink and store file untouched. ✓
- **AE2**: Given a project repo, after `git stash` or a branch switch, the symlink remains (git doesn't track it). ✓
- **AE3**: Given a manifest entry for `milkcrate`, first `agent-sync` creates the symlink and adds the exclude entry; second `agent-sync` is a no-op. ✓
- **AE4**: Given a project where the symlink was deleted, `agent-sync` recreates it pointing at the store file; the store file is untouched. ✓

**Verification:**
- Each project repo's `AGENTS.md` is a symlink to `~/.agent-store/<project>/AGENTS.md`.
- `git -C <project> ls-files AGENTS.md` returns empty (file is untracked/excluded).
- Content is identical: `diff <project>/AGENTS.md ~/.agent-store/<project>/AGENTS.md` shows no differences.
- Store repo has all 3 files committed and pushed.

---

## System-Wide Impact

- **Interaction graph**: The sync tool touches `.git/info/exclude` in each project repo — a local-only file that doesn't affect collaborators. The migration (`git rm --cached`) commits a removal to each project's `development` or `main` branch — collaborators will stop receiving AGENTS.md via git after pulling.
- **Error propagation**: If the store repo is deleted or moved, all symlinks break simultaneously. Mitigation: the store repo is private + version-controlled; a fresh clone restores it. `agent-sync --dry-run` will show all symlinks as broken.
- **State lifecycle risks**: None — symlinks are stateless pointers; the store repo is the single source of truth.
- **Unchanged invariants**: Project repos' code, tests, and committed files are untouched by the sync tool. Only `AGENTS.md` (and optionally `CLAUDE.md`) are symlinked, and only after explicit migration.

---

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| Store repo deleted/moved → all symlinks break | Store repo is version-controlled + private; `agent-sync --dry-run` detects broken symlinks; re-clone + re-run fixes. |
| Accidental `git add AGENTS.md` in project repo (adds symlink to git) | `.git/info/exclude` entry prevents `git add .` from picking it up; symlink to external path may break on other machines anyway (by design — personal config). |
| Migration commit (`git rm --cached AGENTS.md`) surprises collaborators | Communicate the change to the team before migrating; or decide pre-migration that the file is personal and collaborators don't need it. |
| Bash script portability (macOS vs Linux) | Uses standard bash + git commands; avoids macOS-specific `stat` flags or Linux-specific `readlink -f`. Tested on macOS (the user's machine). |

---

## Documentation / Operational Notes

- Store repo `README.md` should explain: (1) what the repo is, (2) how to add a new project, (3) that `agent-sync` must be re-run after adding a project.
- dotfiles `README.md` (or a new `agents/README.md`) should explain: (1) what `agent-sync` does, (2) how to run it, (3) the safety gate for tracked files.
- Cross-machine bootstrap: clone dotfiles (gets the tool), clone `agent-store` to `~/.agent-store` (gets the files), run `agent-sync`.

---

## Sources & References

- **Origin document:** [docs/brainstorms/2026-07-21-centralized-agent-file-store-requirements.md](docs/brainstorms/2026-07-21-centralized-agent-file-store-requirements.md)
- **Related code:** `zsh/.zshrc` (PATH exports), `milkcrate/AGENTS.md`, `bodyclock.fm/AGENTS.md`, `clover-iiif/AGENTS.md`
- **Skill context:** `ce-brainstorm` (requirements), `ce-plan` (this plan)
