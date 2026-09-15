# Enterprise and Field iPad Apps (offline-first, managed, regulated)

For apps used in operations, aviation, logistics, healthcare or field service where connectivity is unreliable, devices are managed, and correctness and auditability matter more than novelty.

## Contents
1. Design priorities
2. Offline-first data architecture
3. Sync engine patterns
4. Managed devices and configuration
5. Identity and session handling on shared devices
6. Audit trails and data integrity
7. Reliability engineering
8. Time, time zones and units
9. iPad productivity UX
10. Release and change management
11. Review checklist for safety-relevant features

---

## 1. Design priorities
1. Correct data shown with clear freshness and source.
2. Works offline; degrades predictably.
3. Never loses user input.
4. Fast to glance at in bright light, gloves, turbulence or vibration: large targets, high contrast, minimal steps.
5. Traceable: who changed what and when.
6. Deterministic behavior across app updates (migrations tested, feature flags controlled).

## 2. Offline-first data architecture
- Local store (SwiftData or Core Data) is the source of truth for the UI.
- Network updates write into the store; views observe the store (`@Query`, `ResultsObserver`).
- User mutations write locally first, then go to an outbox for upload.
- Every record carries: server ID (if known), local ID, `updatedAt` (server time), `lastSyncedAt`, `syncState` (`pending`, `synced`, `conflict`, `failed`).
- Show freshness: "Schedule updated 12 min ago" and a stale-data banner past a threshold.
- Reference data (airports, aircraft types, regulations) shipped or downloaded as versioned bundles, stored read-only in a separate `ModelConfiguration`.

## 3. Sync engine patterns
```swift
@globalActor actor SyncActor { static let shared = SyncActor() }

@SyncActor
final class SyncEngine {
    enum Phase: Sendable, Equatable { case idle, pulling, pushing, failed(String) }

    private let container: ModelContainer
    private let api: APIClient
    private var isRunning = false

    init(container: ModelContainer, api: APIClient) {
        self.container = container
        self.api = api
    }

    func run(reason: String) async {
        guard !isRunning else { return }       // single flight
        isRunning = true
        defer { isRunning = false }
        do {
            try await pushOutbox()
            try await pullChanges()
        } catch is CancellationError {
            return
        } catch {
            // record failure state, schedule retry with backoff
        }
    }

    private func pushOutbox() async throws { /* read pending changes via history or outbox table, send idempotent requests */ }
    private func pullChanges() async throws { /* fetch since server cursor, upsert with context.author = "Server" */ }
}
```
- Pull with a server cursor/ETag; push with idempotency keys.
- Upsert by natural key; never blindly insert.
- Use SwiftData persistent history with authors ("App", "Server", "Widget") and `HistoryObserver` (iOS 27) to trigger pushes only for local changes.
- Conflict policy defined per entity: server wins, client wins, field-level merge, or user resolution. Surface conflicts that affect safety-relevant data to the user.
- Triggers: app foreground, connectivity restored (`NWPathMonitor`), push notification, `BGAppRefreshTask`, manual pull-to-refresh.
- Persist sync cursors and history tokens.
- Bounded retries with exponential backoff; dead-letter failed items with visible status.

## 4. Managed devices and configuration
- Managed App Configuration: read MDM-provided keys from `UserDefaults.standard.dictionary(forKey: "com.apple.configuration.managed")`; observe `UserDefaults.didChangeNotification`. Provide safe defaults and validate every value.
- Feedback to MDM via `com.apple.feedback.managed` key where supported.
- Per-app VPN, Extensible Enterprise SSO, managed Keychain/certificates are configured via MDM; the app should not hard-code environment assumptions.
- Declarative Device Management and managed Apple Accounts affect data separation; test with managed and personal accounts on the same device if supported by policy.
- Single App Mode / Autonomous Single App Mode for kiosk deployments (`UIAccessibility.requestGuidedAccessSession`).
- Distribution: Apple Business Manager custom apps or Enterprise Program in-house distribution per organization policy.

## 5. Identity and session handling on shared devices
- Short-lived sessions with inactivity timeout; re-auth with biometrics or SSO.
- On sign-out: wipe user-scoped stores, Keychain items, caches, URLCache, cookies, pending notifications.
- Shared iPad: per-user data separation; never mix user data in a single store without a user key in every record.
- Hide sensitive screens in app switcher snapshots.

## 6. Audit trails and data integrity
- Append-only audit log for safety-relevant actions: actor, action, entity, before/after values, device, app version, timestamp (UTC), reason.
- Store locally, upload through the same outbox with integrity (hash chain or server acknowledgments).
- Validate inputs at the domain layer with explicit rules and clear error messages; do not rely on UI-only validation.
- Checksums for downloaded reference data; refuse to use corrupted bundles.
- Decimal math for quantities where rounding matters; explicit units on every numeric type.

## 7. Reliability engineering
- No force unwraps, no `try!`, no fatalError paths reachable by data.
- Crash-free sessions and hang rate as release gates (MetricKit, Organizer).
- Defensive decoding of server data (unknown enum cases, missing fields).
- Feature flags with kill switches for risky features, cached so they work offline.
- Graceful handling of storage full, low memory, and clock changes.
- Watchdog-safe launch: no synchronous network or heavy migration on the main thread; show migration progress UI.
- Extensive tests for date math, time zones, migrations and sync conflict rules.

## 8. Time, time zones and units
- Store instants as `Date` (UTC). Store local context separately (station time zone identifier).
- Display with explicit time zone and a visible label ("14:05Z", "09:05 CDT").
```swift
var utc = Date.FormatStyle(date: .omitted, time: .shortened)
utc.timeZone = .gmt
Text("\(departure, format: utc)Z")   // interpolation instead of Text + Text concatenation
```
- Use `Calendar` with explicit `timeZone` for day boundaries (duty days, pairings).
- Beware DST transitions and dateline crossings in duration calculations; use `Date` differences, not wall-clock arithmetic.
- Use `Measurement<UnitLength>`, `Measurement<UnitMass>`, etc., and convert explicitly. Never mix units in raw `Double`s.
- Server time vs device time: detect significant clock skew and warn or correct with server-provided time.

## 9. iPad productivity UX
- `NavigationSplitView` with sidebar + content + detail; keyboard shortcuts for primary actions; `.commands` menus.
- Multiple windows and Stage Manager: every screen resizable, state per scene (`@SceneStorage`).
- Drag and drop between apps (PDFs, text, images) with `Transferable`.
- Apple Pencil: PencilKit for annotations; `onPencilSqueeze`/`onPencilDoubleTap` where useful.
- Pointer and trackpad support: hover effects, context menus.
- Glanceable dashboards: large typography, color plus iconography for status, no information conveyed by color only.
- Dark mode and night-friendly palettes for low-light environments; avoid pure white full-screen flashes.
- Document viewers: PDFKit with search, annotations, and offline caching of large manuals.

## 10. Release and change management
- Semantic versioning, release notes tied to tickets.
- TestFlight internal/external groups mirroring operational roles.
- Phased rollout and ability to disable features remotely.
- Migration rehearsal on production-like data before release.
- Keep previous build available for rollback through MDM if policy allows.
- Accessibility and localization regression passes per release.

## 11. Review checklist for safety-relevant features
- [ ] Data source and freshness visible to the user.
- [ ] Behavior defined and tested offline, during sync, and after conflicts.
- [ ] No silent data loss on crash, kill, or sign-out.
- [ ] Time zones and units explicit in model and UI.
- [ ] Audit entries created for regulated actions.
- [ ] Inputs validated in the domain layer with tests.
- [ ] Feature flag and kill switch available.
- [ ] Migrations tested on real-world-sized data.
- [ ] Accessibility checked at large Dynamic Type and with VoiceOver.
- [ ] AI-generated suggestions (if any) are clearly labeled and require human confirmation.
