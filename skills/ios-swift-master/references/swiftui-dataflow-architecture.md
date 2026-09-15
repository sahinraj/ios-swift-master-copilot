# SwiftUI Data Flow and App Structure

## Contents
1. App, Scene, View
2. Choosing the right property wrapper or macro
3. Observation (`@Observable`)
4. Environment
5. Bindings
6. Stores vs view models
7. Passing data narrowly
8. Persistence wrappers
9. Legacy ObservableObject interop
10. Examples

---

## 1. App, Scene, View
```swift
@main
struct OpsApp: App {
    @State private var session = SessionStore()
    let container = try! ModelContainer(for: Trip.self) // replace with error handling in production

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
        }
        .modelContainer(container)

        #if os(macOS)
        Settings { SettingsView() }
        #endif
    }
}
```
- Scenes: `WindowGroup`, `Window`, `DocumentGroup`, `Settings` (macOS), `MenuBarExtra` (macOS), `ImmersiveSpace` (visionOS), `UtilityWindow`, `DocumentGroupLaunchScene`.
- Scene phase: `@Environment(\.scenePhase)` for foreground/background transitions (save, pause timers).
- Use `@UIApplicationDelegateAdaptor` only for things SwiftUI lacks (push registration, some SDK setup).
- Handle container creation failures gracefully in production (show a recovery screen, log, attempt store reset with user consent).

## 2. Choosing the right tool
| Need | Use |
|---|---|
| Local value state owned by a view | `@State private var isExpanded = false` |
| Reference state (Observable class) owned by a view | `@State private var store = FlightStore()` (lazy since 2027 SDK, back-deployed to iOS 17) |
| Two-way access to a parent's value | `@Binding var isOn: Bool` |
| Bindings into an Observable object passed in | `@Bindable var store: FlightStore` or `@Bindable var store = store` inside body |
| Shared object across a subtree | `.environment(store)` + `@Environment(FlightStore.self) private var store` |
| Shared value/config across a subtree | `@Entry var dateStyle: Date.FormatStyle = .dateTime` in `EnvironmentValues` + `@Environment(\.dateStyle)` |
| Focus | `@FocusState private var focusedField: Field?` |
| Gesture transient state | `@GestureState` |
| Matched geometry / transitions | `@Namespace` |
| UserDefaults-backed setting | `@AppStorage("key")` |
| Per-scene restoration | `@SceneStorage("key")` |
| SwiftData fetch in view | `@Query` |
| SwiftData context | `@Environment(\.modelContext)` |

Rules:
- `@State` is always `private` and owned by the view that declares it.
- Never pass `@State` values in through init expecting them to update; initial values are captured once.
- Do not use `@Binding` when a view only reads. Pass a plain `let`.

## 3. Observation
```swift
@MainActor
@Observable
final class RosterStore {
    enum Phase: Equatable { case idle, loading, loaded, failed(String) }

    private(set) var crew: [CrewMember] = []
    private(set) var phase: Phase = .idle
    var searchText = ""

    @ObservationIgnored private let api: RosterAPI

    init(api: RosterAPI) { self.api = api }

    var filtered: [CrewMember] {
        guard !searchText.isEmpty else { return crew }
        return crew.filter { $0.name.localizedStandardContains(searchText) }
    }

    func load() async {
        phase = .loading
        do {
            crew = try await api.fetchCrew()
            phase = .loaded
        } catch is CancellationError {
            phase = .idle
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
```
- Views track only properties they actually read in `body`. Reading `store.crew.count` tracks `crew`.
- Computed properties are tracked through the stored properties they read.
- `@ObservationIgnored` for dependencies, caches, tasks, and anything that should not trigger updates.
- Make stored property types `Equatable` so the generated setter can skip no-op writes.
- Do not read observable properties in `init` of a view to derive stored state.
- Observable objects must be classes. Prefer `final`.
- Observation works with nested observables: `store.selectedTrip?.status` tracks through both.

## 4. Environment
```swift
extension EnvironmentValues {
    @Entry var unitsPreference: UnitsPreference = .imperial
}

RootView().environment(\.unitsPreference, .metric)

struct AltitudeLabel: View {
    @Environment(\.unitsPreference) private var units
    let feet: Double
    var body: some View { Text(units.format(feet: feet)) }
}
```
- Object environment: `.environment(store)` + `@Environment(RosterStore.self)`. Crashes if missing; for optional use `@Environment(RosterStore.self) private var store: RosterStore?`.
- Keep environment default values cheap and stable. A default like `Date()` or a new object on every access causes churn.
- Do not store closures in the environment that capture changing state; they break equality and invalidate everything.
- Useful built-ins: `\.dismiss`, `\.openURL`, `\.colorScheme`, `\.dynamicTypeSize`, `\.horizontalSizeClass`, `\.locale`, `\.calendar`, `\.timeZone`, `\.editMode`, `\.isEnabled`, `\.accessibilityReduceMotion`, `\.scenePhase`, `\.openWindow`, `\.appearsActive` (window active state, now on iPad too in the 2027 SDK).

## 5. Bindings
- Derived bindings: `$store.searchText`, `$trip.notes`.
- Custom binding when necessary:
```swift
Toggle("Notify", isOn: Binding(
    get: { settings.notificationsEnabled },
    set: { settings.setNotifications($0) }
))
```
- Binding to optional unwrap: `Binding($optionalValue)` returns `Binding<Value>?`.
- Avoid creating bindings to array elements by index for mutable lists; use `ForEach($items) { $item in }` which keys by identity.

## 6. Stores vs view models
Pick based on the codebase:
- **Feature store** (`@Observable` class owning state + async actions, often shared across screens). Good default for SwiftUI apps.
- **View model per screen**. Fine when screens have heavy presentation logic; keep them thin and test them.
- **Plain views with `@Query` and model methods**. Great for small SwiftData features.
- **Unidirectional architectures** (TCA, Redux-like). Follow the project's conventions exactly.

Regardless of pattern:
- Business logic is testable without SwiftUI.
- Views do not call networking or persistence directly unless the project style is explicitly "views + @Query".
- Side effects are `async` methods on the store, started from `.task` or button actions.
- Errors surface as state, not as `print`.

## 7. Passing data narrowly
```swift
// Avoid: row depends on the whole store, re-evaluates on any change
struct TripRow: View {
    let store: TripStore
    let tripID: Trip.ID
    var body: some View { Text(store.trip(tripID).title) }
}

// Prefer: row receives exactly what it shows
struct TripRow: View {
    let title: String
    let departure: Date
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
            Text(departure, format: .dateTime.hour().minute())
        }
    }
}
```
- Value inputs are compared field by field. Passing a large struct invalidates on any field change.
- Observable class inputs are compared by identity; only read properties trigger updates. Passing an observable model to a row is fine if the row reads only what it shows.
- Closures passed as inputs defeat diffing. Pass actions through the environment or keep them stable.

## 8. Persistence wrappers
- `@AppStorage` for small user preferences only (Bool, Int, Double, String, URL, Data, RawRepresentable). Never secrets.
- `@SceneStorage` for per-window UI restoration (selected tab, scroll anchor ID).
- Keychain for tokens and credentials (see networking-security-privacy.md).

## 9. Legacy ObservableObject interop
- If the deployment target is below iOS 17: `ObservableObject` + `@Published` + `@StateObject` (owner) / `@ObservedObject` (non-owner) / `@EnvironmentObject`.
- Migrating: replace `ObservableObject` with `@Observable`, remove `@Published`, `@StateObject` becomes `@State`, `@ObservedObject` becomes a plain property (or `@Bindable`), `@EnvironmentObject` becomes `@Environment(Type.self)`, `.environmentObject(x)` becomes `.environment(x)`.
- Combine pipelines that derived state become computed properties or `async` methods.

## 10. Example: list, detail, edit with Observation
```swift
struct TripListView: View {
    @Environment(TripStore.self) private var store
    @State private var selection: Trip.ID?

    var body: some View {
        NavigationSplitView {
            List(store.trips, selection: $selection) { trip in
                TripRow(title: trip.title, departure: trip.departure)
            }
            .navigationTitle("Trips")
            .task { await store.load() }
            .refreshable { await store.load() }
        } detail: {
            if let id = selection, let trip = store.trip(id) {
                TripDetailView(trip: trip)
            } else {
                ContentUnavailableView("Select a trip", systemImage: "airplane")
            }
        }
    }
}

struct TripDetailView: View {
    @Bindable var trip: TripModel   // @Observable class
    var body: some View {
        Form {
            TextField("Title", text: $trip.title)
            DatePicker("Departure", selection: $trip.departure)
        }
    }
}
```
