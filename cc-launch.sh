#!/usr/bin/env bash
# Pick a project dir with fzf and open Claude Code in it

# Check dependencies
if ! command -v fzf &>/dev/null; then
  echo "cc-launch: fzf not found. Install it from https://github.com/junegunn/fzf" >&2
  exit 1
fi
if ! command -v claude &>/dev/null; then
  echo "cc-launch: claude not found. Install Claude Code from https://claude.ai/code" >&2
  exit 1
fi

CONFIG="${CC_LAUNCH_CONFIG:-$HOME/.claude/cc-launch.conf}"

# Defaults
PROJECTS_ROOT=~/projects
DEPTH=2

# Load config if it exists
[[ -f "$CONFIG" ]] && source "$CONFIG"

if [[ ! -d "$PROJECTS_ROOT" ]]; then
  echo "cc-launch: projects root not found: $PROJECTS_ROOT" >&2
  echo "  Update PROJECTS_ROOT in $CONFIG" >&2
  exit 1
fi

HISTORY_FILE="${HOME}/.claude/cc-launch-history"
RECENT_MARK="★  "

# Load up to 3 recent paths that still exist
recent=()
if [[ -f "$HISTORY_FILE" ]]; then
  while IFS= read -r entry; do
    [[ -n "$entry" && -d "$PROJECTS_ROOT/$entry" ]] && recent+=("$entry")
    [[ ${#recent[@]} -ge 3 ]] && break
  done < "$HISTORY_FILE"
fi

# All project paths
all_paths=$(find "$PROJECTS_ROOT" -mindepth 1 -maxdepth "$DEPTH" -type d \
  \( -name '.*' -o -name 'node_modules' -o -name '__pycache__' -o -name '.venv' \) -prune \
  -o -type d -print \
  | sed "s|$PROJECTS_ROOT/||")

# Build picker list: recent (marked) at top, rest deduped below
if [[ ${#recent[@]} -gt 0 ]]; then
  other_paths="$all_paths"
  for r in "${recent[@]}"; do
    other_paths=$(printf '%s\n' "$other_paths" | grep -vxF "$r")
  done
  list=$(printf "${RECENT_MARK}%s\n" "${recent[@]}"; [[ -n "$other_paths" ]] && printf '%s\n' "$other_paths")
else
  list="$all_paths"
fi

export PROJECTS_ROOT
selected=$(printf '%s\n' "$list" \
  | fzf \
      --prompt="  Claude Code > " \
      --height=40% \
      --layout=reverse \
      --border=rounded \
      --border-label=" Open Claude Code " \
      --preview='
        p=$(printf "%s" {} | sed "s/^★  //"); dir="$PROJECTS_ROOT/$p"
        find "$dir" -maxdepth 1 -mindepth 1 -type d -not -name ".*" | sort | sed "s|.*/||" | while IFS= read -r d; do printf "\033[1;34m%s/\033[0m\n" "$d"; done
        find "$dir" -maxdepth 1 -mindepth 1 ! -type d -not -name ".*" | sort | sed "s|.*/||"
      ' \
      --preview-window=right:40%:wrap)

[[ -z "$selected" ]] && exit 0

# Strip recent marker if present
selected="${selected#${RECENT_MARK}}"

# Save to history: new entry at top, deduped, keep last 50
{
  echo "$selected"
  [[ -f "$HISTORY_FILE" ]] && grep -vxF "$selected" "$HISTORY_FILE"
} | head -50 > "${HISTORY_FILE}.tmp" && mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE"

cd "$PROJECTS_ROOT/$selected" && exec claude
