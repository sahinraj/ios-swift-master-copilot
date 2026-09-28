# Benchmark

A small, honest way to check whether the skill actually changes what your coding agent writes.

Each folder in `tasks/` has:

- `prompt.md`: the exact prompt to paste into the agent.
- `checks.txt`: what a good answer's code should contain (`+`) and must avoid (`-`), as extended regexes with a tab and a reason after each.

The scorer only looks inside fenced code blocks, so an answer that explains "don't use `ObservableObject` anymore" isn't penalized for naming it.

## Running it

1. Start a fresh chat **without** the skill (uninstall it or use a plain agent). Paste each `prompt.md` and save the full reply as `evals/results/baseline/<task-id>.md`.
2. Install the skill, start a fresh chat, pick the **iOS Swift Master** agent (or prefix with `/ios-swift-master`) and do the same into `evals/results/with-skill/`.
3. Score both:

```bash
evals/score.sh evals/results/baseline evals/results/with-skill
VERBOSE=1 evals/score.sh evals/results/with-skill   # print each missed check
```

You get a Markdown table you can paste straight into a README, a PR or a post. Use the same model for both runs and note which one you used, so the comparison is fair.

## Adding a task

Create `tasks/NN-short-name/` with `prompt.md` and `checks.txt`. Keep checks about things that are clearly right or wrong on current SDKs, not style. Then run `bash tests/evals_test.sh` to check the format.

Pattern checks are a floor, not a full grade. They catch outdated APIs and missing essentials, but they don't compile the code. Read the answers too.
