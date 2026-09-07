#!/usr/bin/env bash
# Install the repo's skills into the agents that read a SKILL.md folder:
# Claude Code (.claude/skills), Cursor (.cursor/skills), and Codex (.codex/skills).
#
# It links each skill under skills/ into those directories, project scoped
# (inside this repo). When symlinks are unavailable (Windows without developer
# mode / core.symlinks, restricted filesystems), it falls back to copying the
# skill folder so the skill still loads. It also repairs the broken text stubs
# that a committed symlink turns into on a Windows checkout.
# Idempotent: safe to run repeatedly. Run from the repo root:
#   bash skills/install.sh
# On Windows, run it from Git Bash (bundled with Git for Windows), or use the
# PowerShell equivalent: powershell -ExecutionPolicy Bypass -File skills/install.ps1
set -u

# Resolve the repo root as the parent of this script's directory.
SKILLS_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SKILLS_DIR/.." && pwd)"

TARGETS=(".claude/skills" ".cursor/skills" ".codex/skills")

# Detect a Windows shell (Git Bash / MSYS / Cygwin), where symlinks usually do
# not work and silently become tiny text stubs.
IS_WINDOWS=0
case "$(uname -s 2>/dev/null)" in
  MINGW*|MSYS*|CYGWIN*) IS_WINDOWS=1 ;;
esac

# link_or_copy <src_skill_dir> <dest_link>
# Every target lives two levels below the repo root (e.g. .claude/skills), so the
# relative path back to a skill is always ../../skills/<name>. That avoids the
# old python3 os.path.relpath dependency entirely.
link_or_copy () {
  local src="$1" dest="$2" name
  name="$(basename "$src")"
  local rel="../../skills/$name"

  # Clear whatever is there now: a real dir, a valid symlink, or a broken stub.
  rm -rf "$dest"

  if [ "$IS_WINDOWS" -eq 0 ] && ln -s "$rel" "$dest" 2>/dev/null && [ -d "$dest" ]; then
    echo "linked  ${dest#$REPO_ROOT/} -> $rel"
    return 0
  fi

  # Symlink is unavailable or produced a non-directory stub: copy instead.
  rm -rf "$dest"
  if cp -R "$src" "$dest" 2>/dev/null; then
    echo "copied  ${dest#$REPO_ROOT/} (symlinks unavailable, copied the folder)"
    return 0
  fi

  echo "ERROR: could not link or copy into ${dest#$REPO_ROOT/}" >&2
  return 1
}

# Every subdirectory of skills/ that contains a SKILL.md is a skill.
installed=0
for skill_path in "$SKILLS_DIR"/*/; do
  [ -f "${skill_path}SKILL.md" ] || continue
  skill_path="${skill_path%/}"
  name="$(basename "$skill_path")"
  for t in "${TARGETS[@]}"; do
    dir="$REPO_ROOT/$t"
    mkdir -p "$dir"
    link_or_copy "$skill_path" "$dir/$name"
  done
  installed=$((installed + 1))
done

echo ""
echo "installed $installed skill(s) into: ${TARGETS[*]}"
echo "Cursor also reads .claude/skills and .codex/skills, so it is covered as well."
if [ "$IS_WINDOWS" -eq 1 ]; then
  echo "Windows detected: skills were copied rather than symlinked."
  echo "Re-run this after pulling new changes to refresh the copies."
fi
echo "Next: invoke /xrpl-agentic-resources in your agent, or run its refresh once:"
if [ "$IS_WINDOWS" -eq 1 ]; then
  echo "  powershell -ExecutionPolicy Bypass -File skills/xrpl-agentic-resources/scripts/refresh.ps1"
else
  echo "  bash skills/xrpl-agentic-resources/scripts/refresh.sh"
fi
