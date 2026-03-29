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
STATS_FILE="${HOME}/.claude/cc-launch-stats"
BOOKMARKS_FILE="${HOME}/.claude/cc-launch-bookmarks"
RECENT_MARK="★  "
BOOKMARK_MARK="♥  "
AMBER=$'\e[38;5;214m'
MAGENTA=$'\e[38;5;213m'
RESET=$'\e[0m'

# Load up to 3 recent paths that still exist
recent=()
if [[ -f "$HISTORY_FILE" ]]; then
  while IFS= read -r entry; do
    [[ -n "$entry" && -d "$PROJECTS_ROOT/$entry" ]] && recent+=("$entry")
    [[ ${#recent[@]} -ge 3 ]] && break
  done < "$HISTORY_FILE"
fi

# All project paths (expensive find — done once outside the loop)
all_paths=$(find "$PROJECTS_ROOT" -mindepth 1 -maxdepth "$DEPTH" -type d \
  \( -name '.*' -o -name 'node_modules' -o -name '__pycache__' -o -name '.venv' \) -prune \
  -o -type d -print \
  | sed "s|$PROJECTS_ROOT/||" | sort)

export PROJECTS_ROOT
export CONFIG
export STATS_FILE

# Update stats file: increment session count and record timestamp for a project
_update_stats() {
  local project="$1"
  local now; now=$(date +%s)
  local tmp; tmp=$(mktemp)
  local updated=false
  if [[ -f "$STATS_FILE" ]]; then
    while IFS=: read -r path epoch count; do
      if [[ "$path" == "$project" ]]; then
        echo "${path}:${now}:$((count + 1))"
        updated=true
      else
        echo "${path}:${epoch}:${count}"
      fi
    done < "$STATS_FILE" > "$tmp"
  fi
  [[ "$updated" == false ]] && echo "${project}:${now}:1" >> "$tmp"
  mv "$tmp" "$STATS_FILE"
}

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

# Toggle a project in the bookmarks file
_toggle_bookmark() {
  local project="$1"
  if grep -qxF "$project" "$BOOKMARKS_FILE" 2>/dev/null; then
    local tmp; tmp=$(mktemp)
    grep -vxF "$project" "$BOOKMARKS_FILE" > "$tmp"
    mv "$tmp" "$BOOKMARKS_FILE"
  else
    echo "$project" >> "$BOOKMARKS_FILE"
  fi
}

# Strip ANSI codes and all known markers from a picker entry
_clean_path() {
  local raw="$1"
  raw=$(printf '%s' "$raw" | sed $'s/\033\\[[0-9;]*m//g')
  raw="${raw#${BOOKMARK_MARK}}"
  raw="${raw#${RECENT_MARK}}"
  printf '%s' "$raw"
}

# Picker loop — re-runs on any toggle/action key
while true; do
  SKIP_PERMISSIONS=false
  RESUME_SESSION=false
  [[ -f "$CONFIG" ]] && source "$CONFIG"

  # Reload bookmarks (may have changed via ctrl-b)
  bookmarks=()
  if [[ -f "$BOOKMARKS_FILE" ]]; then
    while IFS= read -r entry; do
      [[ -n "$entry" && -d "$PROJECTS_ROOT/$entry" ]] && bookmarks+=("$entry")
    done < "$BOOKMARKS_FILE"
  fi

  # Build picker list: bookmarks → recents (non-bookmarked) → rest
  rest="$all_paths"
  recent_filtered=()
  for b in "${bookmarks[@]}"; do
    rest=$(printf '%s\n' "$rest" | grep -vxF "$b")
  done
  for r in "${recent[@]}"; do
    if ! printf '%s\n' "${bookmarks[@]:-}" | grep -qxF "$r"; then
      recent_filtered+=("$r")
    fi
    rest=$(printf '%s\n' "$rest" | grep -vxF "$r")
  done
  DIM=$'\e[38;5;240m'
  GRN=$'\e[38;5;114m'

  # Add group separators to the rest section when DEPTH >= 2
  if [[ "$DEPTH" -ge 2 && -n "$rest" ]]; then
    rest_grouped=""
    prev_top=""
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      top="${line%%/*}"
      if [[ "$top" != "$prev_top" && -n "$prev_top" ]]; then
        rest_grouped+="${DIM}  ──────────────────────────────────────────${RESET}"$'\n'
      fi
      rest_grouped+="${line}"$'\n'
      prev_top="$top"
    done <<< "$rest"
  else
    rest_grouped="$rest"
  fi

  list=$(
    [[ ${#bookmarks[@]}       -gt 0 ]] && printf "${MAGENTA}${BOOKMARK_MARK}${RESET}%s\n" "${bookmarks[@]}"
    [[ ${#recent_filtered[@]} -gt 0 ]] && printf "${AMBER}${RECENT_MARK}${RESET}%s\n"     "${recent_filtered[@]}"
    [[ -n "$rest_grouped" ]]           && printf '%s' "$rest_grouped"
  )

  if [[ "$SKIP_PERMISSIONS" == "true" ]]; then
    skip_label="${AMBER}⚡ skip-perms: ON${RESET}"
  else
    skip_label="${DIM}skip-perms: off${RESET}"
  fi

  if [[ "$RESUME_SESSION" == "true" ]]; then
    resume_label="${GRN}↺ resume: ON${RESET}"
  else
    resume_label="${DIM}resume: off${RESET}"
  fi

  sep="${DIM}│${RESET}"
  hint="${DIM}  ctrl-d: skip-perms   ctrl-r: resume   ctrl-b: bookmark   ctrl-n: new   ctrl-g: clone${RESET}"
  NL=$'\n'
  header="  ${skip_label}  ${sep}  ${resume_label}${NL}${hint}"

  result=$(printf '%s\n' "$list" \
    | fzf \
        --ansi \
        --expect='ctrl-d,ctrl-r,ctrl-b,ctrl-n,ctrl-g' \
        --header="$header" \
        --prompt="  ❯  " \
        --pointer="▶" \
        --height=55% \
        --min-height=15 \
        --layout=reverse \
        --border=rounded \
        --border-label=" ✦ Claude Code ✦ " \
        --color='fg+:#f0ead6,hl:#d4a853,hl+:#d4a853,prompt:#d4a853,pointer:#d4a853,border:#4a3f35,label:#d4a853,info:#7a6a5a,separator:#2d2520' \
        --bind='change:first' \
        --info=inline-right \
        --preview='
          p=$(printf "%s" {} | tr -d "\033" | sed "s/\[[0-9;]*m//g" | sed "s/^[★♥]  //")
          dir="$PROJECTS_ROOT/$p"
          branch=$(git -C "$dir" branch --show-current 2>/dev/null)
          [[ -n "$branch" ]] && printf "\033[38;5;141m  ⎇  %s\033[0m\n" "$branch"
          if [[ -f "$STATS_FILE" ]]; then
            stats_line=$(grep "^${p}:" "$STATS_FILE" 2>/dev/null | head -1)
            if [[ -n "$stats_line" ]]; then
              epoch=$(echo "$stats_line" | cut -d: -f2)
              count=$(echo "$stats_line" | cut -d: -f3)
              now=$(date +%s)
              diff=$((now - epoch))
              if   [[ $diff -lt 60 ]];    then age="just now"
              elif [[ $diff -lt 3600 ]];  then age="$((diff/60))m ago"
              elif [[ $diff -lt 86400 ]]; then age="$((diff/3600))h ago"
              else                             age="$((diff/86400))d ago"
              fi
              printf "\033[38;5;246m  ⏱ %s  ·  %s sessions\033[0m\n" "$age" "$count"
            fi
          fi
          printf "\n"
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

  if [[ "$key" == "ctrl-b" ]]; then
    [[ -n "$selected" ]] && _toggle_bookmark "$(_clean_path "$selected")"
    continue
  fi

  if [[ "$key" == "ctrl-n" ]]; then
    printf '\n  New project path (relative to %s): ' "$PROJECTS_ROOT" >/dev/tty
    read -r new_project </dev/tty
    new_project="${new_project#/}"
    new_project="${new_project%/}"
    if [[ -z "$new_project" ]]; then
      continue
    fi
    new_dir="$PROJECTS_ROOT/$new_project"
    if [[ -d "$new_dir" ]]; then
      printf '  ✓ Directory already exists: %s\n' "$new_project"
    else
      mkdir -p "$new_dir"
      printf '  ✓ Created: %s\n' "$new_project"
    fi
    selected="$new_project"
    break
  fi

  if [[ "$key" == "ctrl-g" ]]; then
    printf '\n  Git URL to clone: ' >/dev/tty
    read -r clone_url </dev/tty
    clone_url="${clone_url// /}"
    if [[ -z "$clone_url" ]]; then
      continue
    fi
    clone_dest=$(basename "$clone_url" .git)
    if [[ -z "$clone_dest" || "$clone_dest" == "." ]]; then
      printf '  ✗ Could not infer directory name from URL\n' >/dev/tty
      sleep 1
      continue
    fi
    clone_dir="$PROJECTS_ROOT/$clone_dest"
    if [[ -d "$clone_dir" ]]; then
      printf '  ✗ Directory already exists: %s\n' "$clone_dest" >/dev/tty
      sleep 1
      continue
    fi
    printf '  Cloning into %s...\n' "$clone_dest" >/dev/tty
    if git clone "$clone_url" "$clone_dir" </dev/tty >/dev/tty 2>/dev/tty; then
      selected="$clone_dest"
      break
    else
      printf '  ✗ Clone failed\n' >/dev/tty
      sleep 1
      continue
    fi
  fi

  [[ -z "$selected" ]] && exit 0
  # Ignore group separator lines — re-open picker
  [[ "$(_clean_path "$selected")" == "  ─"* ]] && continue
  break
done

# Clean selected path (strip ANSI + markers)
selected=$(_clean_path "$selected")

# Update session stats (count + timestamp)
_update_stats "$selected"

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
