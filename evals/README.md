# Benchmark

A small, honest way to check whether the skill actually changes what your coding agent writes.

Each folder in `tasks/` has:

- `prompt.md`: the exact prompt to paste into the agent.
- `checks.txt`: what a good answer's code should contain (`+`) and must avoid (`-`), as extended regexes with a tab and a reason after each.

The scorer only looks inside fenced code blocks, so an answer that explains "don't use `ObservableObject` anymore" isn't penalized for naming it.

## Running it

The collector copies each prompt to your clipboard and saves each reply for you (macOS):

```bash
evals/collect.sh baseline      # run with the skill uninstalled
evals/collect.sh with-skill    # run with the skill installed and the iOS Swift Master agent picked
evals/score.sh evals/results/baseline evals/results/with-skill
```

For every task: paste the prompt into a **new** Copilot chat, copy the full reply, press Enter. It catches an empty clipboard or a clipboard that still holds the prompt, skips tasks already saved, and `q` stops so you can pick up later. Use `--redo` to redo a run.

To take the skill out for the baseline and put it back after:

```bash
mv ~/.copilot/skills/ios-swift-master /tmp/ism-off && mv ~/.copilot/agents/ios-swift-master.agent.md /tmp/ism-agent-off
mv /tmp/ism-off ~/.copilot/skills/ios-swift-master && mv /tmp/ism-agent-off ~/.copilot/agents/ios-swift-master.agent.md
```

Restart VS Code after each move. Use the same model for both runs and note which one, so the comparison is fair.

`VERBOSE=1 evals/score.sh evals/results/with-skill` prints each missed check. The output is a Markdown table you can paste into a README, a PR or a post.

## Adding a task

Create `tasks/NN-short-name/` with `prompt.md` and `checks.txt`. Keep checks about things that are clearly right or wrong on current SDKs, not style. Then run `bash tests/evals_test.sh` to check the format.

Pattern checks are a floor, not a full grade. They catch outdated APIs and missing essentials, but they don't compile the code. Read the answers too.
