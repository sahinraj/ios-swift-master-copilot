#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_file() {
  [[ -f "$1" ]] || fail "missing file: $1"
}

assert_absent() {
  [[ ! -e "$1" && ! -L "$1" ]] || fail "expected path to be absent: $1"
}

HOME="$TEST_ROOT/home"
export HOME
mkdir -p "$HOME"

"$ROOT/install.sh" verify >/dev/null

project="$TEST_ROOT/sample-project"
mkdir -p "$project/.github"
printf '# Existing project guidance\n' > "$project/.github/copilot-instructions.md"

"$ROOT/install.sh" project "$project" >/dev/null
"$ROOT/install.sh" project "$project" >/dev/null

assert_file "$project/.github/skills/ios-swift-master/SKILL.md"
assert_file "$project/.github/agents/ios-swift-master.agent.md"
assert_file "$project/.github/instructions/swift.instructions.md"

block_count="$(grep -c '<!-- ios-swift-master:start -->' "$project/.github/copilot-instructions.md")"
[[ "$block_count" == 1 ]] || fail "managed block should occur once, found $block_count"
grep -q '# Existing project guidance' "$project/.github/copilot-instructions.md" || fail "existing project guidance was not preserved"

"$ROOT/install.sh" uninstall-project "$project" >/dev/null
assert_absent "$project/.github/skills/ios-swift-master"
assert_absent "$project/.github/agents/ios-swift-master.agent.md"
assert_absent "$project/.github/instructions/swift.instructions.md"
grep -q '# Existing project guidance' "$project/.github/copilot-instructions.md" || fail "uninstall removed existing project guidance"

"$ROOT/install.sh" personal --copy --claude >/dev/null
assert_file "$HOME/.copilot/skills/ios-swift-master/SKILL.md"
assert_file "$HOME/.copilot/agents/ios-swift-master.agent.md"
assert_file "$HOME/.claude/skills/ios-swift-master/SKILL.md"
assert_file "$HOME/.claude/agents/ios-swift-master.agent.md"

"$ROOT/install.sh" uninstall-personal >/dev/null
assert_absent "$HOME/.copilot/skills/ios-swift-master"
assert_absent "$HOME/.copilot/agents/ios-swift-master.agent.md"
assert_absent "$HOME/.claude/skills/ios-swift-master"
assert_absent "$HOME/.claude/agents/ios-swift-master.agent.md"

printf 'All installer tests passed.\n'

