# SwiftUI Performance and Identity

Core idea: a view is SwiftUI's unit of invalidation. Most performance problems come from invalidating more than necessary or from unstable identity.

## Contents
1. Identity: structural and explicit
2. Invalidation boundaries
3. Keep `init` and `body` cheap
4. Observation-specific rules
5. Environment pitfalls
6. ForEach, List and Table identity rules
7. Conditional modifiers
8. Lazy containers and large data
9. Images
10. Animations and identity
11. Build-time performance (type checking)
12. Measuring
13. Quick diagnostic checklist

---

## 1. Identity
- **Structural identity**: position and type in the view hierarchy. `if/else` produces two different identities; toggling destroys state in the branch.
- **Explicit identity**: `ForEach` ids and `.id(_:)`. Changing `.id` resets the view and its state on purpose (use to reset a form, not as a refresh hack).
- Lifetime of `@State` equals the lifetime of identity.

Preserve identity by changing values, not structure:
```swift
// Avoid: two identities, state and animations reset
if isCompact { SummaryCard(model).padding(8) } else { SummaryCard(model).padding(24) }

// Prefer: one identity
SummaryCard(model).padding(isCompact ? 8 : 24)
```

## 2. Invalidation boundaries
- A separate `View` struct is a boundary. SwiftUI compares its inputs and skips `body` if they did not change.
- Computed properties and `@ViewBuilder` functions are inlined into the parent. They re-run whenever the parent does.
```swift
// Avoid
struct FlightScreen: View {
    @State private var showsDetails = false
    let flight: Flight
    var body: some View {
        VStack { header; details; footer }
    }
    private var header: some View { FlightHeaderContent(flight: flight) }
    private var details: some View { /* expensive */ Text(flight.remarks) }
    private var footer: some View { Text(flight.gate) }
}

// Prefer
struct FlightScreen: View {
    @State private var showsDetails = false
    let flight: Flight
    var body: some View {
        VStack {
            FlightHeader(number: flight.number, route: flight.route)
            FlightDetails(remarks: flight.remarks, isExpanded: showsDetails)
            GateFooter(gate: flight.gate)
        }
    }
}
```
- Pass only the fields a child reads. Value types are compared memberwise.
- Keep high-frequency state (timers, scroll offsets, drag positions) in the smallest view possible.

## 3. Keep `init` and `body` cheap
- `init` runs every time the parent re-evaluates. Treat it as a copy of inputs.
- No JSON decoding, formatter creation, sorting, filtering of large arrays, regex compilation, or image decoding in `init` or `body`.
- Precompute in the model layer or cache in the store.
- Use `Text(date, format:)` and `FormatStyle` instead of creating `DateFormatter` in views.
- Heavy derived data: compute when inputs change (`onChange`, store method) and store the result.
- Never create objects in body (`let viewModel = ViewModel()` inside body).

## 4. Observation-specific rules
- Views depend only on observable properties read during `body`. Reading inside closures (button actions) does not create dependencies.
- Make observable property types `Equatable`. The `@Observable` macro's setter skips notifications for equal values only when it can compare them. Arrays are Equatable only if elements are.
- Avoid a single "god" observable that every view reads. Split by feature, or read narrow properties.
- Do not read `store.items` in a parent just to pass `store` to children; pass the store and let children read.
- `@State private var store = Store()` is lazily initialized in the 2027 SDK (back-deployed to iOS 17): the initializer expression runs once per view lifetime. On older toolchains, an expensive init in the default value ran on every parent update, so initialize in `.task` or pass the object in.
- Frequent updates (sensor data, streaming): throttle or coalesce in the store before assigning.

## 5. Environment pitfalls
- Every view that reads an environment value updates when that value changes.
- Unstable defaults (`@Entry var now: Date = Date()`, `@Entry var service = Service()`) create new values on every access and cause churn. Use static constants.
- Closures in the environment compare as always-changed. Wrap actions in a stable struct or a reference type.
- Avoid putting rapidly changing values (scroll offset, timers) in the environment at the root.

## 6. ForEach, List and Table identity
- Use `Identifiable` models or a stable key path (`id: \.serverID`, `id: \.url`).
- Never `ForEach(items.indices, id: \.self)` for data that can insert, delete or reorder.
- Never `id: \.self` on values that can duplicate or change (titles, names).
- Never generate ids during body (`UUID()` in a computed `id`). Assign ids once at creation.
- Do not derive ids from mutable, user-editable properties; editing changes identity, drops focus, and animates as delete plus insert.
- `ForEach($items) { $item in }` for bindings keyed by identity.
- `List` and lazy stacks need each row to produce **one** top-level view. A top-level `switch`, `if` without `else`, or `Group` with multiple children makes SwiftUI evaluate every row. Wrap in a container:
```swift
struct AlertRow: View {
    let alert: OpsAlert
    var body: some View {
        HStack {   // single root
            switch alert.severity {
            case .info: Label(alert.title, systemImage: "info.circle")
            case .warning: Label(alert.title, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
            case .critical: Label(alert.title, systemImage: "xmark.octagon").foregroundStyle(.red)
            }
        }
    }
}
```
- Filter collections before `ForEach` instead of rendering empty rows.
- Sectioned data: stable section ids too.

## 7. Conditional modifiers
Never write or use:
```swift
extension View {
    @ViewBuilder func `if`<T: View>(_ condition: Bool, transform: (Self) -> T) -> some View {
        if condition { transform(self) } else { self }
    }
}
```
It creates two view types, destroys state when the condition flips and breaks animations. Use:
- Ternaries in arguments: `.opacity(isHidden ? 0 : 1)`, `.foregroundStyle(isActive ? .green : .secondary)`.
- Neutral values: `.padding(isCompact ? 0 : 16)`, `.disabled(!canEdit)`.
- `#if` for compile-time platform differences only.
- If structure truly differs, accept the identity change deliberately and document why.

## 8. Lazy containers and large data
- `List`, `LazyVStack`, `LazyVGrid` create rows on demand. Plain `VStack` inside `ScrollView` builds everything.
- Paginate or batch-fetch (SwiftData `fetchLimit`/`fetchOffset`, `@Query` with limits) for thousands of rows.
- Avoid `GeometryReader` in rows.
- Avoid `.id()` on every row that changes each update.
- Row views should not own tasks that restart on scroll; use `.task(id:)` with stable ids and cancellable work.
- For extremely large or custom-rendered data sets, consider `Canvas`, or `UICollectionView` via representable.

## 9. Images
- Downsample large images to display size (ImageIO `CGImageSourceCreateThumbnailAtIndex`).
- Decode off the main actor in `@concurrent` functions; cache results (NSCache or actor cache).
- `AsyncImage` in the 2027 SDK uses HTTP caching; configure capacity with a custom `URLSession` via `asyncImageURLSession(_:)`. For older targets, implement a small cached image loader.
- Use asset catalogs and SF Symbols; avoid huge PNGs for icons.

## 10. Animations and identity
- Animations need stable identity to interpolate. Identity changes produce transitions (insert/remove) instead.
- Scope `.animation(_, value:)` to the smallest subtree.
- `transaction { $0.animation = nil }` to disable animation for a subtree.
- `contentTransition(.identity)` to stop cross-fades.

## 11. Build-time performance
- "The compiler is unable to type-check this expression in reasonable time":
  - Xcode 27's `ContentBuilder` unifies common SwiftUI builders into a single path and greatly reduces this, for any deployment target.
  - Still split huge bodies into subviews, add explicit types for complex literals, avoid long chains of `+` on mixed numeric types, avoid deeply nested ternaries inside builders.
  - Swift Charts with deeply branching content on deployment targets below 27: extract branches into `@ChartContentBuilder` functions.
- Enable `-warn-long-expression-type-checking=200` and `-warn-long-function-bodies=200` in Other Swift Flags during investigations.
- Use Xcode's Build Timeline / Build with Timing Summary to find slow files.
- Prefer many small files and modules over giant files; enable explicit modules.

## 12. Measuring
- Instruments SwiftUI template: View Body updates, View Properties changes, Hitches, Hangs, Core Animation commits.
- Time Profiler for expensive body/init code.
- `let _ = Self._printChanges()` inside body during debugging to see which dependency triggered an update. Remove before committing.
- Enable "Hang Reporting" and use MetricKit in production for hangs and hitches.
- Test on the oldest supported device in Release configuration.

## 13. Quick diagnostic checklist
1. Is expensive work in `init` or `body`? Move it.
2. Are sections computed properties instead of subviews? Extract.
3. Does a child receive more data than it reads? Narrow it.
4. Are `ForEach` ids stable and unique? Fix identity.
5. Do List rows have a single root view? Wrap.
6. Is there a conditional `.if` modifier or `if/else` swapping similar views? Replace with ternaries.
7. Are observable property types Equatable? Conform.
8. Are environment defaults stable? Make static.
9. Is high-frequency state stored high in the tree? Push it down.
10. Are images downsampled and cached? Fix.
