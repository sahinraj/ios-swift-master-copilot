# Platform Integration

## Contents
1. UIKit and AppKit interop
2. App lifecycle and scenes
3. Background execution
4. Notifications
5. Widgets, Live Activities, Controls
6. App Intents, Shortcuts, Siri, Spotlight
7. Foundation Models and Apple Intelligence
8. Location, maps, sensors
9. Files, documents, sharing
10. StoreKit, TipKit, other frameworks
11. Extensions and app groups

---

## 1. UIKit and AppKit interop
Embed UIKit in SwiftUI:
```swift
struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document !== document { view.document = document }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, PDFViewDelegate { }
}
```
- `updateUIView` runs often: compare before assigning to avoid resetting state.
- Coordinators handle delegates and target-action; pass bindings into the coordinator via `context.coordinator.parent = self` in `update`.
- `sizeThatFits(_:uiView:context:)` for custom sizing.
- `UIViewControllerRepresentable` for controllers (camera, document picker, mail compose).
- `UIGestureRecognizerRepresentable` (iOS 18) for UIKit gestures in SwiftUI.

Embed SwiftUI in UIKit:
- `UIHostingController(rootView:)`; `sizingOptions = .intrinsicContentSize` for auto-sizing.
- `UIHostingConfiguration { }` for collection/table view cells.
- Observation works in UIKit (iOS 26+ automatic observation tracking in `layoutSubviews`/`updateProperties` style methods); on earlier versions use `withObservationTracking` or `Observations`.
- `UIKit` apps adopting resizable iPhone windows (iOS 27): use trait collections and scene geometry, not `UIScreen.main.bounds`.

AppKit: `NSViewRepresentable`, `NSHostingView`, `NSHostingController`.

## 2. App lifecycle and scenes
- SwiftUI `App` lifecycle with `@Environment(\.scenePhase)`: `.active`, `.inactive`, `.background`. Save state on `.background`.
- UIKit scene-based lifecycle (`UISceneDelegate`) is required for multi-window iPad; SwiftUI handles it for you.
- `@UIApplicationDelegateAdaptor(AppDelegate.self)` for push token registration, background URL session events, third-party SDK hooks.
- State restoration: `@SceneStorage`, `NavigationPath.codable`, `NSUserActivity`.
- Multiple windows: `WindowGroup(for: Trip.ID.self) { $id in }` + `@Environment(\.openWindow)`.

## 3. Background execution
- `BGTaskScheduler` with `BGAppRefreshTask` (short refresh) and `BGProcessingTask` (long, can require power/network). Register identifiers in Info.plist `BGTaskSchedulerPermittedIdentifiers`.
- SwiftUI: `.backgroundTask(.appRefresh("sync")) { await sync() }`.
- `BGContinuedProcessingTask` (iOS 26) for user-initiated work that continues after backgrounding with progress UI.
- Background `URLSession` (`URLSessionConfiguration.background`) for large uploads/downloads that must finish.
- `beginBackgroundTask` for finishing a short critical operation (always end it).
- Silent push (`content-available`) is best effort and throttled.
- Never assume background time; make sync resumable and idempotent.

## 4. Notifications
- `UNUserNotificationCenter`: request authorization at a meaningful moment, not at launch.
- Categories and actions for actionable notifications; handle in `UNUserNotificationCenterDelegate` (`nonisolated` methods under Swift 6, then hop to MainActor).
- Time-sensitive and critical alerts need entitlements and justification.
- Remote push: register via app delegate, send token to server, handle `didReceiveRemoteNotification`.
- Notification Service Extension to decrypt or enrich content.
- In-app: typed `NotificationCenter` messages (Foundation, 2025+) replace stringly-typed `Notification.Name` + `userInfo` for new code.

## 5. Widgets, Live Activities, Controls
- WidgetKit `TimelineProvider`/`AppIntentTimelineProvider`, `TimelineEntry`, `.containerBackground(for: .widget)`.
- Interactive widgets: `Button(intent:)`, `Toggle(isOn:intent:)` with App Intents.
- Share data via app group + SwiftData/UserDefaults(suiteName:). Reload with `WidgetCenter.shared.reloadTimelines(ofKind:)`.
- Live Activities: ActivityKit `ActivityAttributes`, `Activity.request`, push updates; Dynamic Island layouts.
- Control Center / Lock Screen controls: `ControlWidget` with `ControlWidgetButton`/`ControlWidgetToggle` (iOS 18).
- Keep widget views lightweight; no network calls in views.

## 6. App Intents, Shortcuts, Siri, Spotlight
```swift
struct ShowNextTripIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Next Trip"
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trip = try await TripService.shared.nextTrip()
        return .result(dialog: "Your next trip is \(trip.number).")
    }
}

struct OpsShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: ShowNextTripIntent(), phrases: ["Show my next trip in \(.applicationName)"],
                    shortTitle: "Next Trip", systemImageName: "airplane")
    }
}
```
- `AppEntity` + `EntityQuery` expose your data to Shortcuts, Siri, Spotlight and Apple Intelligence.
- `IndexedEntity` and Core Spotlight for search.
- Assistant schemas and interactive snippets expand intents into system experiences; follow current App Intents docs for the SDK you target.
- Intents are the integration point for widgets, controls, Action button, Siri and Visual Intelligence.

## 7. Foundation Models and Apple Intelligence
On-device LLM (iOS 26+, Apple Intelligence enabled devices):
```swift
import FoundationModels

@Generable
struct BriefingSummary {
    @Guide(description: "One sentence overview") var headline: String
    @Guide(description: "Up to three key risks", .count(3)) var risks: [String]
}

func summarize(_ notes: String) async throws -> BriefingSummary {
    guard case .available = SystemLanguageModel.default.availability else {
        throw SummaryError.modelUnavailable
    }
    let session = LanguageModelSession(instructions: "Summarize operational notes factually. Do not invent data.")
    let response = try await session.respond(to: notes, generating: BriefingSummary.self)
    return response.content
}
```
- Check `availability` and design a fallback (device not eligible, Apple Intelligence off, model not ready).
- `@Generable` + `@Guide` for structured output (guided generation). Streaming with `streamResponse`.
- Tool calling with the `Tool` protocol.
- Context window is limited; chunk long inputs.
- Never use generated text for safety-critical decisions without human verification; label AI output clearly.
- Other ML: Core ML, Create ML, Vision, Natural Language, Speech (`SpeechAnalyzer` iOS 26), Translation framework, Image Playground.

## 8. Location, maps, sensors
- Core Location async APIs: `CLLocationUpdate.liveUpdates()`, `CLMonitor` for region/condition monitoring, `CLServiceSession` for authorization scoping (iOS 18).
- Request the minimum authorization level; explain purpose strings clearly.
- MapKit for SwiftUI: `Map(position: $position) { Marker(...); Annotation(...); MapPolyline(...) }`, `MapCameraPosition`, `mapControls`, `MKLocalSearch`, `MKMapItem.Identifier`.
- Motion: Core Motion `CMMotionManager` with `OperationQueue` bridge into `AsyncStream`.
- Bluetooth/accessories: Core Bluetooth, AccessorySetupKit (iOS 18) for privacy-friendly pairing.

## 9. Files, documents, sharing
- `fileImporter`/`fileExporter` modifiers; security-scoped URLs (`startAccessingSecurityScopedResource`).
- `DocumentGroup` document apps; the 2027 Document API (`ReadableDocument`/`WritableDocument`) for new doc apps targeting 27.
- `ShareLink(item:)` with `Transferable` types.
- `FileManager` app container locations: Documents (user-visible if enabled), Application Support (app data), Caches (purgeable), tmp.
- Data protection classes on files (see networking-security-privacy.md).
- `QuickLook` previews via `.quickLookPreview($url)`.

## 10. StoreKit, TipKit, other frameworks
- StoreKit 2: `Product.products(for:)`, `product.purchase()`, `Transaction.updates`, `SubscriptionStoreView`, `StoreView`.
- TipKit: `Tip` types, `TipView`, `.popoverTip`, rules and events; `Tips.configure()` at launch.
- PassKit, HealthKit, EventKit, Contacts, PhotosUI (`PhotosPicker`), AVFoundation/AVKit (`VideoPlayer`), Vision, VisionKit (`DataScannerViewController`), PDFKit, WebKit (`WebView` iOS 26), Charts, GameKit, CryptoKit, Network framework.

## 11. Extensions and app groups
- Share code via frameworks/packages, data via app groups, secrets via shared Keychain access groups.
- Extensions have tight memory limits; avoid loading full app stacks.
- Communicate changes: SwiftData history (`HistoryObserver` on iOS 27), Darwin notifications, `WidgetCenter` reloads.
