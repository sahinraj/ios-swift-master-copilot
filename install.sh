#!/usr/bin/env bash
# ios-swift-master installer for GitHub Copilot (VS Code, Copilot CLI, Copilot for Xcode)
# Safe to run repeatedly. Run ./install.sh help for usage.

set -euo pipefail

VERSION="1.0.0 (Swift 6.4, iOS 27, Xcode 27)"
SKILL_NAME="ios-swift-master"
AGENT_FILE="ios-swift-master.agent.md"
BLOCK_START="<!-- ios-swift-master:start -->"
BLOCK_END="<!-- ios-swift-master:end -->"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_SKILL="$SCRIPT_DIR/skills/$SKILL_NAME"
SRC_AGENT="$SCRIPT_DIR/agents/$AGENT_FILE"
SRC_INSTRUCTIONS="$SCRIPT_DIR/instructions/swift.instructions.md"
SRC_BLOCK="$SCRIPT_DIR/instructions/copilot-instructions-block.md"

COPY_MODE=0
ALSO_CLAUDE=0
FORCE=0

info()  { printf '  %s\n' "$*"; }
ok()    { printf '  [ok] %s\n' "$*"; }
warn()  { printf '  [warn] %s\n' "$*" >&2; }
fail()  { printf '  [error] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<EOF
ios-swift-master installer $VERSION

Usage:
  ./install.sh personal [--copy] [--claude] [--force]
      Install for all projects on this Mac.
        Skill  -> ~/.copilot/skills/$SKILL_NAME   (symlink by default)
        Agent  -> ~/.copilot/agents/$AGENT_FILE
      --copy    copy files instead of symlinking (use if a tool cannot follow symlinks)
      --claude  also link the skill into ~/.claude/skills and the agent into ~/.claude/agents
      --force   replace existing non-managed files (a timestamped backup is kept)

  ./install.sh project <path-to-repo> [--force]
      Install into one repository (required for Copilot for Xcode). Files are copied so they can be committed.
        .github/skills/$SKILL_NAME/
        .github/agents/$AGENT_FILE
        .github/instructions/swift.instructions.md
        .github/copilot-instructions.md   (managed block appended or updated, your content is kept)

  ./install.sh uninstall-personal
  ./install.sh uninstall-project <path-to-repo>
  ./install.sh verify [<path-to-repo>]
  ./install.sh help
EOF
}

check_sources() {
  [[ -f "$SRC_SKILL/SKILL.md" ]] || fail "Missing $SRC_SKILL/SKILL.md. Run this script from the unzipped package folder."
  [[ -f "$SRC_AGENT" ]] || fail "Missing $SRC_AGENT"
  [[ -f "$SRC_INSTRUCTIONS" ]] || fail "Missing $SRC_INSTRUCTIONS"
  local name
  name="$(awk -F': *' '/^name:/{print $2; exit}' "$SRC_SKILL/SKILL.md" | tr -d "\"'")"
  [[ "$name" == "$SKILL_NAME" ]] || fail "SKILL.md name '$name' does not match folder '$SKILL_NAME'"
}

backup() {
  local target="$1"
  local stamp
  stamp="$(date +%Y%m%d-%H%M%S)"
  mv "$target" "$target.backup-$stamp"
  warn "Existing $target moved to $target.backup-$stamp"
}

# place <source> <destination> <link|copy>
place() {
  local src="$1" dest="$2" mode="$3"
  mkdir -p "$(dirname "$dest")"

  if [[ -L "$dest" ]]; then
    local current
    current="$(readlink "$dest")"
    if [[ "$mode" == "link" && "$current" == "$src" ]]; then
      ok "Already linked: $dest"
      return
    fi
    rm "$dest"
  elif [[ -e "$dest" ]]; then
    if [[ -e "$dest/.ios-swift-master-managed" ]] || { [[ -f "$dest" ]] && grep -qE "ios-swift-master|iOS Swift Master" "$dest"; } || [[ "$FORCE" == 1 ]]; then
      if [[ "$FORCE" == 1 && ! -e "$dest/.ios-swift-master-managed" ]]; then backup "$dest"; else rm -rf "$dest"; fi
    else
      fail "$dest already exists and was not installed by this script. Re-run with --force to back it up and replace it."
    fi
  fi

  if [[ "$mode" == "link" ]]; then
    ln -s "$src" "$dest"
    ok "Linked $dest"
  else
    cp -R "$src" "$dest"
    [[ -d "$dest" ]] && printf '%s\n' "$VERSION" > "$dest/.ios-swift-master-managed"
    ok "Copied $dest"
  fi
}

trim_trailing_blank() {
  awk '{ lines[NR] = $0 } END { n = NR; while (n > 0 && lines[n] ~ /^[[:space:]]*$/) n--; for (i = 1; i <= n; i++) print lines[i] }' "$1"
}

merge_block() {
  local file="$1"
  mkdir -p "$(dirname "$file")"
  touch "$file"
  local tmp
  tmp="$(mktemp)"
  awk -v s="$BLOCK_START" -v e="$BLOCK_END" '
    $0 == s {skip=1; next}
    $0 == e {skip=0; next}
    !skip {print}
  ' "$file" > "$tmp"
  trim_trailing_blank "$tmp" > "$tmp.trim"
  if [[ -s "$tmp.trim" ]]; then
    { cat "$tmp.trim"; printf '\n'; cat "$SRC_BLOCK"; } > "$file"
  else
    cat "$SRC_BLOCK" > "$file"
  fi
  rm -f "$tmp" "$tmp.trim"
  ok "Updated managed block in $file"
}

remove_block() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  local tmp
  tmp="$(mktemp)"
  awk -v s="$BLOCK_START" -v e="$BLOCK_END" '
    $0 == s {skip=1; next}
    $0 == e {skip=0; next}
    !skip {print}
  ' "$file" > "$tmp"
  if [[ -z "$(tr -d '[:space:]' < "$tmp")" ]]; then
    rm -f "$file"
    ok "Removed $file (it only contained the managed block)"
  else
    trim_trailing_blank "$tmp" > "$file"
    ok "Removed managed block from $file"
  fi
  rm -f "$tmp"
}

install_personal() {
  check_sources
  local mode="link"
  [[ "$COPY_MODE" == 1 ]] && mode="copy"
  echo "Installing personal skill and agent ($mode mode)"
  place "$SRC_SKILL" "$HOME/.copilot/skills/$SKILL_NAME" "$mode"
  place "$SRC_AGENT" "$HOME/.copilot/agents/$AGENT_FILE" "$mode"
  if [[ "$ALSO_CLAUDE" == 1 ]]; then
    place "$SRC_SKILL" "$HOME/.claude/skills/$SKILL_NAME" "$mode"
    place "$SRC_AGENT" "$HOME/.claude/agents/$AGENT_FILE" "$mode"
  fi
  echo
  info "Next: restart VS Code (or run /skills reload in Copilot CLI)."
  info "Copilot for Xcode needs a project install: ./install.sh project /path/to/repo"
}

install_project() {
  local repo="${1:-}"
  [[ -n "$repo" ]] || fail "Provide a repository path: ./install.sh project /path/to/repo"
  [[ -d "$repo" ]] || fail "Not a directory: $repo"
  check_sources
  repo="$(cd "$repo" && pwd)"
  echo "Installing into $repo/.github"
  place "$SRC_SKILL" "$repo/.github/skills/$SKILL_NAME" copy
  place "$SRC_AGENT" "$repo/.github/agents/$AGENT_FILE" copy
  place "$SRC_INSTRUCTIONS" "$repo/.github/instructions/swift.instructions.md" copy
  merge_block "$repo/.github/copilot-instructions.md"
  echo
  info "Next: commit .github/ so teammates and Copilot cloud agent get it."
  info "In Xcode: reopen the project in Copilot for Xcode and pick 'iOS Swift Master' in the agent menu."
}

uninstall_personal() {
  echo "Removing personal install"
  for p in "$HOME/.copilot/skills/$SKILL_NAME" "$HOME/.copilot/agents/$AGENT_FILE" \
           "$HOME/.claude/skills/$SKILL_NAME" "$HOME/.claude/agents/$AGENT_FILE"; do
    if [[ -L "$p" || -e "$p/.ios-swift-master-managed" ]]; then rm -rf "$p"; ok "Removed $p"
    elif [[ -f "$p" ]] && grep -q "iOS Swift Master" "$p"; then rm -f "$p"; ok "Removed $p"
    elif [[ -e "$p" ]]; then warn "Skipped $p (not managed by this script)"
    fi
  done
}

uninstall_project() {
  local repo="${1:-}"
  [[ -d "$repo" ]] || fail "Provide a repository path: ./install.sh uninstall-project /path/to/repo"
  repo="$(cd "$repo" && pwd)"
  echo "Removing project install from $repo/.github"
  local skill="$repo/.github/skills/$SKILL_NAME"
  [[ -e "$skill/.ios-swift-master-managed" ]] && { rm -rf "$skill"; ok "Removed $skill"; }
  local agent="$repo/.github/agents/$AGENT_FILE"
  [[ -f "$agent" ]] && grep -q "iOS Swift Master" "$agent" && { rm -f "$agent"; ok "Removed $agent"; }
  local instr="$repo/.github/instructions/swift.instructions.md"
  [[ -f "$instr" ]] && grep -q "ios-swift-master" "$instr" && { rm -f "$instr"; ok "Removed $instr"; }
  remove_block "$repo/.github/copilot-instructions.md"
}

verify() {
  local repo="${1:-}"
  echo "ios-swift-master $VERSION"
  check_sources && ok "Package is valid (name matches folder, all files present)"
  local refs
  refs="$(find "$SRC_SKILL/references" -name '*.md' | wc -l | tr -d ' ')"
  ok "$refs reference files"
  for p in "$HOME/.copilot/skills/$SKILL_NAME/SKILL.md" "$HOME/.copilot/agents/$AGENT_FILE" \
           "$HOME/.claude/skills/$SKILL_NAME/SKILL.md" "$HOME/.claude/agents/$AGENT_FILE"; do
    [[ -e "$p" ]] && ok "Found $p" || info "Not installed: $p"
  done
  if [[ -n "$repo" ]]; then
    for p in "$repo/.github/skills/$SKILL_NAME/SKILL.md" "$repo/.github/agents/$AGENT_FILE" \
             "$repo/.github/instructions/swift.instructions.md" "$repo/.github/copilot-instructions.md"; do
      [[ -e "$p" ]] && ok "Found $p" || info "Not installed: $p"
    done
  fi
}

cmd="${1:-help}"
shift || true
ARGS=()
for arg in "$@"; do
  case "$arg" in
    --copy) COPY_MODE=1 ;;
    --claude) ALSO_CLAUDE=1 ;;
    --force) FORCE=1 ;;
    *) ARGS+=("$arg") ;;
  esac
done
set -- "${ARGS[@]+"${ARGS[@]}"}"

case "$cmd" in
  personal) install_personal ;;
  project) install_project "${1:-}" ;;
  uninstall-personal) uninstall_personal ;;
  uninstall-project) uninstall_project "${1:-}" ;;
  verify) verify "${1:-}" ;;
  help|-h|--help) usage ;;
  *) usage; exit 1 ;;
esac
