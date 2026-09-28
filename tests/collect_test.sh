#!/usr/bin/env bash
# Drives evals/collect.sh with a fake clipboard and scripted key presses.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

mkdir -p "$WORK/evals"
cp "$ROOT/evals/collect.sh" "$WORK/evals/"
mkdir -p "$WORK/evals/tasks/01-a" "$WORK/evals/tasks/02-b"
printf 'prompt a\n' >"$WORK/evals/tasks/01-a/prompt.md"
printf 'prompt b\n' >"$WORK/evals/tasks/02-b/prompt.md"

# Fake clipboard: copy writes a file; paste returns queued replies in order.
cat >"$WORK/copy" <<SH
#!/usr/bin/env bash
cat >"$WORK/clip"
SH
cat >"$WORK/paste" <<SH
#!/usr/bin/env bash
n=\$(( \$(cat "$WORK/n" 2>/dev/null || echo 0) + 1 )); echo \$n >"$WORK/n"
case \$n in
  1) cat "$WORK/clip" ;;   # user forgot to copy the reply
  2) printf 'reply a\n' ;;
  *) printf '   \n' ;;      # empty clipboard
esac
SH
chmod +x "$WORK/copy" "$WORK/paste"

# Enter (stale prompt), Enter (saved), Enter (empty), s (skip)
printf '\n\n\ns\n' >"$WORK/keys"
out="$(cd "$WORK" && CLIP_COPY="$WORK/copy" CLIP_PASTE="$WORK/paste" COLLECT_INPUT="$WORK/keys" evals/collect.sh run1)"

grep -q 'still holds the prompt' <<<"$out" || fail "stale prompt not caught"
grep -q 'Clipboard is empty' <<<"$out" || fail "empty clipboard not caught"
[[ "$(cat "$WORK/evals/results/run1/01-a.md")" == "reply a" ]] || fail "reply not saved"
[[ ! -e "$WORK/evals/results/run1/02-b.md" ]] || fail "skipped task was saved"

# Rerun skips saved tasks; q quits cleanly.
printf 'q\n' >"$WORK/keys"
out="$(cd "$WORK" && CLIP_COPY="$WORK/copy" CLIP_PASTE="$WORK/paste" COLLECT_INPUT="$WORK/keys" evals/collect.sh run1)"
grep -q '01-a already saved' <<<"$out" || fail "saved task not skipped"
grep -q 'Stopped' <<<"$out" || fail "quit not handled"

printf 'collect tests passed\n'
