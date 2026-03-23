#!/usr/bin/env bash
# cc-launch — open a terminal, pick a project, start coding

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
SKIP_PERMISSIONS=false
RESUME_SESSION=false

# Load config if it exists
[[ -f "$CONFIG" ]] && source "$CONFIG"

if [[ ! -d "$PROJECTS_ROOT" ]]; then
  echo "cc-launch: projects root not found: $PROJECTS_ROOT" >&2
  echo "  Update PROJECTS_ROOT in $CONFIG" >&2
  exit 1
fi

HISTORY_FILE="${HOME}/.claude/cc-launch-history"
RECENT_MARK="★  "
AMBER=$'\e[38;5;214m'
RESET=$'\e[0m'

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

# Build picker list: recent (amber mark) at top, rest deduped below
if [[ ${#recent[@]} -gt 0 ]]; then
  other_paths="$all_paths"
  for r in "${recent[@]}"; do
    other_paths=$(printf '%s\n' "$other_paths" | grep -vxF "$r")
  done
  list=$(
    printf "${AMBER}${RECENT_MARK}${RESET}%s\n" "${recent[@]}"
    [[ -n "$other_paths" ]] && printf '%s\n' "$other_paths"
  )
else
  list="$all_paths"
fi

export PROJECTS_ROOT
export CONFIG

# Toggle a boolean config key in the config file (portable, macOS + Linux)
_toggle_config() {
  local key="$1" current="$2"
  local new_val; [[ "$current" == "true" ]] && new_val="false" || new_val="true"
  if grep -q "^${key}=" "$CONFIG" 2>/dev/null; then
    local tmp; tmp=$(mktemp)
    while IFS= read -r line; do
      if [[ "$line" =~ ^${key}= ]]; then
        echo "${key}=${new_val}"
      else
        printf '%s\n' "$line"
      fi
    done < "$CONFIG" > "$tmp"
    mv "$tmp" "$CONFIG"
  else
    echo "${key}=${new_val}" >> "$CONFIG"
  fi
}

# Picker loop — re-runs on ctrl-d / ctrl-r so the header reflects toggled state
while true; do
  SKIP_PERMISSIONS=false
  RESUME_SESSION=false
  [[ -f "$CONFIG" ]] && source "$CONFIG"

  if [[ "$SKIP_PERMISSIONS" == "true" ]]; then
    skip_label=$'\e[38;5;214m⚡ skip-perms: ON \e[0m'
  else
    skip_label=$'\e[38;5;240mskip-perms: off\e[0m'
  fi

  if [[ "$RESUME_SESSION" == "true" ]]; then
    resume_label=$'\e[38;5;114m↺ resume: ON \e[0m'
  else
    resume_label=$'\e[38;5;240mresume: off\e[0m'
  fi

  header="  ${skip_label}  $'\e[38;5;240m│\e[0m'  ${resume_label}"$'\n'$'\e[38;5;240m  ctrl-d: toggle skip-perms   ctrl-r: toggle resume\e[0m'

  result=$(printf '%s\n' "$list" \
    | fzf \
        --ansi \
        --expect='ctrl-d,ctrl-r' \
        --header="$header" \
        --prompt="  ❯  " \
        --pointer="▶" \
        --height=55% \
        --min-height=15 \
        --layout=reverse \
        --border=rounded \
        --border-label=" ✦ Claude Code ✦ " \
        --color='bg+:#1e1b18,fg+:#f0ead6,hl:#d4a853,hl+:#d4a853,prompt:#d4a853,pointer:#d4a853,border:#4a3f35,label:#d4a853,info:#7a6a5a,separator:#2d2520' \
        --info=inline-right \
        --preview='
          p=$(printf "%s" {} | sed "s/^.*★  //" | tr -d "\033" | sed "s/\[[0-9;]*m//g")
          dir="$PROJECTS_ROOT/$p"
          branch=$(git -C "$dir" branch --show-current 2>/dev/null)
          [[ -n "$branch" ]] && printf "\033[38;5;141m  ⎇  %s\033[0m\n\n" "$branch"
          find "$dir" -maxdepth 1 -mindepth 1 -type d -not -name ".*" | sort | sed "s|.*/||" | \
            while IFS= read -r d; do printf "\033[1;34m  %s/\033[0m\n" "$d"; done
          find "$dir" -maxdepth 1 -mindepth 1 ! -type d -not -name ".*" | sort | sed "s|.*/||" | \
            while IFS= read -r f; do printf "\033[38;5;250m  %s\033[0m\n" "$f"; done
        ' \
        --preview-window=right:40%:border-left)

  key=$(printf '%s\n' "$result" | head -1)
  selected=$(printf '%s\n' "$result" | sed -n '2p')

  if [[ "$key" == "ctrl-d" ]]; then
    _toggle_config "SKIP_PERMISSIONS" "$SKIP_PERMISSIONS"
    continue
  fi

  if [[ "$key" == "ctrl-r" ]]; then
    _toggle_config "RESUME_SESSION" "$RESUME_SESSION"
    continue
  fi

  [[ -z "$selected" ]] && exit 0
  break
done

# Strip ANSI codes then the recent mark
selected=$(printf '%s' "$selected" | sed $'s/\033\\[[0-9;]*m//g')
selected="${selected#${RECENT_MARK}}"

# Save to history: new entry at top, deduped, keep last 50
{
  echo "$selected"
  [[ -f "$HISTORY_FILE" ]] && grep -vxF "$selected" "$HISTORY_FILE"
} | head -50 > "${HISTORY_FILE}.tmp" && mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE"

# Build claude flags
claude_args=()
[[ "$SKIP_PERMISSIONS" == "true" ]] && claude_args+=(--dangerously-skip-permissions)
[[ "$RESUME_SESSION"   == "true" ]] && claude_args+=(--continue)

cd "$PROJECTS_ROOT/$selected" && exec claude "${claude_args[@]}"
