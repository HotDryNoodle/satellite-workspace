#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

SUBMODULES=(
  sdk
  task-manager
  plugins/mission-planer
  plugins/image-preprocess
)

git -C "${REPO_ROOT}" config core.hooksPath .githooks
chmod +x "${REPO_ROOT}/.githooks/commit-msg"

for path in "${SUBMODULES[@]}"; do
  if [[ -e "${REPO_ROOT}/${path}/.git" ]]; then
    git -C "${REPO_ROOT}/${path}" config core.hooksPath ../.githooks
  fi
done

echo "Configured core.hooksPath=.githooks (parent + workspace submodules)"
echo "Format: skills/commit-message-policy/references/summary-and-examples.md"
