# App Architecture, Modularization, DI, Errors, Logging

## Contents
1. Principles
2. Layering
3. Feature structure
4. Modularization with Swift Package Manager
5. Dependency injection
6. Error handling strategy
7. Logging and diagnostics
8. Configuration, feature flags, environments
9. Code style and project hygiene

---

## 1. Principles
- Match the existing architecture. Consistency beats novelty.
- Keep SwiftUI views declarative and thin. Business rules live in plain Swift types that are testable without UI.
- Push side effects (network, disk, clock, location) to the edges behind small interfaces.
- Model state explicitly with enums. Make invalid states unrepresentable.
- Prefer composition over inheritance and value types over classes.
- Design for concurrency from the start: MainActor UI state, actors or `@concurrent` functions for work, Sendable DTOs between layers.

## 2. Layering
```
App target (composition root: scenes, DI wiring, app lifecycle)
 └─ Feature modules (screens, stores, feature-specific models)
     └─ Domain (entities, rules, use cases; no UIKit/SwiftUI imports)
         └─ Data (API clients, SwiftData/Core Data, Keychain, file storage)
             └─ Core utilities (logging, formatting, networking primitives)
```
- Dependencies point downward only. Domain does not import SwiftUI.
- DTOs (Codable, network shapes) map to domain types at the data layer boundary.
- SwiftData `@Model` types may serve as domain entities in smaller apps; in larger apps, keep them in the data layer and map.

## 3. Feature structure
```
Features/Schedule/
  ScheduleScreen.swift        // View, composes subviews
  ScheduleStore.swift         // @MainActor @Observable, async actions, state enum
  ScheduleRow.swift           // Narrow-input subview
  ScheduleRoute.swift         // Hashable navigation values
  ScheduleClient.swift        // Protocol or closure struct for data access
  Previews/ScheduleFixtures.swift
Tests/ScheduleTests/
  ScheduleStoreTests.swift
```
Store template:
```swift
@MainActor
@Observable
final class ScheduleStore {
    enum State: Equatable {
        case idle
        case loading
        case loaded([ScheduleDay])
        case empty
        case failed(message: String)
    }

    private(set) var state: State = .idle
    @ObservationIgnored private let client: ScheduleClient
    @ObservationIgnored private let logger = Logger(subsystem: "com.example.ops", category: "Schedule")

    init(client: ScheduleClient) { self.client = client }

    func load(month: Date) async {
        state = .loading
        do {
            let days = try await client.days(in: month)
            state = days.isEmpty ? .empty : .loaded(days)
        } catch is CancellationError {
            return
        } catch {
            logger.error("Schedule load failed: \(error.localizedDescription, privacy: .public)")
            state = .failed(message: String(localized: "Could not load your schedule."))
        }
    }
}
```

## 4. Modularization with SwiftPM
```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "OpsKit",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "ScheduleFeature", targets: ["ScheduleFeature"]),
        .library(name: "Domain", targets: ["Domain"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-collections", from: "1.1.0"),
    ],
    targets: [
        .target(name: "Domain", swiftSettings: [.defaultIsolation(nil)]),
        .target(
            name: "ScheduleFeature",
            dependencies: ["Domain", .product(name: "OrderedCollections", package: "swift-collections")],
            resources: [.process("Resources")],
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
            ]
        ),
        .testTarget(name: "ScheduleFeatureTests", dependencies: ["ScheduleFeature"]),
    ],
    swiftLanguageModes: [.v6]
)
```
- A local package in the app workspace is the easiest way to modularize: faster incremental builds, enforced boundaries, isolated tests and previews.
- Use `package` access level for APIs shared between modules of the same package but hidden from the app.
- Resources: `Bundle.module`; String Catalogs per module with `String(localized:bundle: .module)`, or the `#bundle` macro (Xcode 26+) which resolves the correct bundle for the current module.
- Package traits (Swift 6.1+) for optional features.
- Keep macro targets separate; prebuilt swift-syntax reduces build cost (6.3).
- Verify `swiftSettings` names against your tools version; set the tools version comment to what the team's Xcode supports.

## 5. Dependency injection
Options, from lightest:
1. **Initializer injection** (default). Explicit, testable.
2. **Environment injection** for SwiftUI: `.environment(store)` and `@Entry` values for services.
```swift
extension EnvironmentValues {
    @Entry var scheduleClient: ScheduleClient = .live
}
```
3. **Closure-based clients**:
```swift
struct ScheduleClient: Sendable {
    var days: @Sendable (_ month: Date) async throws -> [ScheduleDay]
}
extension ScheduleClient {
    static let live = ScheduleClient { month in try await ScheduleAPI.shared.days(in: month) }
    static let preview = ScheduleClient { _ in ScheduleDay.samples }
}
```
4. **Task-local dependencies** for deep call stacks in tests.
5. **Third-party containers** (swift-dependencies, Factory) only if already used.

Avoid singletons for anything stateful that tests need to replace. If a singleton exists, wrap access behind an injected interface.

## 6. Error handling strategy
- Define errors per layer: `NetworkError`, `PersistenceError`, domain errors like `BidError.windowClosed`.
- Map low-level errors to domain errors at layer boundaries; do not leak `URLError` to views.
- User-facing messages come from `LocalizedError.errorDescription` or view-layer mapping with `String(localized:)`.
- Distinguish recoverable (retry, re-auth), user-fixable (validation), and programmer errors (preconditions).
- Filter `CancellationError` silently.
- Retries with exponential backoff and jitter for idempotent requests only.
- Every `catch` either handles, maps and rethrows, or logs with context. No empty catches.

## 7. Logging and diagnostics
```swift
import OSLog

extension Logger {
    static let sync = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app", category: "Sync")
}

Logger.sync.info("Uploaded \(count) changes")
Logger.sync.error("Upload failed for trip \(tripID, privacy: .private): \(error.localizedDescription, privacy: .public)")
```
- Use `Logger` (unified logging), not `print`. Levels: `debug`, `info`, `notice`, `error`, `fault`.
- Mark personal and sensitive values `privacy: .private` (default for dynamic strings) and never log tokens.
- Signposts for performance: `OSSignposter` intervals around expensive operations; visible in Instruments.
- MetricKit (`MXMetricManager`) for crash, hang, launch and energy diagnostics from the field.
- Retrieve logs from devices with `log collect` or `OSLogStore` for in-app diagnostic export (with consent).

## 8. Configuration and feature flags
- Build configurations (Debug, Release, Staging) with `.xcconfig` files for base URLs and bundle IDs. No secrets in xcconfig or source.
- Runtime feature flags from a remote config with safe defaults and caching.
- `#if DEBUG` for debug-only tooling; never ship debug menus to production builds.
- Managed App Configuration (MDM) for enterprise defaults (see enterprise-ipad.md).

## 9. Code style and hygiene
- Follow the Swift API Design Guidelines.
- swift-format (bundled with Swift 6 toolchains, `swift format`) or SwiftLint per team configuration.
- One primary type per file; extensions for conformances.
- `// MARK: -` sections for large types.
- DocC comments for public APIs of modules.
- No commented-out code, no TODOs without a ticket reference.
- Keep warnings at zero; treat warnings as errors in CI for owned modules. Use Swift 6.4 `@diagnose` for targeted exceptions instead of global suppression.
