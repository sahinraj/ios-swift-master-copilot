#!/usr/bin/env bash
# Checks the eval task format and the scorer against known good and bad answers.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURES="$ROOT/tests/fixtures/evals"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

for task in "$ROOT"/evals/tasks/*/; do
  [[ -s "$task/prompt.md" ]] || fail "missing prompt: $task"
  [[ -s "$task/checks.txt" ]] || fail "missing checks: $task"
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    [[ "$line" =~ ^[+-]\ [^$'\t']+$'\t'.+ ]] || fail "bad check line in $task: $line"
  done <"$task/checks.txt"
done

out="$("$ROOT/evals/score.sh" "$FIXTURES/bad" "$FIXTURES/good")"
grep -q '| 01-observable-migration | 0/5 | 5/5 |' <<<"$out" || fail "unexpected scores: $out"
grep -q '| 04-list-identity | n/a | 2/2 |' <<<"$out" || fail "unexpected scores: $out"

printf 'eval tests passed\n'
