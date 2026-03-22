#!/usr/bin/env bash
# cc-launch — uninstaller
# Reads ~/.claude/cc-launch-manifest.json and reverses everything install-picker.sh did.

set -e

OS_WINDOWS=false
case "$OSTYPE" in
  msys|cygwin) OS_WINDOWS=true ;;
esac

if $OS_WINDOWS; then
  MANIFEST="${USERPROFILE}/.claude/cc-launch-manifest.json"
else
  MANIFEST="$HOME/.claude/cc-launch-manifest.json"
fi

echo ""
echo "╭─────────────────────────────────────────────────────────────────╮"
echo "│                cc-launch — Uninstaller                            │"
echo "╰─────────────────────────────────────────────────────────────────╯"
echo ""

if [[ ! -f "$MANIFEST" ]]; then
  echo "  ✗ No manifest found at $MANIFEST"
  echo "    Nothing to uninstall (or install-picker.sh was never run)."
  exit 1
fi

echo "  Reading manifest: $MANIFEST"
echo ""

python3 - "$MANIFEST" <<'PYEOF'
import json, os, re, sys, shutil

BLOCK_START = "# >>> cc-launch >>>"
BLOCK_END   = "# <<< cc-launch <<<"
manifest_path = sys.argv[1]

with open(manifest_path) as f:
    manifest = json.load(f)

mode          = manifest.get("mode", "?")
modified      = manifest.get("modified_files", [])
created       = manifest.get("created_files", [])
backups       = manifest.get("backups", {})
timestamp     = manifest.get("timestamp", "unknown")

print(f"  Installed:  {timestamp}")
print(f"  Mode:       {'every new tab' if mode == '1' else 'on-demand keybind'}")
print(f"  Modified:   {len(modified)} file(s)")
print(f"  Created:    {len(created)} file(s)")
print()

# ── 1. Remove blocks from modified files ──────────────────────────────────────
def remove_block(filepath):
    """Remove the cc-launch block (between BLOCK_START and BLOCK_END) from a file."""
    try:
        with open(filepath, "r") as f:
            content = f.read()
    except FileNotFoundError:
        return False, "not found"

    if BLOCK_START not in content:
        return False, "marker not found"

    # Remove: optional leading newline + BLOCK_START line + content + BLOCK_END line + optional trailing newline
    pattern = r'\n?' + re.escape(BLOCK_START) + r'.*?' + re.escape(BLOCK_END) + r'\n?'
    new_content, n = re.subn(pattern, "", content, flags=re.DOTALL)

    if n == 0:
        return False, "pattern not matched"

    with open(filepath, "w") as f:
        f.write(new_content)
    return True, f"removed {n} block(s)"

if modified:
    print("── Removing blocks from shell RC files ───────────────────────────────")
    for filepath in modified:
        expanded = os.path.expanduser(filepath)
        ok, msg = remove_block(expanded)
        status = "✓" if ok else "⚠"
        print(f"  {status} {filepath}  ({msg})")
    print()

# ── 2. Delete created files ────────────────────────────────────────────────────
if created:
    print("── Deleting installed files ──────────────────────────────────────────")
    for filepath in created:
        expanded = os.path.expanduser(filepath)
        if os.path.exists(expanded):
            os.remove(expanded)
            print(f"  ✓ deleted  {filepath}")
        else:
            print(f"  ⚠ missing  {filepath}")
    print()

# ── 3. Backups ─────────────────────────────────────────────────────────────────
if backups:
    print("── Backups ───────────────────────────────────────────────────────────")
    for original, backup in backups.items():
        backup_expanded = os.path.expanduser(backup)
        if os.path.exists(backup_expanded):
            print(f"  ✓ kept     {backup}")
        else:
            print(f"  - missing  {backup}")
    print()
    print("  Backups are kept in place (suffix: .cc-launch.bak).")
    print("  Remove them manually if you no longer need them.")
    print()

# ── 4. Remove manifest ─────────────────────────────────────────────────────────
os.remove(manifest_path)
print(f"  ✓ deleted  {manifest_path}")
print()
print("────────────────────────────────────────────────────────────────────")
print("  Uninstall complete. Restart your shell to apply changes.")
print()
PYEOF
