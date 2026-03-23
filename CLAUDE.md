# CLAUDE.md

This file provides guidance to Claude Code when working with the cc-launch project.

Project name: **cc-launch**

## What this project does

`cc-launch` is a cross-platform project picker for Claude Code. It uses `fzf` to let the user select a directory from a configurable projects root, then `cd`s into it and launches `claude`.

## Running

```bash
bash cc-launch.sh
```

Requires `fzf` and `claude` to be in `$PATH`.

## Installing

```bash
bash install-picker.sh
```

Two modes:
- **Mode 1 (always-on):** hooks shell RCs so picker runs on every new interactive shell
- **Mode 2 (on-demand):** installs a `claude-shell` wrapper + terminal keybind; picker only runs when `CC_LAUNCH=1` is set

## Uninstalling

```bash
bash uninstall-picker.sh
```

Reads `~/.claude/cc-launch-manifest.json` and reverses all changes.

## Architecture

| File | Role |
|------|------|
| `cc-launch.sh` | The picker — reads config, runs `find` + `fzf`, execs `claude` |
| `install-picker.sh` | Unified installer: prompts for mode/config, hooks shells, writes manifest |
| `uninstall-picker.sh` | Reads manifest, removes blocks from RC files, deletes created files |
| `install-cc-launch.sh` | Terminal-specific keybind setup (called by installer in mode 2) |
| `install-windows.ps1` | Native Windows PowerShell installer |

## Config

Written to `~/.claude/cc-launch.conf` by the installer. Sourced by `cc-launch.sh` at runtime.

```bash
PROJECTS_ROOT="$HOME/projects"
DEPTH=2
SKIP_PERMISSIONS=false
RESUME_SESSION=false
```

- `PROJECTS_ROOT` — root directory to search for projects
- `DEPTH` — how many levels deep to show (1 = top-level only, 2 = one level of subdirs)
- `SKIP_PERMISSIONS` — when `true`, launches `claude --dangerously-skip-permissions`
- `RESUME_SESSION` — when `true`, launches `claude --continue` to resume the last conversation

Directories named `.*`, `node_modules`, `__pycache__`, `.venv` are always excluded.

## Picker keybinds

| Key | Action |
|-----|--------|
| `enter` | Open selected project in Claude Code |
| `ctrl-d` | Toggle `--dangerously-skip-permissions` (persisted to config) |
| `ctrl-r` | Toggle `--continue` / resume last session (persisted to config) |
| `ctrl-c` / `esc` | Exit without opening anything |

## Manifest

The installer writes `~/.claude/cc-launch-manifest.json` tracking:
- `mode` — which install mode was used
- `modified_files` — RC files that were appended to
- `created_files` — files created from scratch (binary, config, wrapper)
- `backups` — map of `original → backup path` (suffix: `.cc-launch.bak`)

The uninstaller uses this to reverse changes without needing to know the original state.

## Block markers

Every snippet appended to shell RC files is wrapped in:

```
# >>> cc-launch >>>
...
# <<< cc-launch <<<
```

The uninstaller uses these markers for surgical removal via Python regex.

## Platform support

- **macOS:** iTerm2 (plist via Python), Ghostty (config append)
- **Linux:** Ghostty, Kitty, WezTerm, Alacritty (instructions only)
- **Windows/WSL:** Windows Terminal (settings.json via Python)
- **Shells:** zsh, bash, fish, PowerShell (pwsh / powershell)
