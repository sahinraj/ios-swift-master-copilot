# Performance, Debugging, Instruments, Builds

## Contents
1. Debugging workflow
2. Crashes
3. Hangs and main-thread work
4. Memory: leaks, growth, retain cycles
5. Concurrency bugs
6. SwiftUI-specific debugging
7. Instruments cheat sheet
8. Launch time and app size
9. Energy and networking
10. Build performance
11. Command-line tools
12. Xcode 27 and AI tooling

---

## 1. Debugging workflow
1. Reproduce reliably; note device, OS, build config, data state.
2. Read the exact error or crash log. Symbolicate.
3. Form one hypothesis; add a breakpoint, log or test that can falsify it.
4. Fix the root cause, not the symptom. Add a regression test.
5. Verify on the oldest supported OS and device class.

LLDB essentials:
- `po value`, `p value`, `v value` (frame variable, no code execution, safest).
- `expr self.isLoading = false` to mutate state.
- `bt`, `frame select 3`, `thread list`.
- Symbolic breakpoints: `UIViewAlertForUnsatisfiableConstraints`, `swift_willThrow` (catch all Swift throws), `objc_exception_throw`.
- Breakpoint actions with "Automatically continue" as non-invasive logging.
- `watchpoint set variable self.count` to find unexpected writes.

## 2. Crashes
| Crash signature | Typical cause |
|---|---|
| `EXC_BAD_INSTRUCTION` / `Fatal error: Unexpectedly found nil` | Force unwrap, `try!`, `as!` |
| `Index out of range` | Unchecked array index, stale index after mutation |
| `EXC_BAD_ACCESS` | Unsafe pointers, `unowned` to deallocated object, C interop |
| `Simultaneous accesses` | Exclusivity violation (`inout` overlap) |
| `SwiftData/...: Fatal error` at launch | Schema issue, unsupported type (consider `@Attribute(.codable)` on iOS 27), missing migration |
| `Incorrect actor executor assumption` | `MainActor.assumeIsolated` or isolated code called from wrong thread (legacy callbacks) |
| `Watchdog 0x8badf00d` | Main thread blocked at launch or resume |
| `Jetsam` / memory limit | Huge images, unbounded caches, leaks |
| `SIGABRT` with `NSInternalInconsistencyException` | UIKit misuse (table updates, constraints, off-main UI) |
| `CheckedContinuation` misuse | Resumed twice (trap) or never (warning log, hang) |

- Enable Address Sanitizer, Thread Sanitizer, Undefined Behavior Sanitizer and Main Thread Checker in scheme diagnostics during investigations.
- Zombie Objects for Objective-C over-release.
- Crash reports: Xcode Organizer, MetricKit `MXCrashDiagnostic`, TestFlight feedback. Keep dSYMs for every build.

## 3. Hangs and main-thread work
- Symptoms: UI freezes, "Hang detected" in Xcode debug gauges, Organizer hang reports.
- Tools: Instruments Hangs and Time Profiler, Xcode Thread Performance Checker.
- Causes: synchronous I/O, JSON decoding, image decoding, SwiftData fetches of large sets, heavy `body`/`init`, semaphores waiting on async work, lock contention.
- Fixes: move to `@concurrent` async functions, batch and paginate fetches, precompute off main, cache formatters, downsample images.

## 4. Memory
- Xcode Memory Graph Debugger: look for purple leak markers, then inspect retain paths.
- Leaks and Allocations instruments; mark generations to find growth between repeated actions.
- Retain cycle sources: stored closures capturing `self`, `Task` stored on self looping forever, strong delegates, `Timer`, Combine `sink` stored without `[weak self]`, observers.
- `deinit { logger.debug("deinit \(Self.self)") }` during debugging to confirm deallocation.
- Image memory = width x height x 4 bytes. A 4000x3000 photo is ~46 MB decoded.
- `NSCache` for purgeable caches; respond to memory warnings.

## 5. Concurrency bugs
- Thread Sanitizer for data races (still valuable with Swift 6 when unsafe escapes exist).
- Swift Concurrency instrument (Swift Tasks, Swift Actors): task lifetimes, actor queue depth, main actor blocking.
- Reentrancy bugs: state changed across `await`; fix by re-reading state after await or using in-flight task patterns.
- Priority inversions: high-priority tasks awaiting low-priority actors; avoid long work on shared actors.
- Deadlocks: `DispatchSemaphore.wait()` on MainActor waiting for MainActor work.
- Leaked tasks: tasks never cancelled; use `.task` modifiers and cancel stored tasks.

## 6. SwiftUI-specific debugging
- `let _ = Self._printChanges()` in `body` prints what changed (debug only).
- Instruments SwiftUI template: body update counts, cause-and-effect graphs, long view body updates, hitches.
- View hierarchy debugger works for SwiftUI-backed UIKit views.
- Common bugs:
  - State resets: identity changed (`if/else`, `.id`, unstable `ForEach` ids).
  - View not updating: value not observed (read outside body, `@ObservationIgnored`, non-Observable class), or `@State` initialized from a parameter and never updated.
  - Task restarts repeatedly: `.task(id:)` id changes each render.
  - Sheet opens twice or not at all: multiple `sheet` modifiers competing on same view or presentation from a disappearing view.
  - Navigation destination not found: `navigationDestination` inside a lazy container or not registered for that type.
  - Keyboard covers fields: use `ScrollView` + `scrollDismissesKeyboard`, `safeAreaInset`, focus-driven scroll.
- Xcode 27 `@State` macro errors: see swiftui-ios26-ios27-new.md.

## 7. Instruments cheat sheet
| Instrument | Use for |
|---|---|
| Time Profiler | CPU hot spots, slow `body`, slow launch |
| Hangs | Main thread blocks |
| SwiftUI | View body updates, invalidations, hitches |
| Swift Concurrency | Tasks, actors, main actor contention |
| Allocations / Leaks | Memory growth and leaks |
| Network | Request timing, payloads (HTTP traffic) |
| Core Data | SwiftData/Core Data fetches, faults, saves |
| Energy Log / Power Profiler | Battery impact |
| Animation Hitches / Core Animation | Dropped frames |
| App Launch | Pre-main and post-main launch phases |
| os_signpost (Points of Interest) | Custom intervals from `OSSignposter` |
| File Activity / Disk Usage | I/O on main thread |

- Profile Release builds on real devices. Simulator timing is not representative.

## 8. Launch time and app size
- Target a first frame well under 400 ms warm on supported devices. Defer SDK initialization, lazy-load features, avoid synchronous network at launch.
- Avoid heavy `static let` initializers that run at first access during launch.
- Measure with `XCTApplicationLaunchMetric` and Organizer launch metrics.
- App size: asset catalogs with app thinning, on-demand resources/background assets for large content, strip unused architectures, review third-party SDK weight, `-Osize` for size-sensitive targets.

## 9. Energy and networking
- Batch network requests; avoid polling (use push or long-lived connections with backoff).
- Stop location updates when not needed; use significant-change or `CLMonitor` conditions.
- Stop timers and display links in background.
- Use `URLSession` discretionary background transfers for non-urgent sync.

## 10. Build performance
- Build with Timing Summary; Build Timeline in Xcode's report navigator.
- `-warn-long-function-bodies=200`, `-warn-long-expression-type-checking=200` to find slow type checking.
- Xcode 27 `ContentBuilder` improves SwiftUI type checking automatically.
- Split large files and view bodies; add explicit types to complex expressions and collection literals.
- Modularize with local SwiftPM packages; enable explicitly built modules; avoid `@_exported` umbrella imports.
- Keep macro usage deliberate; macro targets add build cost (prebuilt swift-syntax helps).
- Clean DerivedData only when caches are genuinely corrupted, not as a routine.
- CI: cache SwiftPM checkouts and compilation caches where supported.

## 11. Command-line tools
- `xcodebuild -list`, `xcodebuild build -scheme App -destination 'generic/platform=iOS'`.
- `xcodebuild test -scheme App -destination 'platform=iOS Simulator,name=<name>'`.
- `xcrun simctl list`, `boot`, `install`, `launch`, `openurl`, `privacy grant`, `push`, `status_bar override`.
- `xcrun devicectl` for physical devices (install, launch, logs).
- `xcrun xctrace record --template 'Time Profiler' --launch -- App.app`.
- `swift build`, `swift test`, `swift package resolve`, `swift package show-traits` (6.3), `swift format`.
- `log stream --predicate 'subsystem == "com.example.ops"'`.
- `xcrun agent skills export` (Xcode 27) to export Apple's coding assistant skills.

## 12. Xcode 27 and AI tooling
- Xcode 27 Coding Assistant with Apple skills (SwiftUI Specialist, What's New in SwiftUI).
- Xcode exposes an MCP server for agents; tools like XcodeBuildMCP allow agents to build, run tests and read diagnostics. Always verify agent changes by building and running tests locally.
- Treat AI-generated Swift like any PR: compile, test, profile the hot paths, review concurrency annotations.
