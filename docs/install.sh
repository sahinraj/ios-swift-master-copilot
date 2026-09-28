#!/usr/bin/env bash
# One-line bootstrap for iOS Swift Master.
#   curl -fsSL https://sahinraj.github.io/ios-swift-master-copilot/install.sh | bash
#   curl -fsSL https://sahinraj.github.io/ios-swift-master-copilot/install.sh | bash -s -- personal --claude
#   curl -fsSL https://sahinraj.github.io/ios-swift-master-copilot/install.sh | bash -s -- project ~/path/to/YourApp
# Clones (or updates) the repo into $IOS_SWIFT_MASTER_HOME, then runs ./install.sh with your arguments.

set -euo pipefail

REPO_URL="${IOS_SWIFT_MASTER_REPO:-https://github.com/sahinraj/ios-swift-master-copilot.git}"
DEST="${IOS_SWIFT_MASTER_HOME:-$HOME/.ios-swift-master}"

command -v git >/dev/null 2>&1 || { echo "  [error] git is required" >&2; exit 1; }

if [[ -d "$DEST/.git" ]]; then
  echo "  Updating $DEST"
  git -C "$DEST" pull --ff-only --quiet
elif [[ -e "$DEST" ]]; then
  echo "  [error] $DEST exists and is not a git checkout. Set IOS_SWIFT_MASTER_HOME to another folder." >&2
  exit 1
else
  echo "  Cloning into $DEST"
  git clone --depth 1 --quiet "$REPO_URL" "$DEST"
fi

cd "$DEST"
./install.sh verify
if [[ $# -eq 0 ]]; then
  set -- personal
fi
./install.sh "$@"
