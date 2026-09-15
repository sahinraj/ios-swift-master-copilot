# Swift / SwiftUI / SwiftData Code Review Checklist

## How to review
1. Understand intent: read the PR description, linked ticket, and tests first.
2. Check the project settings that change the rules (deployment target, Swift language mode, default actor isolation).
3. Review in passes: correctness, concurrency, data, UI and performance, accessibility and localization, security, tests, style.
4. Report findings grouped by severity. For each: file and line, the problem, why it matters, a concrete fix (code if short).

Severity labels:
- **Blocker**: crash, data loss, data race, security or privacy issue, broken migration, wrong safety-relevant output.
- **Major**: incorrect behavior in edge cases, main-thread hangs, leaks, missing error handling, accessibility failure on primary flows.
- **Minor**: performance inefficiency, unclear naming, missing tests for non-critical paths.
- **Nit**: style and formatting (only if the linter does not catch it).

Keep praise short and specific. Do not rewrite the whole PR; suggest the smallest change that fixes each issue.

## Correctness
- [ ] No `!`, `try!`, `as!` in production paths without proven invariants.
- [ ] Optionals handled meaningfully (no `?? ""` hiding real absence).
- [ ] `switch` over enums exhaustive; `@unknown default` for SDK enums.
- [ ] Integer overflow, division by zero, empty collections, off-by-one checked.
- [ ] Dates: explicit time zones and calendars; no string date math.
- [ ] Money and precise quantities use `Decimal`; units explicit.
- [ ] Errors are handled, mapped, or propagated; no empty `catch`.
- [ ] `CancellationError` not shown to users.
- [ ] Availability checks around new APIs.

## Concurrency
- [ ] UI state mutated only on MainActor.
- [ ] No `DispatchQueue`/completion handlers in new code without reason.
- [ ] Heavy work in `@concurrent` functions or background actors, not on MainActor.
- [ ] No `Task.detached` without justification.
- [ ] Unstructured tasks handle errors and are cancelled when their owner goes away.
- [ ] `.task`/`.task(id:)` used instead of `onAppear` + `Task`.
- [ ] Actor reentrancy considered around every `await` that precedes a state write.
- [ ] No `@unchecked Sendable`, `nonisolated(unsafe)`, `@preconcurrency` without a comment proving safety.
- [ ] No semaphores or blocking waits on async work.
- [ ] Continuations resumed exactly once on every path.
- [ ] SwiftData models/contexts not crossing actors.

## SwiftData / persistence
- [ ] Schema changes come with a new `VersionedSchema` and migration stage.
- [ ] Migration tested with existing data.
- [ ] Unique constraints handled (and not used with CloudKit).
- [ ] Delete rules intentional; no orphans.
- [ ] Relationship order persisted explicitly if needed.
- [ ] Predicates only use stored properties; enum and compound predicates gated to iOS 27 when used.
- [ ] `@Attribute(.codable)` only for types not owned; not queried or sorted.
- [ ] Background writes via `@ModelActor`, saves explicit.
- [ ] Large fetches limited, indexed, or paginated.
- [ ] History tokens and sync cursors persisted.

## SwiftUI
- [ ] Views small, with narrow inputs; sections extracted as `View` types.
- [ ] `init` and `body` free of expensive work and side effects.
- [ ] `@State` private and owned; not initialized from changing parameters.
- [ ] Xcode 27: no `@State` with both a default value and an `init` assignment.
- [ ] `@Observable` used for new reference state; property types Equatable where possible.
- [ ] Stable `ForEach` identity; no `indices` + `\.self` on mutable data; no ids generated in body.
- [ ] List rows have a single root view.
- [ ] No conditional `.if` modifier; ternaries in modifier arguments.
- [ ] Environment defaults stable; no closures in environment.
- [ ] Navigation value-based; destinations not inside lazy containers.
- [ ] Sheets/alerts use item-based presentation where appropriate.
- [ ] Modern APIs used (`foregroundStyle`, `clipShape`, `onChange` two-param, `NavigationStack`) in new code.
- [ ] Previews compile with self-contained data.
- [ ] Layout adapts to size classes and resizing; no `UIDevice` idiom checks for layout.

## Accessibility and localization
- [ ] Icon-only controls labeled; decorative images hidden.
- [ ] Grouped rows combined for VoiceOver; headers marked.
- [ ] Dynamic Type works at accessibility sizes.
- [ ] Color not the only signal; contrast adequate.
- [ ] Reduce Motion respected.
- [ ] Strings localized with comments; plurals in String Catalog; no concatenated fragments.
- [ ] Numbers, dates, measurements formatted with FormatStyle.

## Security and privacy
- [ ] No secrets in code, logs, analytics.
- [ ] Tokens in Keychain with correct accessibility.
- [ ] Sensitive values logged with `privacy: .private`.
- [ ] Deep links and file imports validated.
- [ ] Purpose strings and privacy manifest updated for new APIs or SDKs.
- [ ] Sensitive files protected; cleared on sign-out.

## Performance and resources
- [ ] No main-thread I/O, decoding, or image decoding.
- [ ] Images downsampled; caches bounded.
- [ ] No retain cycles (closures, tasks, delegates, timers).
- [ ] Network requests cancellable; no polling loops without backoff.

## Tests
- [ ] New logic covered with Swift Testing tests (behavior-named).
- [ ] Edge cases and error paths tested; parameterized where it reduces duplication.
- [ ] Async tests do not sleep; clocks injected.
- [ ] SwiftData tests use in-memory containers; migration tests for schema changes.
- [ ] UI tests use accessibility identifiers and wait APIs.

## Style and maintainability
- [ ] Follows API Design Guidelines and team linter.
- [ ] Access control minimal.
- [ ] No dead code, commented-out code, or untracked TODOs.
- [ ] Public APIs documented.
- [ ] Changes scoped to the task; unrelated refactors split out.
