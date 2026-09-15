# SwiftData (iOS 17 through iOS 27)

## Contents
1. Models
2. Attributes and relationships
3. Container and configuration
4. ModelContext
5. Fetching: `@Query` and `FetchDescriptor`
6. Predicates (incl. enum and compound predicates, iOS 27)
7. Sectioned queries (iOS 27)
8. `.codable` attributes (iOS 27)
9. `ResultsObserver` (iOS 27)
10. Persistent history and `HistoryObserver` (iOS 27)
11. Background work with `@ModelActor`
12. Migrations
13. CloudKit sync
14. Model inheritance (iOS 26)
15. Undo, autosave, transactions
16. Performance
17. Testing and previews
18. Architecture patterns
19. Pitfalls

---

## 1. Models
```swift
import SwiftData

@Model
final class Trip {
    #Unique<Trip>([\.tripNumber])          // iOS 18
    #Index<Trip>([\.departure], [\.origin, \.destination]) // iOS 18

    var tripNumber: String
    var origin: String
    var destination: String
    var departure: Date
    var status: TripStatus                 // Codable enum, filterable in predicates on iOS 27
    var notes: String = ""

    @Relationship(deleteRule: .cascade, inverse: \Leg.trip)
    var legs: [Leg] = []

    @Transient var isSelected = false

    init(tripNumber: String, origin: String, destination: String, departure: Date, status: TripStatus = .scheduled) {
        self.tripNumber = tripNumber
        self.origin = origin
        self.destination = destination
        self.departure = departure
        self.status = status
    }
}

enum TripStatus: String, Codable, CaseIterable, Sendable {
    case scheduled, boarding, departed, arrived, cancelled
}
```
- `@Model` classes are `Observable` automatically. Do not add `@Observable`.
- Supported property types: primitives, `String`, `Date`, `Data`, `URL`, `UUID`, `Decimal`, Codable structs/enums (decomposed into columns when possible), arrays of those, other `@Model` types (relationships), optionals.
- Provide an explicit `init`. Default values help migrations and CloudKit.
- Use `final class`.
- `persistentModelID` is the stable identity (`PersistentIdentifier`, Sendable). Temporary until first save.

## 2. Attributes and relationships
- `@Attribute(.unique)` (not with CloudKit), `.externalStorage` for large `Data`, `.allowsCloudEncryption`, `.preserveValueOnDeletion` (history tombstones), `.spotlight`, `.ephemeral`, `originalName:` for renames, `hashModifier:` to force migration.
- `@Attribute(.codable)` (iOS 27) stores an opaque Codable blob, see section 8.
- `@Relationship(deleteRule: .cascade | .nullify | .deny | .noAction, minimumModelCount:, maximumModelCount:, inverse:)`.
- Declare the inverse on one side with a key path. Many-to-many: arrays on both sides with one inverse declaration.
- To-many relationships are unordered. Persist a `sortIndex: Int` when order matters.
- Assign relationships after inserting both models into the same context, or insert the parent and append children.

## 3. Container and configuration
```swift
let schema = Schema([Trip.self, Leg.self])
let config = ModelConfiguration(
    "Ops",
    schema: schema,
    isStoredInMemoryOnly: false,
    allowsSave: true,
    groupContainer: .identifier("group.com.example.ops"),
    cloudKitDatabase: .none
)
let container = try ModelContainer(for: schema, migrationPlan: OpsMigrationPlan.self, configurations: config)
```
- Attach to scenes/views: `.modelContainer(container)` or `.modelContainer(for: [Trip.self])`.
- Multiple configurations split models across stores (e.g. a read-only reference store and a user store).
- App groups for widgets and extensions.
- Handle container errors: log, show recovery UI. Never `try!` in production.
- Custom data stores (iOS 18): `DataStore` protocol for backing SwiftData with your own storage (JSON, remote).

## 4. ModelContext
- Main context: `container.mainContext` (MainActor) or `@Environment(\.modelContext)`.
- `insert(_:)`, `delete(_:)`, `delete(model:where:)` for batch deletes, `save()`, `rollback()`, `hasChanges`, `autosaveEnabled` (true for main context), `fetch`, `fetchCount`, `fetchIdentifiers`, `enumerate(_:batchSize:)`, `model(for: PersistentIdentifier)`, `registeredModel(for:)`, `transaction { }`, `author` (for history), `undoManager`.
- Contexts are not Sendable. One context per actor.
- Save explicitly after batches of important changes (autosave timing is not guaranteed before app termination or crashes). Save in `scenePhase == .background` handlers.

## 5. Fetching
In views:
```swift
struct TripsView: View {
    @Query(filter: #Predicate<Trip> { $0.status != .cancelled },
           sort: [SortDescriptor(\Trip.departure)],
           animation: .default)
    private var trips: [Trip]

    var body: some View {
        List(trips) { TripRow(title: $0.tripNumber, departure: $0.departure) }
    }
}
```
Dynamic queries via init:
```swift
struct FilteredTrips: View {
    @Query private var trips: [Trip]

    init(origin: String, sortOrder: SortOrder) {
        _trips = Query(
            filter: #Predicate<Trip> { $0.origin == origin },
            sort: \Trip.departure,
            order: sortOrder
        )
    }
    var body: some View { List(trips) { Text($0.tripNumber) } }
}
```
Outside views:
```swift
var descriptor = FetchDescriptor<Trip>(
    predicate: #Predicate { $0.departure >= startOfDay },
    sortBy: [SortDescriptor(\.departure)]
)
descriptor.fetchLimit = 50
descriptor.fetchOffset = page * 50
descriptor.propertiesToFetch = [\.tripNumber, \.departure]
descriptor.relationshipKeyPathsForPrefetching = [\.legs]
let trips = try context.fetch(descriptor)
let count = try context.fetchCount(descriptor)
```
- `@Query(FetchDescriptor)` also works.
- `@Query` re-runs when the store changes; keep predicates simple for large stores.

## 6. Predicates
- `#Predicate<Model> { ... }` supports comparisons, `&&`, `||`, `!`, optional chaining with `??`/`flatMap`, `contains`, `starts(with:)`, `localizedStandardContains`, `allSatisfy`, collection `count`, `isEmpty`, relationship traversal, local captured constants (capture values, not model objects).
- Not supported: arbitrary method calls, computed properties, `@Transient` properties, regex, custom functions. Keep logic to stored properties.
- `#Expression` (iOS 18) for reusable expressions inside predicates.
- **Enum predicates (iOS 27)**: compare Codable enum properties directly:
```swift
let status = TripStatus.boarding
let boarding = #Predicate<Trip> { $0.status == status }
```
  On earlier OS versions, persist `statusRawValue: String` and filter on that.
- **Compound predicates (iOS 27)**: build filters incrementally and combine:
```swift
var parts: [Predicate<Trip>] = []
if !search.isEmpty { parts.append(#Predicate { $0.tripNumber.localizedStandardContains(search) }) }
if onlyToday { parts.append(#Predicate { $0.departure >= startOfDay && $0.departure < endOfDay }) }
let filter = parts.isEmpty ? nil : Predicate(all: parts)   // AND. Use Predicate(any:) for OR
_trips = Query(filter: filter, sort: \Trip.departure)
```
  Earlier OS: `#Predicate { first.evaluate($0) && second.evaluate($0) }`.

## 7. Sectioned queries (iOS 27)
```swift
struct TripsByOrigin: View {
    @Query(sort: \Trip.departure, sectionBy: \Trip.origin)
    private var trips: [Trip]

    var body: some View {
        List {
            ForEach(_trips.sections) { section in
                Section(section.id) {
                    ForEach(section) { trip in
                        TripRow(title: trip.tripNumber, departure: trip.departure)
                    }
                }
            }
        }
    }
}
```
- `trips` is still the flat array. Sections are on the underlying query: `_trips.sections`.
- Each section's `id` is the key path value; the section is a collection of models.
- Sorting applies across the whole result set, so sort by the section key first if you want sections ordered by it.
- The section key must be a persisted stored property (not computed, not transient, not a relationship path). Denormalize a stored field if needed.

## 8. `@Attribute(.codable)` (iOS 27)
```swift
import MapKit

@Model
final class Airport {
    var icao: String
    var name: String
    @Attribute(.codable) var mapItemIdentifier: MKMapItem.Identifier?

    init(icao: String, name: String, mapItemIdentifier: MKMapItem.Identifier? = nil) {
        self.icao = icao
        self.name = name
        self.mapItemIdentifier = mapItemIdentifier
    }
}
```
- Fixes launch crashes like "Class property within Persisted Struct/Enum is not supported" for Codable types that SwiftData cannot decompose (e.g. framework classes).
- Stored as an opaque encoded blob: cannot be used in predicates or sort descriptors, and shape changes do not trigger migrations. The type's Codable implementation must be forward and backward compatible.
- Use only for types you do not own. Model your own types as `@Model` or decomposable Codable structs.

## 9. `ResultsObserver` (iOS 27)
Query-style fetching and change observation anywhere, not just in views.
```swift
import Observation
import SwiftData

@MainActor
@Observable
final class DashboardStore {
    private(set) var departuresToday = 0
    private(set) var delayed: [Trip] = []

    @ObservationIgnored private let observer: ResultsObserver<Trip, Never>
    @ObservationIgnored private var token: ObservationTracking.Token?

    init(modelContext: ModelContext) throws {
        observer = try ResultsObserver<Trip, Never>(modelContext: modelContext)
        token = withContinuousObservation(options: [.didSet]) { [weak self] _ in
            self?.recompute()
        }
    }

    private func recompute() {
        let trips = observer.results
        departuresToday = trips.filter { Calendar.current.isDateInToday($0.departure) }.count
        delayed = trips.filter { $0.status == .boarding && $0.departure < .now }
    }
}
```
- Generic parameters: model type and section identifier type (`Never` when not sectioned).
- Supports filtering, sorting and sectioning like `@Query` (check initializer overloads for predicate/sort/section parameters).
- Everything read during the observation closure is tracked (results plus model properties you touch).
- Keep the `ObservationTracking.Token` alive; releasing it stops updates.
- In SwiftUI views, `@Query` is still the first choice.

## 10. Persistent history and `HistoryObserver`
History (iOS 18):
- Every save records a transaction with changes (`.insert`, `.update`, `.delete`), author and token.
- `context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>(predicate: #Predicate { $0.token > lastToken }))`.
- Change types: `DefaultHistoryInsert<Model>`, `DefaultHistoryUpdate<Model>` (with `updatedAttributes`), `DefaultHistoryDelete<Model>` (tombstone values for `.preserveValueOnDeletion` attributes).
- Set `context.author = "App"` / `"Widget"` / `"Server"` to filter by origin.
- Persist the last processed `DefaultHistoryToken` (it is Codable) so you resume after relaunch.
- Delete old history with `context.deleteHistory(_:)` after processing.

`HistoryObserver` (iOS 27):
```swift
@globalActor actor SyncActor { static let shared = SyncActor() }

@SyncActor
final class OutboundSync {
    private var observer: HistoryObserver?
    private var token: ObservationTracking.Token?
    private let container: ModelContainer

    init(container: ModelContainer) { self.container = container }

    func start() throws {
        observer = try HistoryObserver(authors: ["App"], modelContainer: container)
        token = withContinuousObservation(options: .didSet) { [weak self] _ in
            _ = self?.observer?.eventCounter     // establishes tracking
            self?.drainHistory()
        }
    }

    private func drainHistory() {
        let context = ModelContext(container)
        // fetchHistory after the last persisted token, upload changes, save new token
    }
}
```
- Single observable property `eventCounter` increments when new transactions arrive.
- Filter by `authors:` or `observedModels:` (e.g. `[Trip.self]`).
- Great for outbound sync to your own backend, reacting to widget/extension writes, audit pipelines.
- Exclude your own server-applied changes by using a distinct author when writing them.

## 11. Background work with `@ModelActor`
```swift
@ModelActor
actor TripImporter {
    func importTrips(_ payload: [TripDTO]) throws -> Int {
        for dto in payload {
            modelContext.insert(Trip(tripNumber: dto.number, origin: dto.origin,
                                     destination: dto.destination, departure: dto.departure))
        }
        try modelContext.save()
        return payload.count
    }

    func markArrived(_ id: PersistentIdentifier) throws {
        guard let trip = self[id, as: Trip.self] else { return }
        trip.status = .arrived
        try modelContext.save()
    }
}

// Usage
let importer = TripImporter(modelContainer: container)
let count = try await importer.importTrips(dtos)
```
- The macro synthesizes `modelContainer`, `modelContext`, an executor and `init(modelContainer:)`.
- Pass `PersistentIdentifier` and Sendable DTOs in and out, never `@Model` instances.
- The actor's executor is tied to where its context was created; creating a `@ModelActor` from the main actor can end up running work on the main thread. Create it from a nonisolated/`@concurrent` context when you need true background execution, and verify with Instruments.
- Main-context `@Query` views pick up background saves automatically.
- Batch large imports (save every N inserts) and use `autoreleasepool`-free loops with periodic `save()` to bound memory.

## 12. Migrations
```swift
enum OpsSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Trip.self] }
    @Model final class Trip { var tripNumber: String = ""; var departure: Date = .now; init() {} }
}

enum OpsSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] { [Trip.self] }
    @Model final class Trip {
        @Attribute(.unique) var tripNumber: String = ""
        var departure: Date = .now
        var status: String = "scheduled"
        init() {}
    }
}

enum OpsMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [OpsSchemaV1.self, OpsSchemaV2.self] }
    static var stages: [MigrationStage] { [v1ToV2] }

    static let v1ToV2 = MigrationStage.custom(
        fromVersion: OpsSchemaV1.self,
        toVersion: OpsSchemaV2.self,
        willMigrate: { context in
            // Deduplicate before the unique constraint applies
            let trips = try context.fetch(FetchDescriptor<OpsSchemaV1.Trip>())
            var seen = Set<String>()
            for trip in trips where !seen.insert(trip.tripNumber).inserted { context.delete(trip) }
            try context.save()
        },
        didMigrate: nil
    )
}
```
- Lightweight migrations (`MigrationStage.lightweight`) cover adding optional/defaulted properties, renames with `originalName`, deleting properties.
- Custom stages for data transforms and deduplication.
- Typealias current models (`typealias Trip = OpsSchemaV2.Trip`) so app code uses the latest version.
- Ship migration tests: create a V1 store on disk in a test, then open with the plan.
- Never change a shipped schema without a new version.

## 13. CloudKit sync
- `ModelConfiguration(cloudKitDatabase: .private("iCloud.com.example.ops"))` or `.automatic`.
- Requirements: no `@Attribute(.unique)` / `#Unique`, all properties optional or with defaults, all relationships optional, no `.deny` delete rules.
- Enable iCloud + CloudKit capability, Background Modes remote notifications, and deploy the schema to production in the CloudKit console before release.
- Sync is eventual. Design for duplicates (dedupe on a natural key after sync) and conflicts (last writer wins).
- For shared/public databases or fine-grained control, use Core Data + `NSPersistentCloudKitContainer` or CloudKit directly.

## 14. Model inheritance (iOS 26)
- `@Model class Aircraft {}` with `@Model final class Freighter: Aircraft {}` subclasses.
- Query the base type to fetch all subclasses, filter with `is`/`as?` in predicates on type.
- Use when subtypes share most properties and you query across them. Otherwise prefer composition or an enum discriminator.

## 15. Undo, autosave, transactions
- `.modelContainer(for:isUndoEnabled: true)` or set `context.undoManager`.
- `context.transaction { }` groups changes and saves at the end.
- `rollback()` to discard unsaved edits (e.g. cancel button in an edit sheet).
- Edit sheets: edit a model directly and rollback on cancel, or copy values into a draft struct and apply on save. Choose one pattern per codebase.

## 16. Performance
- Index properties used in predicates and sorts (`#Index`).
- Limit fetched properties and prefetch relationships you will traverse.
- Use `fetchCount` instead of fetching arrays to count.
- Batch deletes: `try context.delete(model: Trip.self, where: #Predicate { $0.departure < cutoff })`.
- Do not store large blobs inline; use `.externalStorage` or files with URLs.
- Avoid `@Query` in many rows; query once at the list level.
- Profile with the Core Data instrument and `-com.apple.CoreData.SQLDebug 1` launch argument (SwiftData runs on Core Data).

## 17. Testing and previews
```swift
@MainActor
enum PreviewData {
    static let container: ModelContainer = {
        let container = try! ModelContainer(for: Trip.self,
                                            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        for index in 0..<10 {
            container.mainContext.insert(Trip(tripNumber: "T\(index)", origin: "MEM", destination: "IND",
                                              departure: .now.addingTimeInterval(Double(index) * 3600)))
        }
        return container
    }()
}
```
- Tests: fresh in-memory container per test (Swift Testing suites create state in `init`).
- Test migrations with on-disk stores in a temporary directory.
- Test `@ModelActor` methods with `await`.

## 18. Architecture patterns
- Small features: views + `@Query` + model methods.
- Medium/large: repositories or stores that own a `ModelContext` for writes, `@Query` in views for reads, `ResultsObserver` for derived state.
- Keep networking DTOs separate from `@Model` types; map at the boundary.
- Offline-first: SwiftData as the source of truth, `HistoryObserver` to push local changes, a sync actor to pull remote changes with a distinct author.

## 19. Pitfalls
- Crash "Class property within Persisted Struct/Enum is not supported": use `@Attribute(.codable)` (iOS 27) or model the type differently.
- Using models across actors: pass `PersistentIdentifier`.
- Capturing a model object inside `#Predicate`: capture its ID or value instead.
- Filtering on computed/transient properties in predicates: not supported; store the value.
- Expecting array relationship order: add a sort index.
- Forgetting to save background contexts.
- Unique constraints plus CloudKit: not allowed.
- `@Query` with complex predicates on thousands of rows in every list row: move to parent.
- Deleting a parent without cascade rules leaves orphans.
- Schema changes without versioning: users crash on launch after update.
