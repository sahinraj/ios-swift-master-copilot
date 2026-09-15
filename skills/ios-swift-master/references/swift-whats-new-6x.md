# What's New in Swift 6.0 to 6.4

Use this to pick features the project's toolchain supports and to migrate safely. Always check `swift --version` / Xcode version before using a feature. Check the Swift Evolution dashboard (https://www.swift.org/swift-evolution/) for the exact proposal status.

## Swift 6.4 (Xcode 27, released September 2026)

### Language ergonomics
- **`anyAppleOS` availability** covers iOS, iPadOS, macOS, watchOS, tvOS and visionOS at a shared version: `@available(anyAppleOS 27, *)`, `#if os(anyAppleOS)`. Combine with a separate `@available(tvOS ..., unavailable)` when one platform differs.
- **`@diagnose` attribute** gives per-declaration control over warnings: silence a deprecation warning for one function, promote a warning to an error, or downgrade a future error to a warning during migration.
- **Async `defer`** (SE-0493): `await` is allowed in `defer` inside async functions. Cleanup is implicitly awaited before return.
- **Existential syntax** relaxed: parentheses are no longer required in some positions, e.g. `any P?`.
- **Memberwise initializers** improved for structs mixing `private` and non-private stored properties (an internal init for accessible properties plus a private init with everything).
- **Borrowing iteration**: a new iteration protocol lets `for-in` borrow elements, so noncopyable containers like `Span` and `InlineArray` can be iterated without copies and iteration can throw.
- **Borrow and mutate accessors** for yielding storage access in performance-sensitive library code.

### Concurrency
- **Task cancellation shields** (SE-0504): `await withTaskCancellationShield { await transaction.rollback() }` makes cleanup code see `Task.isCancelled == false`. Use only for short cleanup, never to hide cancellation from long work.
- **Warnings for ignored throwing tasks** (SE-0520): `Task { try await work() }` with an unused handle and unhandled errors now warns. Handle errors inside the task, keep the handle and await `value`, or write `_ = Task { }` when ignoring is intentional.
- **Typed throws in `Task` initializers**: `Task<String, URLError>`.
- **Async `Result` initializer** (SE-0530): `let result = await Result { try await fetch() }`.
- **`~Sendable`** (SE-0518): declare that a type is intentionally not `Sendable` and suppress inference, without blocking a thread-safe subclass from conforming.

### Interop and platforms
- Better C interop, Swift-Java improvements, WebAssembly/JavaScriptKit work, Embedded Swift gains full metatype support.

### Foundation
- `URL` unified into a single Swift implementation (NSURL/CFURL), parsing up to 4x faster.
- Faster `Data` operations and `NSData` bridging.
- `ProgressManager` and `Subprogress` for structured, async-friendly progress reporting (also used by SwiftUI's Document API writers).

### Swift Testing
- XCTest interoperability: XCTest assertion failures inside Swift Testing tests are reported as issues, and Swift Testing APIs such as `#expect` work inside XCTest. Cross-framework issues default to warnings; Xcode has a setting to make them failures.
- Retry support for flaky tests up to a configurable limit.
- Builds on 6.3's warning-severity issues and `Test.cancel()`.

## Swift 6.3 (March 2026)
- **`@c`** exposes Swift functions and enums to C with a generated header declaration; `@c(CustomName)`; `@c @implementation` implements a C-declared function in Swift.
- **Module selectors**: `ModuleA::getValue()`; `Swift::Task { }`.
- **Library performance attributes**: `@specialize`, `@inline(always)`, `@export(implementation)`.
- **`weak let`** (SE-0481) for immutable weak references, which makes some classes checkably `Sendable`.
- **SwiftPM**: Swift Build integration preview, prebuilt swift-syntax for shared macro libraries, `swift package show-traits`.
- **Swift Testing**: `Issue.record(_:severity: .warning)`, `try Test.cancel()`, image attachments (UIKit/AppKit/CoreGraphics overlays).
- **DocC**: experimental Markdown output, static HTML content, code block annotations (`nocopy`, `highlight=[...]`, `showLineNumbers`, `wrap=`).
- Official Swift SDK for Android.

## Swift 6.2 (September 2025, Xcode 26)

### Approachable concurrency
- **Default actor isolation** (SE-0466): module-wide `MainActor` isolation. Xcode build setting `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (default for new app projects in Xcode 26+). SwiftPM: `.defaultIsolation(MainActor.self)` in `swiftSettings`.
- **`nonisolated(nonsending)` by default** (SE-0461, upcoming feature `NonisolatedNonsendingByDefault`, enabled by `SWIFT_APPROACHABLE_CONCURRENCY = YES`): nonisolated async functions run on the caller's actor instead of hopping to the global executor.
- **`@concurrent`**: explicitly run an async function on the concurrent thread pool. Use for CPU-heavy work.
- **Isolated conformances** (SE-0470): `extension ViewModel: @MainActor Equatable`.
- **`Task.immediate`** (SE-0472) starts synchronously on the current actor until the first suspension.
- **Task naming** (SE-0469): `Task(name: "SyncFlights") { }`.
- **`Observations`** (SE-0475): `for await value in Observations({ model.count }) { }` streams changes from `@Observable` types outside SwiftUI.
- **Isolated `deinit`** for actor-isolated classes.
- **Global-actor-isolated conformances and `@MainActor` default** reduce `Sendable` errors in app targets.

### Performance and safety
- `InlineArray<N, T>` with `[N of T]` sugar (SE-0453, SE-0483).
- `Span`, `MutableSpan`, `RawSpan`, `UTF8Span` (SE-0447 and follow-ups).
- Strict memory safety checking (opt-in, SE-0458) with `unsafe` expressions.
- Integer generic parameters (SE-0452).
- Raw identifiers with backticks (SE-0451), great for test names.
- `@abi` attribute for ABI-preserving API changes.
- Subprocess package, `NotificationCenter` typed messages (Foundation), `Duration` improvements.
- WebAssembly support; VS Code Swift extension officially published by swift.org.

## Swift 6.1 (March 2025, Xcode 16.3)
- `nonisolated` on types and extensions.
- Trailing commas in tuples, parameter lists, generic lists, closure capture lists (SE-0439).
- Task group child result type inference.
- `@objc @implementation` for implementing Objective-C classes in Swift.
- Swift Testing: `ConfirmationSteps`, test scoping traits (`TestScoping`).
- Package traits in SwiftPM.

## Swift 6.0 (September 2024, Xcode 16)
- **Swift 6 language mode** with complete data-race safety checking by default.
- **Region-based isolation** (SE-0414) and **`sending`** (SE-0430) remove many false positive `Sendable` errors.
- **Typed throws** (SE-0413).
- **Noncopyable generics** (SE-0427), `~Copyable` in `Optional`, `Result`, etc.
- **`count(where:)`** (SE-0220), `RangeSet` and discontiguous collection ops.
- **Access level on imports** (SE-0409).
- **Pack iteration** (SE-0408).
- **`Int128`/`UInt128`**.
- **Synchronization module**: `Mutex`, `Atomic`.
- **`@retroactive`** conformance marker.
- **Swift Testing** introduced.
- **Embedded Swift** preview.
- Foundation re-core in Swift (swift-foundation) begins.

## Migration playbook: Swift 5 mode to Swift 6 mode

1. Update to the newest Xcode. Build in Swift 5 mode with `SWIFT_STRICT_CONCURRENCY = complete` to see warnings first.
2. For app targets, set Default Actor Isolation to `MainActor` and enable Approachable Concurrency. This removes most noise in UI code.
3. Work module by module, leaves first (models, utilities), then services, then UI.
4. Fix patterns in this order:
   - Global mutable state: make it `let`, move into an actor, or isolate to `@MainActor`.
   - Non-Sendable types crossing actors: make value types `Sendable`, pass IDs instead of models, use `sending` parameters.
   - Completion-handler APIs: wrap with `withCheckedThrowingContinuation` once; resume exactly once.
   - Delegates from Apple frameworks called on arbitrary queues: mark methods `nonisolated` and hop to MainActor explicitly.
   - Timers, NotificationCenter and KVO closures: move to `Task` loops with `AsyncSequence` (`NotificationCenter.default.notifications(named:)`) or typed notification messages.
5. Use `@preconcurrency import` only for modules you do not control that lack annotations, and remove it when they update.
6. Flip `SWIFT_VERSION = 6` per target when warnings reach zero. Keep a short allowlist of documented `@unchecked Sendable` types.
7. Add tests for anything whose threading changed. Run with Thread Sanitizer.

## Upcoming feature flags worth knowing
Enable in SwiftPM with `.enableUpcomingFeature("Name")`, in Xcode under Swift Compiler, Upcoming Features.
- `NonisolatedNonsendingByDefault`
- `InferIsolatedConformances`
- `ExistentialAny` (require `any`)
- `MemberImportVisibility` (imports must be explicit in each file)
- `InternalImportsByDefault`
- `InferSendableFromCaptures`

Strict memory safety is not an upcoming feature flag; it is opted into with the `-strict-memory-safety` compiler flag (SwiftPM: `.strictMemorySafety()`). Verify flag spelling against the current toolchain before adding it.
