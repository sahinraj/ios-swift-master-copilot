# Swift Concurrency (Swift 6.4)

## Contents
1. Mental model
2. Project settings to check first
3. async/await basics
4. Structured concurrency
5. Unstructured tasks
6. Cancellation
7. Actors and isolation
8. MainActor and UI
9. Sendable, sending, regions
10. AsyncSequence and streams
11. Bridging legacy code
12. Observation outside SwiftUI
13. Synchronization primitives
14. Common compiler errors and fixes
15. Anti-patterns

---

## 1. Mental model
- An **isolation domain** is either an actor (including `@MainActor`) or nonisolated. Data can only be mutated from its domain.
- `await` marks a potential suspension point. State can change across it (actor reentrancy). Re-validate assumptions after every `await`.
- Tasks form a tree. Child tasks inherit priority, task-local values and cancellation. Structured concurrency guarantees children finish before the parent scope ends.
- Swift 6 language mode turns data-race diagnostics into errors.

## 2. Project settings to check first
| Setting | Meaning |
|---|---|
| `SWIFT_VERSION = 6` / `swiftLanguageModes: [.v6]` | Full data race checking |
| `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` / `.defaultIsolation(MainActor.self)` | Unannotated code in the module is `@MainActor` |
| `SWIFT_APPROACHABLE_CONCURRENCY = YES` | Enables `NonisolatedNonsendingByDefault` and related inference |
| `SWIFT_STRICT_CONCURRENCY = complete` | Swift 5 mode warnings |

With MainActor-by-default:
- Everything is `@MainActor` unless marked `nonisolated` or declared in another isolation.
- Mark pure value types, parsers, and services that must run anywhere as `nonisolated`.
- Heavy work goes into `@concurrent` functions.

```swift
nonisolated struct FlightPlanParser {
    @concurrent
    func parse(_ data: Data) async throws -> FlightPlan {
        try JSONDecoder().decode(FlightPlan.self, from: data)
    }
}
```

## 3. async/await basics
```swift
func loadRoster() async throws -> [CrewMember] {
    let (data, response) = try await URLSession.shared.data(from: rosterURL)
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
        throw RosterError.badStatus
    }
    return try JSONDecoder().decode([CrewMember].self, from: data)
}
```
- Call async functions from async contexts, `.task` modifiers, or `Task { }`.
- Async properties: `var thumbnail: UIImage { get async throws }`.
- Async sequences with `for try await line in url.lines { }`.
- Under `nonisolated(nonsending)` default, a nonisolated async function runs on the caller's executor. To guarantee background execution, use `@concurrent`.

## 4. Structured concurrency
Parallel fixed number of operations:
```swift
async let schedule = api.schedule(for: pilotID)
async let bids = api.bids(for: pilotID)
let (s, b) = try await (schedule, bids)
```
Dynamic number of operations:
```swift
let images = try await withThrowingTaskGroup(of: (Int, UIImage).self) { group in
    for (index, url) in urls.enumerated() {
        group.addTask { (index, try await loader.image(at: url)) }
    }
    var result = [Int: UIImage]()
    for try await (index, image) in group { result[index] = image }
    return result
}
```
- Limit concurrency by adding tasks as others finish (`group.next()`).
- `withDiscardingTaskGroup` for fire-and-forget children (servers, listeners) without accumulating results.
- The first thrown error cancels remaining children in throwing groups when you rethrow.
- Task-local values: `@TaskLocal static var requestID: String?` with `$requestID.withValue(...)`.

## 5. Unstructured tasks
- `Task { }` inherits the current actor and priority. Use to bridge from sync code (button actions, delegate callbacks).
- `Task.detached { }` inherits nothing. Almost never needed; prefer `@concurrent` functions.
- `Task.immediate { }` (6.2) starts running synchronously until first suspension.
- Swift 6.4 warns when a throwing unstructured task's errors are ignored.
```swift
Button("Sync") {
    Task {
        do { try await store.sync() }
        catch { store.present(error) }
    }
}
```
- Store long-lived tasks and cancel them:
```swift
@MainActor @Observable final class LiveTracker {
    @ObservationIgnored private var updates: Task<Void, Never>?
    func start() {
        updates?.cancel()
        updates = Task { [weak self] in
            for await position in PositionFeed.stream() {
                self?.apply(position)
            }
        }
    }
    func stop() { updates?.cancel() }
}
```
- In SwiftUI prefer `.task { }` / `.task(id:) { }`: automatic cancellation when the view disappears or the id changes.

## 6. Cancellation
- Cancellation is cooperative. Check `Task.isCancelled` or call `try Task.checkCancellation()` in loops and between expensive steps.
- `withTaskCancellationHandler(operation:onCancel:)` to cancel underlying non-Swift work (sockets, file operations).
- URLSession async APIs throw `CancellationError`/`URLError(.cancelled)` when the task is cancelled.
- Swift 6.4 cancellation shields for must-finish cleanup:
```swift
defer {
    await withTaskCancellationShield {
        await ledger.flushPendingWrites()
    }
}
```
- Do not treat `CancellationError` as a user-facing failure. Filter it out before showing alerts.

## 7. Actors and isolation
```swift
actor TokenStore {
    private var token: AuthToken?
    private var refreshTask: Task<AuthToken, Error>?

    func validToken() async throws -> AuthToken {
        if let token, !token.isExpired { return token }
        if let refreshTask { return try await refreshTask.value }
        let task = Task { try await AuthAPI.refresh() }
        refreshTask = task
        defer { refreshTask = nil }
        let newToken = try await task.value
        token = newToken
        return newToken
    }
}
```
- The in-flight task pattern above avoids duplicate refreshes caused by reentrancy.
- Actor methods are implicitly isolated; external calls need `await`.
- `nonisolated` members cannot touch mutable state; good for `let` constants and pure functions.
- `isolated` parameters: `func update(on actor: isolated SomeActor)`.
- `#isolation` default argument to inherit the caller's isolation in generic helpers.
- Custom global actors: `@globalActor actor DatabaseActor { static let shared = DatabaseActor() }`.
- Actors are not a replacement for every class. Use them for shared mutable state accessed from multiple domains.

## 8. MainActor and UI
- SwiftUI `View` is `@MainActor` isolated. Observable stores that drive UI should be `@MainActor`.
- `MainActor.run { }` is rarely needed in async code; call a `@MainActor` function with `await` instead.
- `MainActor.assumeIsolated { }` for synchronous callbacks you know run on main (legacy delegates); traps otherwise.
- Delegates from frameworks (CoreLocation, AVFoundation, CoreBluetooth) may call on other queues: declare methods `nonisolated` and forward:
```swift
extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        Task { @MainActor in self.latest = last }
    }
}
```
- Isolated conformances for MainActor types conforming to nonisolated protocols: `extension Store: @MainActor SomeDelegate`.

## 9. Sendable, sending, regions
- Value types with `Sendable` members are implicitly `Sendable` when not public. Public types need explicit conformance.
- Final classes can be `Sendable` if all stored properties are `let` and `Sendable` (or use `weak let` for delegates).
- Actors are always `Sendable`.
- Closures crossing domains must be `@Sendable` or `sending`.
- `sending` parameters and results transfer ownership of a non-Sendable value into another region: the caller cannot use it afterwards.
- Region-based isolation lets you create a non-Sendable value and pass it into a task if you never touch it again.
- `~Sendable` (6.4) documents an intentionally non-Sendable type.
- `@unchecked Sendable` only with internal locking (`Mutex`) and a comment.
- SwiftData `@Model` instances and `ModelContext` are not Sendable. Pass `PersistentIdentifier` or value snapshots.

## 10. AsyncSequence and streams
```swift
func events() -> AsyncStream<FlightEvent> {
    AsyncStream(bufferingPolicy: .bufferingNewest(100)) { continuation in
        let observer = EventSource { continuation.yield($0) }
        continuation.onTermination = { _ in observer.stop() }
        observer.start()
    }
}
```
- `AsyncStream.makeStream(of:)` returns `(stream, continuation)` for producer/consumer separation.
- `AsyncThrowingStream` for failures.
- Choose a buffering policy on purpose; unbounded buffers grow forever.
- Swift Async Algorithms package: `debounce`, `throttle`, `merge`, `combineLatest`, `chunks`, `AsyncChannel`.
- Built-in sequences: `URL.lines`, `FileHandle.bytes`, `NotificationCenter.notifications(named:)`.

## 11. Bridging legacy code
```swift
func legacyFetch() async throws -> Report {
    try await withCheckedThrowingContinuation { continuation in
        LegacyClient.fetch { result in
            continuation.resume(with: result)
        }
    }
}
```
- Resume exactly once. Checked continuations trap on double resume and log if never resumed.
- Wrap delegate-based APIs with `AsyncStream`.
- Combine: `publisher.values` gives an `AsyncSequence`. Do not add new Combine pipelines for app state; use Observation.
- GCD code: replace `DispatchQueue.main.async` with MainActor isolation, `DispatchQueue.global().async` with `@concurrent` functions, serial queues guarding state with actors or `Mutex`.

## 12. Observation outside SwiftUI
- `Observations { model.value }` (6.2) yields an async sequence of transactional snapshots:
```swift
Task {
    for await count in Observations({ store.pendingCount }) {
        badge.update(count)
    }
}
```
- `withObservationTracking(_:onChange:)` for one-shot change notifications.
- `withContinuousObservation(options:)` returning an `ObservationTracking.Token` (2027 SDK) is used with SwiftData `ResultsObserver`/`HistoryObserver`; keep the token alive for as long as you want updates.

## 13. Synchronization primitives
- `Mutex<State>` (Synchronization module, iOS 18+) for tiny critical sections in synchronous code:
```swift
import Synchronization
final class Counter: Sendable {
    private let value = Mutex(0)
    func increment() { value.withLock { $0 += 1 } }
}
```
- `Atomic<Int>` for lock-free counters.
- `OSAllocatedUnfairLock` for older targets.
- Never hold a lock across `await`.

## 14. Common compiler errors and fixes
| Error | Fix |
|---|---|
| "Main actor-isolated property can not be referenced from a nonisolated context" | Make the caller `@MainActor`, add `await` in async context, or move the value into a `nonisolated let` |
| "Sending 'x' risks causing data races" | Do not use `x` after sending it; make it `Sendable`; pass a copy or ID |
| "Capture of non-sendable type in @Sendable closure" | Capture a Sendable snapshot, mark the type Sendable, or restructure to avoid crossing |
| "Static property 'shared' is not concurrency-safe" | `static let` with Sendable type, or isolate with `@MainActor` |
| "Non-sendable result type cannot be sent from nonisolated context" | Return a Sendable DTO, or keep the call in the same isolation |
| "Call to main actor-isolated initializer in a synchronous nonisolated context" | Mark the caller `@MainActor` or make the init `nonisolated` |
| "Conformance of X to protocol P crosses into main actor-isolated code" | Use an isolated conformance `extension X: @MainActor P` or make requirements `nonisolated` |
| "Unstructured throwing task was not used" (6.4) | Handle errors inside the task, store and await the handle, or `_ = Task { }` |

## 15. Anti-patterns
- `Task.detached` to "get off the main thread". Use `@concurrent`.
- `DispatchQueue.main.async` inside async code.
- `@unchecked Sendable` or `nonisolated(unsafe)` to make errors disappear.
- `Task { }` inside `onAppear` instead of `.task`.
- Awaiting inside a loop over items that could run in parallel (use a task group, bounded).
- Ignoring reentrancy: reading actor state, awaiting, then writing based on the stale read.
- Blocking with semaphores to wait for async work (deadlocks on MainActor).
- Swallowing `CancellationError` as a failure alert.
- Creating `ModelContext` on one actor and using it on another.
