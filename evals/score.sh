#!/usr/bin/env bash
# Scores saved model answers against each task's checks.
#
#   evals/score.sh <run-dir> [<run-dir> ...]
#
# A run dir holds one answer per task, named <task-id>.md (for example
# results/baseline/01-observable-migration.md). Only fenced code blocks are
# scored, so prose that mentions an old API does not count against an answer.
#
# checks.txt format, one check per line, tab before the reason:
#   + <extended regex>	<reason>    must appear
#   - <extended regex>	<reason>    must not appear

set -euo pipefail

EVALS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TASKS_DIR="$EVALS_DIR/tasks"
VERBOSE="${VERBOSE:-0}"

[[ $# -ge 1 ]] || { sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

code_only() {
  awk '/^[[:space:]]*```/{inside=!inside; next} inside' "$1"
}

# score_task <answer-file> <checks-file> -> prints "passed total"
score_task() {
  local answer="$1" checks="$2" code passed=0 total=0 sign pattern reason hit
  code="$(code_only "$answer")"
  while IFS=$'\t' read -r rule reason || [[ -n "$rule" ]]; do
    [[ -z "$rule" || "$rule" == \#* ]] && continue
    sign="${rule:0:1}"
    pattern="${rule:2}"
    total=$((total + 1))
    if grep -Eq -- "$pattern" <<<"$code"; then hit=1; else hit=0; fi
    if [[ ( "$sign" == "+" && $hit -eq 1 ) || ( "$sign" == "-" && $hit -eq 0 ) ]]; then
      passed=$((passed + 1))
    elif [[ "$VERBOSE" == "1" ]]; then
      printf '    miss: %s\n' "$reason" >&2
    fi
  done <"$checks"
  printf '%s %s\n' "$passed" "$total"
}

header="| Task |"
divider="|---|"
for run in "$@"; do
  header+=" $(basename "$run") |"
  divider+="---|"
done
printf '%s\n%s\n' "$header" "$divider"

declare -a sum_passed sum_total
for task_dir in "$TASKS_DIR"/*/; do
  id="$(basename "$task_dir")"
  row="| $id |"
  i=0
  for run in "$@"; do
    answer="$run/$id.md"
    if [[ -f "$answer" ]]; then
      [[ "$VERBOSE" == "1" ]] && printf '  %s / %s\n' "$(basename "$run")" "$id" >&2
      read -r p t < <(score_task "$answer" "$task_dir/checks.txt")
      row+=" $p/$t |"
      sum_passed[i]=$(( ${sum_passed[i]:-0} + p ))
      sum_total[i]=$(( ${sum_total[i]:-0} + t ))
    else
      row+=" n/a |"
    fi
    i=$((i + 1))
  done
  printf '%s\n' "$row"
done

row="| **Total** |"
for i in $(seq 0 $(($# - 1))); do
  p=${sum_passed[i]:-0}; t=${sum_total[i]:-0}
  pct=0; [[ $t -gt 0 ]] && pct=$(( 100 * p / t ))
  row+=" **$p/$t ($pct%)** |"
done
printf '%s\n' "$row"
