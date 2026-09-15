# Testing: Swift Testing, XCTest, UI tests

## Contents
1. What to use when
2. Swift Testing essentials
3. Parameterized tests
4. Traits
5. Async and concurrency testing
6. Exit tests, attachments, warnings, cancellation, retries
7. XCTest interop (Swift 6.4)
8. Test doubles and dependency injection
9. Testing SwiftUI logic
10. Testing SwiftData
11. UI tests (XCUITest)
12. Snapshot and performance testing
13. Organization and CI

---

## 1. What to use when
| Need | Framework |
|---|---|
| Unit and integration tests | Swift Testing |
| UI automation | XCTest `XCUIApplication` |
| Performance (`measure`, metrics) | XCTest |
| Existing XCTest suites | Keep; migrate gradually. Swift 6.4 interop lets both coexist |

## 2. Swift Testing essentials
```swift
import Testing
@testable import Ops

@Suite("Fuel calculator")
struct FuelCalculatorTests {
    let calculator = FuelCalculator(reservePolicy: .standard)   // fresh per test

    @Test("Adds reserve fuel to trip fuel")
    func addsReserve() throws {
        let plan = try calculator.plan(tripFuel: 12_000)
        #expect(plan.totalFuel == 14_400)
    }

    @Test func rejectsNegativeFuel() {
        #expect(throws: FuelError.negativeFuel) {
            try calculator.plan(tripFuel: -1)
        }
    }

    @Test func `unwraps optional result`() throws {      // raw identifier test name (6.2)
        let alternate = try #require(calculator.nearestAlternate(for: "KMEM"))
        #expect(alternate.icao == "KBNA")
    }
}
```
- `#expect(condition)` records a failure and continues. `#require` throws and stops the test; also unwraps optionals.
- `#expect(throws: SomeError.self)`, `#expect(throws: specificValue)`, `#expect(throws: Never.self)`. Newer toolchains return the thrown error from `#expect(throws:)` for further checks.
- Suites are types (structs preferred). `init` is setup; `deinit` (classes/actors) is teardown.
- Tests run in parallel by default. Avoid shared mutable state; use `.serialized` when order or exclusivity matters.
- `Issue.record("message")` for custom failures.
- `withKnownIssue { }` for known bugs without failing CI.
- `confirmation("callback fires", expectedCount: 1) { confirm in ... }` for event-based code.

## 3. Parameterized tests
```swift
@Test("Converts flight levels", arguments: [
    (FlightLevel(350), 35_000),
    (FlightLevel(90), 9_000),
])
func flightLevelToFeet(level: FlightLevel, feet: Int) {
    #expect(level.feet == feet)
}

@Test(arguments: TripStatus.allCases)
func everyStatusHasLabel(_ status: TripStatus) {
    #expect(!status.label.isEmpty)
}

@Test(arguments: zip(["KMEM", "KIND"], ["Memphis", "Indianapolis"]))
func airportNames(icao: String, name: String) { }
```
- Two argument collections without `zip` produce the Cartesian product.
- Each argument case runs independently and can be re-run from Xcode's test navigator.

## 4. Traits
- `.enabled(if: FeatureFlags.newParser)`, `.disabled("Flaky on CI, FB123")`.
- `.bug("https://tracker/123", "Title")`, `.tags(.networking, .critical)` with `extension Tag { @Tag static var networking: Self }`.
- `.timeLimit(.minutes(1))`.
- `.serialized` on suites.
- Custom scoping traits (`TestTrait` + `TestScoping`, Swift 6.1) for shared setup like task-local dependencies:
```swift
struct MockClockTrait: TestTrait, TestScoping {
    func provideScope(for test: Test, testCase: Test.Case?, performing function: @Sendable () async throws -> Void) async throws {
        try await Clock.$current.withValue(.fixed) { try await function() }
    }
}
```

## 5. Async and concurrency testing
- Test functions can be `async throws`. Mark suites or tests `@MainActor` when testing MainActor stores.
```swift
@MainActor
@Suite struct RosterStoreTests {
    @Test func loadsCrew() async {
        let store = RosterStore(api: StubRosterAPI(crew: [.captain]))
        await store.load()
        #expect(store.crew.count == 1)
        #expect(store.phase == .loaded)
    }
}
```
- Avoid sleeps. Inject clocks (`any Clock<Duration>`) and use test clocks (e.g. swift-clocks) or `ContinuousClock` with controllable schedulers.
- For streams, collect a bounded prefix: `for await value in stream.prefix(3) { }`.
- Test cancellation: start a task, cancel, assert state and that `CancellationError` is not surfaced to users.
- Run tests with Thread Sanitizer periodically.

## 6. Exit tests, attachments, warnings, cancellation, retries
- Exit tests (Swift 6.2): `await #expect(processExitsWith: .failure) { precondition(false) }` to verify crashes and preconditions (macOS/Linux/Windows hosts; not on iOS devices). Swift 6.3 allows capturing values.
- Attachments: `Attachment.record(data, named: "response.json")`; image attachments on Apple platforms (Swift 6.3) for UIKit/AppKit/CoreGraphics images.
- Warning issues (6.3): `Issue.record("Slow response", severity: .warning)` does not fail the test.
- Test cancellation (6.3): `try Test.cancel("Not applicable for this argument")` skips the rest of a test or a single parameterized case.
- Retrying flaky tests (6.4): configurable retry until pass or limit. Prefer fixing flakiness; use retries as a temporary measure with a bug trait.

## 7. XCTest interop (Swift 6.4)
- XCTest assertions (`XCTAssertEqual`) called from code running inside a Swift Testing test are reported as issues.
- Swift Testing APIs (`#expect`, `#require`) work inside XCTest test methods.
- Cross-framework issues default to warnings; an Xcode setting upgrades them to failures.
- Migration path: convert helpers first, then test classes one at a time. Mapping:
  - `XCTestCase` subclass → `@Suite struct`
  - `setUp` → `init`, `tearDown` → `deinit` (class/actor suite)
  - `XCTAssertEqual(a, b)` → `#expect(a == b)`
  - `XCTUnwrap(x)` → `try #require(x)`
  - `XCTAssertThrowsError` → `#expect(throws:)`
  - `XCTSkip` → `.enabled(if:)` / `Test.cancel`
  - `expectation` + `wait` → `confirmation` or async/await

## 8. Test doubles and dependency injection
- Depend on protocols at seams (network, persistence, clock, location, analytics), not everywhere.
```swift
protocol RosterAPI: Sendable {
    func fetchCrew() async throws -> [CrewMember]
}

struct StubRosterAPI: RosterAPI {
    var crew: [CrewMember] = []
    var error: (any Error)?
    func fetchCrew() async throws -> [CrewMember] {
        if let error { throw error }
        return crew
    }
}
```
- Closure-based clients (struct of closures) work well with Swift concurrency and are easy to stub.
- URLProtocol subclasses to stub `URLSession` at the transport level for integration tests.
- Never hit real network or real user data in unit tests.

## 9. Testing SwiftUI logic
- Test stores/view models directly. Views should be thin.
- For navigation, test the router state (`path` contents).
- For formatting, test the format style output with a fixed locale and time zone.
- ViewInspector or snapshot libraries are optional; do not introduce them without team agreement.
- Previews are not tests, but every preview must build.

## 10. Testing SwiftData
```swift
@MainActor
@Suite struct TripRepositoryTests {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        container = try ModelContainer(for: Trip.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        context = container.mainContext
    }

    @Test func deletesCancelledTrips() throws {
        context.insert(Trip(tripNumber: "A1", origin: "MEM", destination: "IND", departure: .now, status: .cancelled))
        context.insert(Trip(tripNumber: "A2", origin: "MEM", destination: "IND", departure: .now))
        try TripRepository(context: context).purgeCancelled()
        #expect(try context.fetchCount(FetchDescriptor<Trip>()) == 1)
    }
}
```
- Migration tests: write a V1 store to a temp URL, close it, reopen with the migration plan, assert data.
- History/observer tests: perform saves with a known author, assert processing results.

## 11. UI tests (XCUITest)
- Launch with arguments/environment to use fake services and in-memory stores: `app.launchArguments = ["-uiTesting"]`.
- Query by accessibility identifiers (`.accessibilityIdentifier("saveButton")`), not labels that get localized.
- Wait with `waitForExistence(timeout:)`, not sleeps.
- Page object pattern for readable flows.
- Keep UI tests few and high value (critical paths). Record video/screenshots on failure via `XCTAttachment`.

## 12. Snapshot and performance
- Performance: `measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) { }` in XCTest; set baselines per device.
- App launch: `XCTApplicationLaunchMetric`.
- Snapshot testing (third party) for design regression; pin device, OS, locale, Dynamic Type size.

## 13. Organization and CI
- Mirror source structure in test targets. Name tests by behavior.
- Test plans (`.xctestplan`) for configurations: sanitizers, locales, retries, tags.
- `xcodebuild test -scheme Ops -destination 'platform=iOS Simulator,name=<simulator name>' -testPlan CI` (list names with `xcrun simctl list devices available`).
- `swift test --filter FuelCalculatorTests` for packages; `swift test --parallel`.
- Code coverage as a signal, not a target. Cover business rules and edge cases thoroughly.
