#!/usr/bin/env bash
# Runs docs/install.sh against this local checkout instead of GitHub.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

export HOME="$TEST_ROOT/home"
export IOS_SWIFT_MASTER_REPO="$ROOT"
export IOS_SWIFT_MASTER_HOME="$TEST_ROOT/checkout"
mkdir -p "$HOME"

bash "$ROOT/docs/install.sh" >/dev/null
[[ -L "$HOME/.copilot/skills/ios-swift-master" ]] || fail "skill not linked"
[[ -L "$HOME/.copilot/agents/ios-swift-master.agent.md" ]] || fail "agent not linked"

# Second run updates in place and stays idempotent.
bash "$ROOT/docs/install.sh" personal >/dev/null

mkdir -p "$TEST_ROOT/blocked"
IOS_SWIFT_MASTER_HOME="$TEST_ROOT/blocked" bash "$ROOT/docs/install.sh" >/dev/null 2>&1 \
  && fail "expected refusal for a non-git destination"

printf 'bootstrap tests passed\n'
