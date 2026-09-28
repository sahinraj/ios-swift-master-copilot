#!/usr/bin/env bash
# Walks you through the benchmark prompts and saves each Copilot reply.
#
#   evals/collect.sh <run-name> [--redo]
#
# For each task it copies the prompt to your clipboard. Paste it into a new
# Copilot chat, copy the full reply, then press Enter here to save it as
# evals/results/<run-name>/<task-id>.md. Tasks already saved are skipped
# unless you pass --redo, so you can quit and pick up where you left off.
#
# Uses pbcopy/pbpaste (macOS). Set CLIP_COPY and CLIP_PASTE to use others.

set -euo pipefail

EVALS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIP_COPY="${CLIP_COPY:-pbcopy}"
CLIP_PASTE="${CLIP_PASTE:-pbpaste}"
INPUT="${COLLECT_INPUT:-/dev/tty}"

[[ $# -ge 1 && "$1" != -* ]] || { sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
run="$1"
redo=0
[[ "${2:-}" == "--redo" ]] && redo=1

command -v "${CLIP_COPY%% *}" >/dev/null 2>&1 || { echo "Clipboard tool '$CLIP_COPY' not found." >&2; exit 1; }
out_dir="$EVALS_DIR/results/$run"
mkdir -p "$out_dir"
exec 3<"$INPUT"

tasks=("$EVALS_DIR"/tasks/*/)
total=${#tasks[@]}
n=0
for task_dir in "${tasks[@]}"; do
  n=$((n + 1))
  id="$(basename "$task_dir")"
  dest="$out_dir/$id.md"
  if [[ -s "$dest" && $redo -eq 0 ]]; then
    printf '[%d/%d] %s already saved, skipping\n' "$n" "$total" "$id"
    continue
  fi

  prompt="$(cat "$task_dir/prompt.md")"
  printf '%s' "$prompt" | $CLIP_COPY
  printf '\n[%d/%d] %s\n' "$n" "$total" "$id"
  printf '  Prompt copied. Paste it into a NEW Copilot chat.\n'

  while true; do
    printf '  Copy the full reply, then press Enter (s = skip, q = quit): '
    read -r -u 3 answer || answer=q
    case "$answer" in
      q) printf '\nStopped. Run the same command again to continue.\n'; exit 0 ;;
      s) printf '  Skipped.\n'; break ;;
    esac
    reply="$($CLIP_PASTE)"
    if [[ -z "${reply//[[:space:]]/}" ]]; then
      printf '  Clipboard is empty. Copy the reply first.\n'
    elif [[ "$reply" == "$prompt" ]]; then
      printf '  Clipboard still holds the prompt. Copy the reply first.\n'
    else
      printf '%s\n' "$reply" >"$dest"
      printf '  Saved %s\n' "${dest#"$EVALS_DIR"/}"
      break
    fi
  done
done

printf '\nDone with %s. Score it with:\n  evals/score.sh %s\n' "$run" "${out_dir#"$PWD"/}"
