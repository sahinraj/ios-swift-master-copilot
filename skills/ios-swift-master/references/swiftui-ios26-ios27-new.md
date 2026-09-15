# SwiftUI: iOS 26 Liquid Glass and the 2027 Releases (iOS 27)

Gate everything here with availability checks unless the deployment target already covers it. API names are from Apple's WWDC26 "What's new in SwiftUI" session and SDK docs; confirm exact signatures in Xcode 27 Quick Help when compiling fails.

## Contents
- Part A: iOS 26 (2025) Liquid Glass and related APIs
- Part B: 2027 releases
  1. Source-breaking changes: `@State` macro and `ContentBuilder`
  2. Look and feel refresh
  3. Resizable iPhone apps
  4. Tabs and toolbars
  5. Document API
  6. Reorderable containers
  7. Swipe actions on any view
  8. Item-based alerts and confirmation dialogs
  9. AsyncImage caching and custom sessions
  10. Agent skills in Xcode 27
  11. Adoption checklist

---

## Part A: iOS 26 Liquid Glass

Apps built with the iOS 26 SDK adopt Liquid Glass automatically for system bars, tab bars, sheets, menus, toolbars and controls. Custom chrome needs explicit adoption.

### Core APIs
```swift
// A custom floating control on glass
HStack {
    Button("Arm", systemImage: "bolt") { arm() }
    Button("Reset", systemImage: "arrow.counterclockwise") { reset() }
}
.padding()
.glassEffect(.regular.tint(.blue).interactive(), in: .capsule)
```
- `glassEffect(_:in:)` with `Glass.regular`, `.clear`, `.identity`; modifiers `.tint(_:)`, `.interactive()`.
- `GlassEffectContainer(spacing:) { }` groups nearby glass shapes so they blend and morph together; improves rendering performance.
- `glassEffectID(_:in:)` with a `@Namespace` for morphing transitions between glass elements; `glassEffectUnion(id:namespace:)` to merge shapes; `glassEffectTransition(_:)`.
- Buttons: `.buttonStyle(.glass)` and `.buttonStyle(.glassProminent)`.
- `backgroundExtensionEffect()` extends imagery under sidebars and inspectors.
- `scrollEdgeEffectStyle(_:for:)` for soft or hard edge effects under bars.
- Tab bars: `tabBarMinimizeBehavior(.onScrollDown)`, `tabViewBottomAccessory { }`, `Tab(role: .search)`.
- Toolbars: `ToolbarSpacer(.fixed | .flexible)`, `sharedBackgroundVisibility(.hidden)`, badges on toolbar items.
- `ConcentricRectangle` and container-concentric corners to match device and window corners.
- Sheets get glass backgrounds at partial detents; remove custom opaque `presentationBackground` unless required.

### Guidance
- Do not put glass on content (lists, cards of data). Glass is for the navigation and control layer that floats above content.
- Do not stack glass on glass. Use a `GlassEffectContainer` instead.
- Remove custom bar backgrounds (`toolbarBackground(.visible)` with opaque colors) that fight the system look unless branding requires them.
- Test with Reduce Transparency and Increase Contrast; glass falls back automatically, custom overlays may not.
- Mixed UIKit + SwiftUI: `UIGlassEffect` and SwiftUI `glassEffect` do not share containers. Keep morphing groups within one framework.

### Other iOS 26 SwiftUI additions
- `@Animatable` macro and `@AnimatableIgnored`.
- `WebView` and `WebPage` (WebKit for SwiftUI).
- Rich text editing: `TextEditor(text: $attributedString)` with `AttributedTextSelection`.
- `navigationSubtitle(_:)`.
- Swift Charts 3D (`Chart3D`).
- Drag and drop improvements (`dragContainer`, multi-item drags on macOS).
- `@Observable` works with `Observations` async sequence from Swift 6.2.
- Foundation Models framework for on-device LLM features (see platform-integration.md).

---

## Part B: 2027 releases (iOS/iPadOS/macOS/watchOS/tvOS/visionOS 27, Xcode 27)

### 1. Source-breaking changes (fix these first when upgrading to Xcode 27)

#### `@State` is now a macro
- Reference types stored in `@State` are initialized **lazily, once per view lifetime**. This behavior is back-deployed to iOS 17 / macOS 14 and aligned releases when built with Xcode 27.
- New compile error pattern: a `@State` property with a default value that is also assigned in `init`:
```swift
// Error in Xcode 27: 'self.title' used before being initialized
struct PageEditor: View {
    @State private var draft = Draft()
    let title: String
    init(title: String) {
        self.draft = Draft(title: title)
        self.title = title
    }
    var body: some View { Text(draft.title) }
}

// Fix: remove the default value, initialize once in init
struct PageEditor: View {
    @State private var draft: Draft
    let title: String
    init(title: String) {
        self.draft = Draft(title: title)
        self.title = title
    }
    var body: some View { Text(draft.title) }
}
```
  Reordering assignments is the wrong fix. Assigning a new value to an already-defaulted `@State` never updated the displayed state anyway.
- Stacking another property wrapper on a `@State` property can produce "invalid redeclaration of synthesized property". Restructure so backing storage names do not collide.
- Views relying on a synthesized private memberwise init used from an extension may need an explicit initializer.
- Reference: TN3211, "Resolving SwiftUI source incompatibilities for State and ContentBuilder".

#### `ContentBuilder` unifies result builders
- Common SwiftUI builders (`ViewBuilder` and friends used by `Section`, `Group`, `ForEach`, etc.) share a single builder, `@ContentBuilder`, which is an evolution of `ViewBuilder` and works for any deployment target.
- Big win: far fewer "unable to type-check this expression in reasonable time" errors.
- New ambiguity errors to fix:
  - Passing a styled `ShapeStyle` expression directly to `overlay`/`background` can report `ambiguous use of 'opacity'`. Use the trailing closure form:
```swift
// Before (may be ambiguous in Xcode 27)
Text("Hold short").overlay(Color.red.opacity(0.4).blendMode(.multiply))
// After
Text("Hold short").overlay { Color.red.opacity(0.4).blendMode(.multiply) }
```
  - A type in another module named like a SwiftUI type (e.g. its own `Color`) may now be ambiguous. Qualify as `SwiftUI.Color`.
  - Swift Charts with deeply branching content and a deployment target below 27 can type-check slowly. Extract branches into `@ChartContentBuilder` functions.
- You can annotate your own helpers: `@ContentBuilder func legend() -> some View { }`.

### 2. Look and feel refresh
- Liquid Glass gets a refined appearance automatically and follows the new system Liquid Glass tint slider. No code changes needed.
- On macOS, custom glass elements can be `interactive()` and respond to the pointer.
- iPad windows dim icons and text when inactive, like Mac. Adjust custom elements with `@Environment(\.appearsActive)`:
```swift
struct AccountFooter: View {
    @Environment(\.appearsActive) private var appearsActive
    var body: some View {
        AccountBadge().opacity(appearsActive ? 1 : 0.5)
    }
}
```
- iPad and Mac menu bars show a minimal set of icons by default. Show an icon for a key item with `.labelStyle(.titleAndIcon)` on its `Label`.

### 3. Resizable iPhone apps
- iPhone apps are resizable on iOS 27 (iPhone Mirroring, iPhone apps running on iPad).
- Xcode 27 Live Previews have resize handles.
- Use size classes and container sizes, never device idiom, for layout decisions. Handle orientation and geometry changes without assuming screen bounds. Mixed UIKit apps: see "Modernize your UIKit app" (WWDC26).

### 4. Tabs and toolbars
```swift
TabView {
    Tab("Schedule", systemImage: "calendar") { ScheduleView() }
    Tab("Trades", systemImage: "arrow.left.arrow.right") { TradesView() }
    Tab("Cart", systemImage: "cart", role: .prominent) { CartView() }
}
```
- `Tab(role: .prominent)` places a distinguished tab at the bottom trailing edge.
- Toolbar space management when the window shrinks:
```swift
.toolbar {
    ToolbarItemGroup {
        UndoButton()
        RedoButton()
    }
    .visibilityPriority(.high)            // stays visible longest

    ToolbarOverflowMenu {                  // always in the overflow menu
        ExportButton()
        ClearAllButton()
    }

    ToolbarItem(placement: .topBarPinnedTrailing) {   // never hidden
        ShareButton()
    }
}
```
- `.toolbarMinimizeBehavior(.onScrollDown, for: .navigationBar)` hides the nav bar while scrolling down.
- `contentMarginsRemoved()` removes default margins around a toolbar item.
- `ToolbarPlacement.statusBar` visibility replaces `statusBarHidden(_:)` on iOS (now deprecated).
- Toolbar builders accept `ForEach` and `EmptyView`.
- Availability differs per API and platform; check each.

### 5. Document API (new foundation for document apps)
New protocols for iOS, macOS and visionOS 27 that complement `FileDocument`/`ReferenceFileDocument`. Prefer them for new document apps targeting 27+.

Concepts:
- The document is an `@Observable` **class** (not recreated on edits, so editors like `TextEditor` keep their models).
- `WritableDocument`: list of writable content types, an `@MainActor` `snapshot(contentType:)` that captures current content as a value, and a `writer(configuration:)` returning a `DocumentWriter`.
- `DocumentWriter`: a `nonisolated async` `write(snapshot:to:previous:progress:)` that runs in the background, receives the previous snapshot for incremental package writes, and reports progress with `Subprogress`.
- `ReadableDocument` + `DocumentReader`: the twin for reading.
- Convenience `FileWrapperDocumentReader` / `FileWrapperDocumentWriter` if you do not need custom streaming or direct URL access.
- Direct document URL access is first-class.
- Multiple export formats: add content types (e.g. `.png`) and branch on `contentType.conforms(to:)` inside the writer.
- `DocumentCreationSource` + `NewDocumentButton(_:source:)` in `DocumentGroupLaunchScene` offer multiple ways to create a document; the creation closure receives a `context` with the chosen source.
- Autosave depends on registered undo actions. Register undo for edits or changes will not be detected.

Shape (verify exact signatures in the SDK):
```swift
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let flightLog = UTType(exportedAs: "com.example.flightlog")
}

struct LogSnapshot: Sendable {
    var entries: [LogEntry]
}

@Observable
final class FlightLogDocument: WritableDocument, ReadableDocument {
    static let writableContentTypes: [UTType] = [.flightLog, .commaSeparatedText]
    static let readableContentTypes: [UTType] = [.flightLog]

    var entries: [LogEntry] = []

    @MainActor
    func snapshot(contentType: UTType) async throws -> sending LogSnapshot {
        LogSnapshot(entries: entries)
    }

    func writer(configuration: sending WriteConfiguration) -> sending LogWriter {
        LogWriter(contentType: configuration.contentType)
    }

    // ReadableDocument requirements: provide a DocumentReader and apply the read snapshot.
}

struct LogWriter: DocumentWriter {
    typealias Snapshot = LogSnapshot
    let contentType: UTType

    nonisolated func write(
        snapshot: sending LogSnapshot,
        to destination: URL,
        previous: sending LogSnapshot?,
        progress: consuming Subprogress
    ) async throws {
        if contentType.conforms(to: .flightLog) {
            // Encode and write only what changed compared to `previous`.
        } else if contentType.conforms(to: .commaSeparatedText) {
            // Export CSV.
        }
    }
}

@main
struct FlightLogApp: App {
    var body: some Scene {
        DocumentGroupLaunchScene("Flight Logs") {
            NewDocumentButton("New Log", source: .blank)
            NewDocumentButton("Import From Template…", source: .template)
        }
        DocumentGroup { document in
            FlightLogEditor(document: document)
        } { configuration, context in
            FlightLogDocument(configuration: configuration, context: context)
        }
    }
}

extension DocumentCreationSource {
    static let blank = Self(id: "blank")
    static let template = Self(id: "template")
}
```

### 6. Reorderable containers (drag to reorder anywhere)
Works with `List`, `LazyVStack`, `LazyVGrid`, stacks and custom layouts on iOS, macOS, watchOS (first time) and visionOS 27. Not tvOS.
```swift
struct WaypointList: View {
    @State private var waypoints: [Waypoint]

    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(waypoints) { waypoint in
                    WaypointRow(name: waypoint.name)
                }
                .reorderable()
            }
            .reorderContainer(for: Waypoint.self) { difference in
                difference.apply(to: &waypoints)
            }
        }
    }
}
```
- The closure receives a `ReorderDifference` with `sources` (moved IDs) and a `destination` whose `position` is `.before(id)` or `.end`. Apply it to your data yourself.
- `apply(to:)` above is your own helper, not an SDK method. A dependency-free version:
```swift
extension ReorderDifference where CollectionID == ReorderableSingleCollectionIdentifier {
    func apply(to items: inout [some Identifiable<ItemID>]) {
        let moving = items.filter { sources.contains($0.id) }
        items.removeAll { sources.contains($0.id) }
        let insertIndex: Int = switch destination.position {
        case .before(let id): items.firstIndex { $0.id == id } ?? items.endIndex
        case .end: items.endIndex
        }
        items.insert(contentsOf: moving, at: insertIndex)
    }
}
```
  Apple's session sample uses `OrderedDictionary` from swift-collections for the same job. Check the generic constraint names in Quick Help if this does not compile.
- Multiple sections: tag each `ForEach` with `.reorderable(collectionID:)` and use `reorderContainer(for:in:)` so the difference includes destination collection.
- The reorder container is already a drag source and drop target. Add `dragContainer(for:)` to customize payloads or per-child `dropDestination(for:isEnabled:)` to support drop-onto-item actions.
- For SwiftData-backed order, persist an explicit `sortIndex` property and update it in the closure.

### 7. Swipe actions on any view
```swift
ScrollView {
    LazyVStack(spacing: 0) {
        ForEach(notices) { notice in
            NoticeRow(notice: notice)
                .swipeActions(edge: .trailing) {
                    Button("Acknowledge", systemImage: "checkmark") { acknowledge(notice) }
                        .tint(.green)
                }
        }
    }
}
.swipeActionsContainer()
```
- Without `.swipeActionsContainer()` on the scroll container, `swipeActions` does nothing outside `List`.
- New overload with `onPresentationChanged` tells you when actions reveal or hide.
- iOS, macOS, watchOS, visionOS 27. Not tvOS.

### 8. Item-based alerts and confirmation dialogs
```swift
@State private var pendingDeletion: Waypoint?

.confirmationDialog("Delete waypoint?", item: $pendingDeletion) { waypoint in
    Button("Delete \(waypoint.name)", role: .destructive) { delete(waypoint) }
} message: { waypoint in
    Text("\(waypoint.name) will be removed from the route.")
}

.alert("Sync failed", item: $syncError) { _ in
    Button("OK", role: .cancel) { }
} message: { error in
    Text(error.localizedDescription)
}
```
- One optional drives presentation and value; SwiftUI resets it to `nil` on dismissal. No `Identifiable` requirement.

### 9. AsyncImage caching and custom sessions
- `AsyncImage` honors standard HTTP caching by default on 2027 OS versions, even for apps built with older SDKs (runtime behavior).
- New `AsyncImage(request:)` initializer accepts a `URLRequest` for per-image cache policy, headers or auth.
- `asyncImageURLSession(_:)` sets the `URLSession` for all `AsyncImage`s in a subtree (custom `URLCache` sizes, auth, timeouts).
```swift
enum ImageSessions {
    static let charts: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 50_000_000, diskCapacity: 300_000_000)
        return URLSession(configuration: config)
    }()
}

ChartThumbnailGrid()
    .asyncImageURLSession(ImageSessions.charts)

AsyncImage(request: URLRequest(url: chartURL, cachePolicy: .returnCacheDataElseLoad)) { phase in
    switch phase {
    case .success(let image): image.resizable().scaledToFit()
    case .failure: Image(systemName: "exclamationmark.triangle")
    default: ProgressView()
    }
}
```
- Both new APIs require the 27 SDK.

### 10. Agent skills in Xcode 27
- Xcode 27's Coding Assistant ships Apple skills: **SwiftUI Specialist** (best practices) and **What's New in SwiftUI** (adopting 2027 APIs).
- Export them for other tools with `xcrun agent skills export` (run with `--help` for options). The exported Markdown can live next to this skill in `~/.copilot/skills/`.

### 11. Adoption checklist for an existing app
1. Build with Xcode 27. Fix `@State` macro and `ContentBuilder` ambiguity errors (TN3211).
2. Review Liquid Glass appearance, inactive iPad window state, menu bar icons.
3. Test iPhone resizing with Live Preview resize handles; remove idiom-based layout.
4. Audit toolbars on compact widths; add `visibilityPriority`, `ToolbarOverflowMenu`, pinned placements.
5. Replace `isPresented` + stored optional patterns with item-based `alert`/`confirmationDialog` where you touch that code.
6. Replace custom image caches with `AsyncImage` caching if deployment target allows.
7. Replace hand-rolled drag-reorder or `onMove` workarounds in non-List containers with reorderable containers (27+).
8. Document apps targeting 27+: evaluate `WritableDocument`/`ReadableDocument` for background, incremental saves.
9. Wrap all new APIs in `if #available(iOS 27, *)` or `@available(anyAppleOS 27, *)` when supporting older OS versions.
