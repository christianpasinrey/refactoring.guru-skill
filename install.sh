#!/usr/bin/env bash
#
# Install the patterns-and-refactoring skill for Claude Code.
#
#   ./install.sh              install globally to ~/.claude/skills
#   ./install.sh --project    install to ./.claude/skills in the current directory
#
set -euo pipefail

SKILL_NAME="patterns-and-refactoring"
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/skills/${SKILL_NAME}"

if [ ! -d "$SOURCE_DIR" ]; then
  echo "error: skill source not found at ${SOURCE_DIR}" >&2
  exit 1
fi

if [ "${1:-}" = "--project" ]; then
  TARGET_ROOT="$(pwd)/.claude/skills"
  SCOPE="project ($(pwd))"
else
  TARGET_ROOT="${HOME}/.claude/skills"
  SCOPE="global (${HOME}/.claude)"
fi

TARGET_DIR="${TARGET_ROOT}/${SKILL_NAME}"

if [ -d "$TARGET_DIR" ]; then
  printf 'Skill already installed at %s\nOverwrite? [y/N] ' "$TARGET_DIR"
  read -r reply
  case "$reply" in
    [yY]*) rm -rf "$TARGET_DIR" ;;
    *) echo "Aborted."; exit 0 ;;
  esac
fi

# Copy the *contents* into an explicitly created target directory. `cp -r src dst`
# would create dst as a copy of src when dst does not exist, which puts SKILL.md
# and references/ loose in skills/ instead of inside skills/<SKILL_NAME>/.
mkdir -p "$TARGET_DIR"
cp -R "$SOURCE_DIR/." "$TARGET_DIR/"

REF_COUNT=$(find "${TARGET_DIR}/references" -name '*.md' -type f | wc -l | tr -d ' ')

echo "Installed ${SKILL_NAME} — ${SCOPE}"
echo "  ${TARGET_DIR}"
echo "  SKILL.md + ${REF_COUNT} reference files"
echo
echo "Verify with /skills inside Claude Code."
echo "To make invocation mandatory, see CLAUDE.md.snippet.md."
