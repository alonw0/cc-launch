# cc-launch

<p align="center">
  <img src="logo.png" alt="cc-launch logo" width="320" />
</p>

If you find yourself opening terminal tabs just to start a new Claude Code session — **cc-launch is for you**.

Open a tab. Pick a project. Claude starts. That's it.

```
╭──────────────── Open Claude Code ─────────────────╮
│   Claude Code >                                    │
│  ★  work/my-api                                   │
│  ★  playground/cc-gym                             │
│   work/frontend                          docs/     │
│   work/my-api                            src/      │
│   playground/cc-gym                      tests/    │
│   playground/side-project                   README.md │
╰────────────────────────────────────────────────────╯
```

Recently opened projects pin to the top. Everything else is one fuzzy search away.

## Requirements

- [`fzf`](https://github.com/junegunn/fzf) — `brew install fzf` / `apt install fzf`
- [Claude Code](https://claude.ai/code) — `curl -fsSL https://claude.ai/install.sh | sh`

## Install

```bash
git clone https://github.com/alonw0/cc-launch.git
cd cc-launch
bash install-picker.sh
```

**Windows (native PowerShell):**
```powershell
git clone https://github.com/alonw0/cc-launch.git
cd cc-launch
pwsh -ExecutionPolicy Bypass -File install-windows.ps1
```

The installer asks two questions:

**1. How do you use your terminal?**

| Choice | Behavior |
|--------|----------|
| `[1]` Mostly for Claude *(recommended)* | cc-launch opens on **every new terminal tab** |
| `[2]` Mixed use | cc-launch only opens via a **keyboard shortcut** |

**2. Where are your projects?**
- Root directory (default: `~/projects`)
- Search depth (default: `2` — finds `projects/foo` and `projects/foo/bar`)

The installer detects your shell(s) (zsh, bash, fish, PowerShell) and configures them automatically. For mode 2 it also sets up a terminal keybind (iTerm2, Ghostty, Kitty, WezTerm, Windows Terminal).

## Uninstall

```bash
bash ~/path/to/cc-launch/uninstall-picker.sh
```

Reads the install manifest and surgically removes every change. Shell RC files are restored cleanly — nothing else is touched.

## Configuration

Edit `~/.claude/cc-launch.conf` to change settings without reinstalling:

```bash
PROJECTS_ROOT="$HOME/projects"
DEPTH=2
SKIP_PERMISSIONS=false
```

| Setting | Default | Description |
|---------|---------|-------------|
| `PROJECTS_ROOT` | `~/projects` | Root directory scanned for projects |
| `DEPTH` | `2` | Search depth (1 = top-level only, 2 = include one level of subdirs) |
| `SKIP_PERMISSIONS` | `false` | Launch Claude with `--dangerously-skip-permissions` |
| `RESUME_SESSION` | `false` | Resume the last conversation (`--continue`) instead of starting fresh |

Both flags can be toggled live inside the picker — no need to edit the file manually:

| Key | Action |
|-----|--------|
| `ctrl-d` | Toggle `--dangerously-skip-permissions` |
| `ctrl-r` | Toggle `--continue` (resume last session) |

The header shows the current state of both options and updates instantly.

Recent project history is stored in `~/.claude/cc-launch-history`.

## Platform support

| Platform | Shell hook | Terminal keybind |
|----------|------------|-----------------|
| macOS | ✓ | iTerm2, Ghostty |
| Linux | ✓ | Ghostty, Kitty, WezTerm, Alacritty* |
| Windows (Git Bash / WSL) | ✓ | Windows Terminal |
| Windows (native PowerShell) | ✓ | Windows Terminal |

\* Alacritty: instructions printed during install

## License

MIT
