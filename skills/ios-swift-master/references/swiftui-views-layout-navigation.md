# SwiftUI Views, Layout, Navigation

## Contents
1. View composition
2. Layout system
3. Stacks, grids, containers
4. Lists, forms, tables
5. Scrolling
6. Navigation
7. Presentation (sheets, alerts, popovers, inspectors)
8. Tabs and toolbars
9. Text, images, symbols, colors
10. Controls and input, focus
11. Gestures and drag and drop
12. Animation and transitions
13. Custom layouts, Canvas, shapes, graphics
14. Adaptivity: size classes, resizable iPhone apps, iPad, Mac, visionOS
15. Previews
16. Modifier order and styling APIs
17. Soft-deprecated to modern mapping

---

## 1. View composition
- A `View` is a lightweight description. `body` must be cheap and side-effect free.
- Extract subviews into `struct`s with narrow inputs. Use `@ViewBuilder` functions only for tiny, non-stateful helpers.
- Custom reusable styling: `ViewModifier` + `extension View { func cardStyle() -> some View }`, or `ButtonStyle`, `LabelStyle`, `ToggleStyle` for controls.
- Container views taking content: `struct Card<Content: View>: View { @ViewBuilder var content: Content }`.
- iOS 18+ custom containers: `ForEach(subviews: content) { subview in }`, `Group(subviews: content) { subviews in }`, container values with `@Entry` in `ContainerValues`.
- `EquatableView` / `.equatable()` only when profiling shows benefit.

## 2. Layout system
- Parent proposes a size, child chooses its size, parent places the child. Modifiers wrap views and participate in this negotiation.
- `frame(width:height:alignment:)` proposes fixed sizes; `frame(minWidth:maxWidth:...)` flexible; `maxWidth: .infinity` fills.
- `fixedSize(horizontal:vertical:)`, `layoutPriority(_:)`, `.fixedSize()` to stop truncation.
- `padding`, `safeAreaInset(edge:)` for bars that push content, `safeAreaPadding`, `ignoresSafeArea(_:edges:)`, `contentMargins(_:for:)`.
- `containerRelativeFrame(.horizontal, count:span:spacing:)` for paging and grid sizing without `GeometryReader`.
- `GeometryReader` is a last resort: it takes all proposed space and forces layout reads. Prefer `onGeometryChange(for:of:action:)` (iOS 18) to read a single value, or `containerRelativeFrame`, `ViewThatFits`, custom `Layout`.
- `ViewThatFits(in: .horizontal) { WideLayout(); CompactLayout() }` picks the first that fits.
- Alignment guides: `alignmentGuide(.leading) { d in d[.leading] }`, custom `HorizontalAlignment`.
- `AnyLayout(isCompact ? AnyLayout(VStackLayout()) : AnyLayout(HStackLayout()))` switches layout while preserving identity.

## 3. Stacks, grids, containers
- `HStack`, `VStack`, `ZStack` with `alignment` and `spacing`. `Spacer(minLength:)`.
- Lazy stacks inside `ScrollView`: `LazyVStack`, `LazyHStack` with `pinnedViews: [.sectionHeaders]`.
- Grids: `Grid { GridRow { } }` for static aligned tables; `LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))])` for large collections.
- `Group`, `Section`, `ControlGroup`, `DisclosureGroup`, `GroupBox`, `LabeledContent`.
- `ContentUnavailableView("No Results", systemImage: "magnifyingglass", description: Text("..."))`, `.search` variant.
- 2027 SDK: any container can support drag-to-reorder with `.reorderable()` and `.reorderContainer(for:)` (see swiftui-ios26-ios27-new.md).

## 4. Lists, forms, tables
```swift
List(selection: $selection) {
    Section("Upcoming") {
        ForEach(trips) { trip in
            TripRow(title: trip.title, departure: trip.departure)
                .swipeActions(edge: .trailing) {
                    Button("Delete", role: .destructive) { store.delete(trip.id) }
                }
        }
        .onDelete { store.delete(at: $0) }
        .onMove { store.move(from: $0, to: $1) }
    }
}
.listStyle(.insetGrouped)
```
- Rows should be a single top-level view so List can compute identity cheaply. Wrap branching rows in a container.
- Filter data before `ForEach`; do not return `EmptyView` for hidden rows.
- `Form` for settings and data entry, with `Section`, `LabeledContent`, `Picker`, `Toggle`, `Stepper`, `DatePicker`.
- `Table` (iPadOS/macOS) with `TableColumn`, sorting via `sortOrder: $sortOrder` and `KeyPathComparator`, selection, `contextMenu(forSelectionType:)`.
- `OutlineGroup` / `List(children:)` for hierarchies.
- `.refreshable { await store.reload() }`, `.searchable(text:placement:prompt:)`, `.searchSuggestions`, `.searchScopes`.
- Swipe actions work outside `List` in the 2027 SDK when the scroll container has `.swipeActionsContainer()`.

## 5. Scrolling
- `ScrollView(.vertical)` + lazy stack for custom lists.
- Programmatic scrolling (iOS 17/18): `@State private var position = ScrollPosition(idType: Item.ID.self)` with `.scrollPosition($position)`, then `position.scrollTo(id:)`, `scrollTo(edge: .bottom)`. Mark content with `.scrollTargetLayout()`.
- `ScrollViewReader` + `proxy.scrollTo(id, anchor:)` for older targets.
- Paging and snapping: `.scrollTargetBehavior(.paging)` or `.viewAligned`.
- Observe: `onScrollGeometryChange(for:of:action:)`, `onScrollVisibilityChange(threshold:)`, `onScrollPhaseChange`.
- `scrollIndicators(.hidden)`, `scrollDismissesKeyboard(.interactively)`, `scrollBounceBehavior(.basedOnSize)`, `defaultScrollAnchor(.bottom)` for chat-like UIs.
- Liquid Glass: `scrollEdgeEffectStyle(_:for:)` (iOS 26) to tune edge blur under bars.
- `scrollClipDisabled()` when shadows get clipped.

## 6. Navigation
Value-based stack with typed routes:
```swift
enum Route: Hashable {
    case trip(Trip.ID)
    case crew(CrewMember.ID)
    case settings
}

@MainActor @Observable final class Router {
    var path: [Route] = []
    func show(_ route: Route) { path.append(route) }
    func popToRoot() { path.removeAll() }
}

struct AppNavigation: View {
    @State private var router = Router()
    var body: some View {
        NavigationStack(path: $router.path) {
            HomeView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .trip(let id): TripDetailScreen(tripID: id)
                    case .crew(let id): CrewScreen(crewID: id)
                    case .settings: SettingsScreen()
                    }
                }
        }
        .environment(router)
    }
}
```
- `NavigationLink(value:)` inside the stack; destinations registered once near the root, not inside lazy containers.
- `NavigationPath` for heterogeneous paths; it is `Codable` via `path.codable` for state restoration.
- `NavigationSplitView` for iPad/Mac with `columnVisibility`, `preferredCompactColumn`, `navigationSplitViewStyle(.balanced)`. It collapses to a stack on compact width.
- `navigationDestination(item:)` and `navigationDestination(isPresented:)` for programmatic pushes from state.
- Titles: `navigationTitle`, `navigationSubtitle` (iOS 26), `navigationBarTitleDisplayMode(.inline)`, `toolbarTitleMenu`.
- Zoom transitions (iOS 18): `.navigationTransition(.zoom(sourceID: id, in: namespace))` on destination + `.matchedTransitionSource(id: id, in: namespace)` on source.
- Deep links: `.onOpenURL { url in router.handle(url) }`, universal links, `NSUserActivity` via `.onContinueUserActivity`.
- Do not nest `NavigationStack`s. Each tab owns one stack.

## 7. Presentation
- Sheets: `.sheet(item: $selectedTrip) { trip in }` preferred over `isPresented` + separate optional. `.fullScreenCover`, `.popover(item:)`.
- Detents: `.presentationDetents([.medium, .large])`, `.presentationDragIndicator(.visible)`, `.presentationBackgroundInteraction(.enabled(upThrough: .medium))`, `.presentationSizing(.form)` (iOS 18), `.interactiveDismissDisabled(hasChanges)`.
- Alerts and dialogs: `.alert("Title", isPresented:actions:message:)`; 2027 SDK adds `item:` overloads for `.alert` and `.confirmationDialog` so one optional drives presentation and value.
- `.inspector(isPresented:) { }` for trailing panels (iPad/Mac), sheet on compact iPhone.
- `.contextMenu { } preview: { }`, `.menuActionDismissBehavior`.
- `dismiss` via `@Environment(\.dismiss)`.
- Error presentation: store an `Error?`/`LocalizedError?` in state and present with `alert(isPresented:error:)` or the item-based API.

## 8. Tabs and toolbars
```swift
TabView(selection: $tab) {
    Tab("Schedule", systemImage: "calendar", value: .schedule) { ScheduleView() }
    Tab("Bids", systemImage: "list.number", value: .bids) { BidsView() }
    Tab(value: .search, role: .search) { SearchView() }
}
.tabViewStyle(.sidebarAdaptable)
```
- iOS 18 `Tab` API with `TabSection` for sidebar groups; `tabViewCustomization` for user-customizable tabs.
- Liquid Glass (iOS 26): `tabBarMinimizeBehavior(.onScrollDown)`, `tabViewBottomAccessory { }`.
- 2027 SDK: `Tab(role: .prominent)` places a distinguished tab at the trailing edge.
- Toolbars:
```swift
.toolbar {
    ToolbarItem(placement: .topBarLeading) { EditButton() }
    ToolbarItemGroup(placement: .primaryAction) { SaveButton(); ShareButton() }
    ToolbarItem(placement: .bottomBar) { StatusLabel() }
}
```
- Placements: `.primaryAction`, `.cancellationAction`, `.confirmationAction`, `.destructiveAction`, `.topBarLeading`, `.topBarTrailing`, `.bottomBar`, `.keyboard`, `.status`, `.principal`.
- iOS 26: `ToolbarSpacer(.fixed)` groups glass items, `.sharedBackgroundVisibility(.hidden)` separates an item.
- 2027 SDK: `.visibilityPriority(.high)`, `ToolbarOverflowMenu { }`, `.topBarPinnedTrailing`, `.toolbarMinimizeBehavior(.onScrollDown, for: .navigationBar)`, `ForEach` inside toolbar builders.
- `.toolbarBackground`, `.toolbarVisibility(.hidden, for: .tabBar)`, `.toolbarRole(.editor)`.

## 9. Text, images, symbols, colors
- `Text` supports Markdown in literals, `AttributedString`, formatting (`Text(amount, format: .currency(code: "USD"))`), `Text(date, style: .relative)`, `Text(timerInterval:)`.
- Fonts: semantic styles (`.body`, `.headline`, `.largeTitle`), `.font(.system(.title2, design: .rounded, weight: .semibold))`. Custom fonts with `Font.custom(_:size:relativeTo:)` to scale with Dynamic Type.
- `lineLimit(2, reservesSpace: true)`, `truncationMode`, `minimumScaleFactor` (use sparingly), `multilineTextAlignment`, `textSelection(.enabled)`, `monospacedDigit()`.
- `TextEditor` supports `AttributedString` rich editing (iOS 26).
- Images: `Image("asset")`, `Image(systemName:)` with `symbolRenderingMode(.hierarchical)`, `symbolVariant(.fill)`, `symbolEffect(.bounce, value: count)`, `contentTransition(.symbolEffect(.replace))`.
- `.resizable().scaledToFit()` / `.aspectRatio(contentMode: .fill)` + `.clipped()`.
- `AsyncImage(url:)` with phases; in the 2027 SDK it honors HTTP caching by default and accepts `URLRequest` and a custom session.
- Large local images: downsample with ImageIO before display; do not load full-resolution photos into lists.
- Colors: semantic (`.primary`, `.secondary`, `.tint`, `Color(.systemBackground)`), asset catalog colors with light/dark variants. `foregroundStyle(.secondary)`, hierarchical styles `.tertiary`.
- Materials: `.background(.regularMaterial)`; Liquid Glass surfaces use `glassEffect` (iOS 26).
- Gradients: `LinearGradient`, `.gradient` on colors, `MeshGradient` (iOS 18).

## 10. Controls, input, focus
- `Button(action:label:)`, `Button("Title", systemImage:role:action:)`, `buttonStyle(.bordered | .borderedProminent | .plain | .glass | .glassProminent)`, `controlSize`, `buttonBorderShape`.
- `Toggle`, `Picker` (`.segmented`, `.menu`, `.wheel`, `.navigationLink`, `.palette`), `DatePicker`, `MultiDatePicker`, `Slider`, `Stepper`, `ColorPicker`, `PhotosPicker`, `ShareLink`, `PasteButton`, `Menu`, `Gauge`, `ProgressView`.
- Text input: `TextField("Label", text:, prompt:)`, `axis: .vertical` for growing fields, `SecureField`, `.textContentType`, `.keyboardType`, `.submitLabel`, `.onSubmit`, `.autocorrectionDisabled()`, `.textInputAutocapitalization(.never)`.
- Formatted input: `TextField("Fuel", value: $fuel, format: .number)`.
- Focus:
```swift
enum Field: Hashable { case callsign, altitude }
@FocusState private var focus: Field?

TextField("Callsign", text: $callsign).focused($focus, equals: .callsign)
    .onSubmit { focus = .altitude }
```
- `defaultFocus`, `focusSection()` (tvOS/macOS), `.focusable()`, `onKeyPress` for hardware keyboards.
- Keyboard shortcuts on iPad/Mac: `.keyboardShortcut("s", modifiers: .command)`.
- Sensory feedback: `.sensoryFeedback(.success, trigger: savedCount)`.

## 11. Gestures and drag and drop
- `onTapGesture(count:)`, `onLongPressGesture`, `DragGesture`, `MagnifyGesture`, `RotateGesture`, `SpatialTapGesture`.
- Compose with `.simultaneously(with:)`, `.sequenced(before:)`, `.exclusively(before:)`; attach with `.gesture`, `.simultaneousGesture`, `.highPriorityGesture`.
- Track in-flight values with `@GestureState` (resets automatically).
- Prefer `Button` over `onTapGesture` for anything actionable (accessibility, hit testing, keyboard).
- `contentShape(.rect)` to expand hit areas.
- Drag and drop: `Transferable` types with `.draggable(item)` and `.dropDestination(for:action:isTargeted:)`. The 2027 SDK adds `dragContainer(for:)` and per-child `dropDestination(for:isEnabled:)` alongside reorder containers.
- UIKit-style pan/pinch interop via `UIGestureRecognizerRepresentable` (iOS 18).

## 12. Animation and transitions
- Implicit: `.animation(.snappy, value: isExpanded)` scoped to a value. Never use `.animation(_:)` without `value:`.
- Explicit: `withAnimation(.spring(duration: 0.35, bounce: 0.2)) { isExpanded.toggle() }`, completion `withAnimation(_:completionCriteria:_:completion:)`.
- Presets: `.smooth`, `.snappy`, `.bouncy`, `.spring`, `.easeInOut`, `.linear`.
- Transitions: `.transition(.move(edge: .bottom).combined(with: .opacity))`, `.asymmetric`, `.push(from:)`, custom `Transition` protocol (iOS 17).
- `matchedGeometryEffect(id:in:)` for shared element animation within one hierarchy.
- `phaseAnimator`, `keyframeAnimator` for multi-step animations.
- `contentTransition(.numericText(value:))` for changing numbers.
- `@Animatable` macro (iOS 26) synthesizes `animatableData` for custom shapes and modifiers; mark non-animated stored properties `@AnimatableIgnored`. Implement `animatableData` manually for older targets.
- Respect `accessibilityReduceMotion`: swap spatial animations for fades.
- `CustomAnimation` protocol for bespoke timing curves.

## 13. Custom layouts and graphics
- `Layout` protocol: implement `sizeThatFits(proposal:subviews:cache:)` and `placeSubviews(in:proposal:subviews:cache:)`. Use for flow layouts, radial menus, calendar grids.
- `Canvas { context, size in }` for thousands of drawn elements (charts, maps, overlays); `TimelineView(.animation)` for continuous redraw.
- Shapes: `Rectangle`, `RoundedRectangle(cornerRadius:style: .continuous)`, `Capsule`, `Circle`, `UnevenRoundedRectangle`, `ConcentricRectangle` (iOS 26), custom `Shape` with `path(in:)`.
- `.clipShape(.rect(cornerRadius: 12))`, `.containerShape`, `.mask`.
- Visual effects: `.shadow`, `.blur`, `.visualEffect { content, proxy in }`, Metal shaders `.colorEffect`, `.distortionEffect`, `.layerEffect` with `ShaderLibrary`.
- `drawingGroup()` flattens complex vector hierarchies into a single Metal layer; measure before using.
- Swift Charts: `Chart { LineMark(...) }`, `BarMark`, `PointMark`, `AreaMark`, `RuleMark`, `SectorMark`, `chartXSelection`, `chartScrollableAxes`, `Chart3D` (iOS 26), accessibility via `accessibilityLabel` and audio graphs.

## 14. Adaptivity
- Use `horizontalSizeClass` and container size, not `UIDevice.current.userInterfaceIdiom`, to choose layouts.
- iPhone apps become resizable on iOS 27 (iPhone Mirroring, iPhone apps on iPad). Test with resize handles in Xcode 27 Live Previews.
- iPadOS windowing: support any size, multiple windows (`WindowGroup(for: Trip.ID.self)` + `openWindow(value:)`), `.windowResizability`, pointer hover (`.hoverEffect`, `onContinuousHover`), keyboard shortcuts, menu bar commands (`.commands { CommandMenu("Flight") { } }`).
- In the 2027 SDK iPad/Mac menu bars show a minimal set of icons by default; opt specific items into icons with `.labelStyle(.titleAndIcon)`.
- macOS: `Settings` scene, `MenuBarExtra`, `.windowStyle`, `.windowToolbarStyle`, `openSettings`, Table-first UIs.
- visionOS: `ImmersiveSpace`, `RealityView`, ornaments (`.ornament`), `glassBackgroundEffect`, volumetric windows.
- watchOS: `NavigationStack`, `TabView(.verticalPage)`, `digitalCrownRotation`, complications with WidgetKit.

## 15. Previews
```swift
#Preview("Loaded") {
    TripListView()
        .environment(TripStore.preview(state: .loaded))
        .modelContainer(PreviewData.container)
}

#Preview("Toggle", traits: .sizeThatFitsLayout) {
    @Previewable @State var isOn = true
    SettingRow(title: "Notify", isOn: $isOn)
}
```
- Every preview is self-contained: in-memory SwiftData container, fake services, no network.
- `PreviewModifier` (iOS 18) to share expensive preview setup across previews.
- Traits: `.landscapeLeft`, `.sizeThatFitsLayout`, `.fixedLayout(width:height:)`.
- Preview Dark Mode, large Dynamic Type, right-to-left and pseudolanguages using the canvas variants.
- Xcode 27 Live Previews support interactive resize handles.

## 16. Modifier order and styling APIs
- Order matters: `padding().background()` differs from `background().padding()`. Frame before background to size the background.
- Apply `.accessibilityElement(children:)` and labels after composition.
- Put `.task`, `.onChange`, `.sheet` on stable parents, not on views that appear and disappear rapidly.
- Styles propagate: set `.buttonStyle`, `.toggleStyle`, `.tint`, `.font` on containers to affect descendants.

## 17. Soft-deprecated to modern mapping
| Old | Modern |
|---|---|
| `NavigationView` | `NavigationStack` / `NavigationSplitView` |
| `NavigationLink(destination:isActive:)` | `navigationDestination(isPresented:)` / value links |
| `foregroundColor(_:)` | `foregroundStyle(_:)` |
| `cornerRadius(_:)` | `clipShape(.rect(cornerRadius:))` |
| `onChange(of:perform:)` single-param closure | `onChange(of:initial:_:)` with `(old, new)` or no params |
| `.animation(_:)` without value | `.animation(_:value:)` |
| `ObservableObject` / `@Published` / `@StateObject` | `@Observable` / `@State` |
| `@EnvironmentObject` | `@Environment(Type.self)` |
| `EnvironmentKey` boilerplate | `@Entry` |
| `PreviewProvider` | `#Preview` |
| `tabItem` | `Tab` |
| `actionSheet` | `confirmationDialog` |
| `alert(isPresented:content:)` with `Alert` | `alert(_:isPresented:actions:message:)` |
| `statusBarHidden(_:)` (iOS) | `ToolbarPlacement.statusBar` visibility (2027 SDK) |
| `FileDocument` / `ReferenceFileDocument` for new doc apps targeting 27 | `ReadableDocument` / `WritableDocument` |
| `MagnificationGesture` / `RotationGesture` | `MagnifyGesture` / `RotateGesture` |
| `edgesIgnoringSafeArea` | `ignoresSafeArea` |
| `accentColor` | `tint` |

Only change soft-deprecated calls when the user asks or when you are already editing that code. Otherwise mention them.
