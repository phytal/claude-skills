#!/bin/bash
set -e

SKILLS_DIR="$HOME/.claude/skills"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$SKILLS_DIR"

skills=(flag-review implementation-review implementation-recap feedback-review)

for skill in "${skills[@]}"; do
  if [ -d "$SKILLS_DIR/$skill" ]; then
    echo "Updating $skill..."
  else
    echo "Installing $skill..."
  fi
  cp -r "$SCRIPT_DIR/$skill" "$SKILLS_DIR/"
done

echo ""
echo "Installed ${#skills[@]} skills to $SKILLS_DIR"
echo "They'll be available globally in your next Claude Code session."
