# iOS Swift Master for GitHub Copilot

A master skill, custom agent and instruction set that makes GitHub Copilot an expert in Swift 6.4, SwiftUI and SwiftData for the 2027 SDKs (iOS 27, Xcode 27). It works in VS Code, Copilot CLI, Copilot cloud agent, Copilot code review and Copilot for Xcode, and the same skill also works in Claude Code.

Version 1.0.0, built September 2026 against Swift 6.4 and the WWDC26 SwiftUI and SwiftData releases.

This is an independent community project and is not affiliated with or endorsed by Apple, GitHub, Microsoft, or Anthropic.

[Website](https://sahinraj.github.io/ios-swift-master-copilot/) · [Latest release](https://github.com/sahinraj/ios-swift-master-copilot/releases/latest) · [Report an issue](https://github.com/sahinraj/ios-swift-master-copilot/issues)

## Quick start

Clone the repository, validate the package, and install it for your user account:

```bash
git clone https://github.com/sahinraj/ios-swift-master-copilot.git
cd ios-swift-master-copilot
./install.sh verify
./install.sh personal
```

For Copilot for Xcode or a shared team repository, use a project install instead:

```bash
./install.sh project ~/path/to/YourApp
```

## What's inside

```
ios-swift-master-copilot/
├── install.sh                                  Installer (personal, project, uninstall, verify)
├── skills/ios-swift-master/
│   ├── SKILL.md                                Entry point: routing table and non-negotiable rules
│   └── references/                             Loaded on demand, only when a task needs them
│       ├── swift-language-guide.md             Every chapter of the TSPL Language Guide
│       ├── swift-language-reference.md         Grammar, attributes, declarations, patterns, availability
│       ├── swift-whats-new-6x.md               Swift 6.0 to 6.4, migration playbook, feature flags
│       ├── swift-concurrency.md                Actors, isolation, Sendable, tasks, cancellation, errors table
│       ├── swiftui-dataflow-architecture.md    @State, @Observable, @Environment, stores
│       ├── swiftui-views-layout-navigation.md  Layout, lists, navigation, toolbars, animation, previews
│       ├── swiftui-performance-identity.md     Identity, invalidation, slow views
│       ├── swiftui-ios26-ios27-new.md          Liquid Glass plus every 2027 SwiftUI change
│       ├── swiftdata.md                        Models, queries, migrations, CloudKit, observers
│       ├── testing.md                          Swift Testing, XCTest interop, UI tests
│       ├── app-architecture.md                 Layers, SPM modules, DI, errors, logging
│       ├── platform-integration.md             UIKit interop, background, widgets, App Intents, Foundation Models
│       ├── accessibility-localization.md       VoiceOver, Dynamic Type, String Catalogs, FormatStyle
│       ├── networking-security-privacy.md      URLSession, auth, Keychain, ATS, privacy manifests
│       ├── performance-debugging.md            Crashes, hangs, leaks, Instruments, build times
│       ├── enterprise-ipad.md                  Offline-first, MDM, audit trails, time zones
│       └── code-review-checklist.md            Severity-based review checklist
├── agents/ios-swift-master.agent.md            "iOS Swift Master" custom agent
└── instructions/
    ├── swift.instructions.md                   Always-on rules for **/*.swift
    └── copilot-instructions-block.md           Block merged into .github/copilot-instructions.md
```

### How the pieces work together

| Piece | When Copilot uses it | Works in |
|---|---|---|
| Skill (`SKILL.md` + references) | Loaded automatically when your prompt matches the description, or on demand with `/ios-swift-master` | VS Code, Copilot CLI, cloud agent, code review, Claude Code |
| Custom agent | When you pick "iOS Swift Master" in the agent dropdown | VS Code, Copilot CLI, Copilot for Xcode |
| `swift.instructions.md` | Every request that touches a `.swift` file | VS Code, Copilot for Xcode |
| `copilot-instructions.md` block | Every request in the repo | VS Code, Copilot for Xcode, GitHub.com |

Copilot for Xcode supports custom agents and instruction files but does not document skills support yet. The agent is written to read the skill's reference files directly from `.github/skills/`, which is why a **project install** is the way to use this in Xcode.

## Requirements

- macOS with bash (default shell on macOS is fine; the script runs with `/usr/bin/env bash`).
- One or more of:
  - VS Code with GitHub Copilot Chat (current release)
  - GitHub Copilot CLI
  - Copilot for Xcode 0.48.0 or later (custom agents are generally available from 0.48.0)
- A Copilot plan that includes agent mode.

## Step 1: Put the package somewhere permanent

The personal install uses symlinks back to this folder, so don't leave it in Downloads.

```bash
mkdir -p ~/Developer
mv ~/Downloads/ios-swift-master-copilot.zip ~/Developer/
cd ~/Developer
unzip -o ios-swift-master-copilot.zip
cd ios-swift-master-copilot
chmod +x install.sh
./install.sh verify
```

`verify` should report the package as valid with 17 reference files.

## Step 2A: Personal install (VS Code and Copilot CLI, all projects)

```bash
./install.sh personal
```

This creates:
- `~/.copilot/skills/ios-swift-master` (symlink)
- `~/.copilot/agents/ios-swift-master.agent.md` (symlink)

Options:
- `--claude` also links into `~/.claude/skills` and `~/.claude/agents` so Claude Code picks up the same skill.
- `--copy` copies instead of symlinking, if a tool will not follow symlinks.
- `--force` replaces an existing folder you created yourself (the old one is backed up with a timestamp).

Because it's a symlink, editing files in `~/Developer/ios-swift-master-copilot` updates every tool at once.

### Verify in VS Code
1. Restart VS Code.
2. Open the Chat view and switch to Agent mode.
3. Type `/skills` and confirm `ios-swift-master` is listed.
4. Type `/agents` (or open the agent dropdown) and confirm "iOS Swift Master" is listed.
5. If something is missing, right-click in the Chat view, select **Diagnostics**, and look for load errors.

### Verify in Copilot CLI
```text
copilot
/skills reload
/skills info ios-swift-master
/agent
```

## Step 2B: Project install (required for Copilot for Xcode, recommended for teams)

```bash
./install.sh project ~/path/to/YourApp
```

This copies into the repo:
- `.github/skills/ios-swift-master/`
- `.github/agents/ios-swift-master.agent.md`
- `.github/instructions/swift.instructions.md`
- `.github/copilot-instructions.md` (a marked block is appended; your existing content is preserved)

Files are copied rather than linked, so they can be committed and so Xcode's sandbox can read them.

### Use it in Copilot for Xcode
1. Update Copilot for Xcode to 0.48.0 or later (menu bar icon, Check for Updates).
2. Open the project folder in Xcode. Make sure Copilot for Xcode has permission to read the workspace.
3. Open Copilot Chat, switch to **Agent** mode.
4. Open the agent dropdown at the bottom of the chat and pick **iOS Swift Master**.
5. If it does not appear, open `.github/agents/ios-swift-master.agent.md` in Xcode once, then check the dropdown again. This is a known Copilot for Xcode bug.
6. Optional: in Copilot for Xcode **Settings > Advanced > Custom Instructions**, paste the contents of `instructions/swift.instructions.md` (without the frontmatter) to apply the rules in every workspace.

### Commit for your team
```bash
cd ~/path/to/YourApp
git add .github
git commit -m "Add iOS Swift Master Copilot skill, agent and instructions"
```
Teammates get the agent in VS Code and Xcode, and Copilot cloud agent and Copilot code review pick up the skill from `.github/skills`.

## Step 3: Try it

Good first prompts:
- `/ios-swift-master review ScheduleView.swift for performance and identity problems`
- `Migrate this target to Swift 6 language mode with MainActor default isolation. Plan first.`
- `Add drag to reorder to this LazyVGrid on iOS 27 with a fallback for iOS 18.`
- `Write Swift Testing tests for FuelCalculator including parameterized edge cases.`
- `Convert this ObservableObject view model to @Observable and fix the @State init error from Xcode 27.`
- `Add a VersionedSchema migration that makes tripNumber unique and dedupes existing rows.`
- With the agent selected: `Review this PR diff using the code review checklist.`

## Optional: add Apple's official Xcode 27 skills

Xcode 27 ships two Apple skills (SwiftUI Specialist and What's New in SwiftUI). They complement this skill well.

```bash
xcrun agent skills export --help      # see the available options first
```

Export them, then place each exported skill folder in `~/.copilot/skills/` (and `~/.claude/skills/` if you use Claude Code). Each folder's name must match the `name:` in its `SKILL.md`.

## Updating

```bash
cd ~/Developer/ios-swift-master-copilot
# replace files with a newer version or edit references directly
./install.sh personal                  # re-links, safe to repeat
./install.sh project ~/path/to/YourApp # re-copies, updates the managed block
```

## Uninstalling

```bash
./install.sh uninstall-personal
./install.sh uninstall-project ~/path/to/YourApp
```
Only files created by this installer are removed. Your own content in `copilot-instructions.md` stays.

## Customizing

- **Tighten the triggers**: edit `description` in `SKILL.md` (max 1024 characters). The skill loads based on this text.
- **Hide from the slash menu** but keep auto-loading: add `user-invocable: false` to the `SKILL.md` frontmatter.
- **Manual only**: add `disable-model-invocation: true`.
- **Restrict agent tools**: add a `tools:` list to the agent frontmatter (for example a read-only review agent). Leaving it out gives the agent all available tools.
- **Pin a model**: add `model: ['<model name from your picker>']` to the agent frontmatter. An array tries each model in order.
- **Team-specific rules**: add a new file under `references/` and a row in the `SKILL.md` routing table.

## Troubleshooting

| Problem | Fix |
|---|---|
| Skill not listed in VS Code | Folder name and `name:` must both be `ios-swift-master`, lowercase with hyphens. Run `./install.sh verify`. Check Chat Diagnostics. |
| Skill listed but never used | Invoke with `/ios-swift-master`, or mention Swift, SwiftUI or SwiftData explicitly. Make sure you are in Agent mode. |
| Agent missing in Xcode | Update Copilot for Xcode, confirm `.github/agents/` exists in the opened folder, open the agent file once in Xcode. |
| Xcode agent ignores references | The workspace root must be the repo root that contains `.github/`. Grant Copilot for Xcode folder access. |
| Symlinked skill not found | Use `./install.sh personal --copy`. |
| "already exists and was not installed by this script" | Re-run with `--force`; your folder is backed up. |
| VS Code Agent Host sessions do not see user agents | Agent Host reads `~/.copilot/agents` and `~/.copilot/skills`, which is exactly where this installer puts them. Restart the session. |

## Sources

- The Swift Programming Language: https://docs.swift.org/latest/documentation/the-swift-programming-language/
- Swift docs: https://docs.swift.org/latest/documentation/
- SwiftUI: https://developer.apple.com/documentation/swiftui
- SwiftData: https://developer.apple.com/documentation/swiftdata
- WWDC26 What's new in SwiftUI: https://developer.apple.com/videos/play/wwdc2026/269/
- WWDC26 What's new in SwiftData: https://developer.apple.com/videos/play/wwdc2026/274/
- Swift 6.3 release: https://www.swift.org/blog/swift-6.3-released/
- VS Code Agent Skills: https://code.visualstudio.com/docs/agent-customization/agent-skills
- VS Code custom agents: https://code.visualstudio.com/docs/agent-customization/custom-agents
- Copilot CLI skills: https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-skills
- Copilot for Xcode changelog: https://github.com/github/CopilotForXcode/blob/main/CHANGELOG.md

The reference files are original condensed guidance written from these sources. Verify exact API signatures in Xcode Quick Help when something new does not compile, since some 2027 APIs may still shift between SDK releases.

## Contributing and license

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for the validation steps and source requirements. This project is available under the [MIT License](LICENSE).
