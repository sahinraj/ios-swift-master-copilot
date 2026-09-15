# Accessibility and Localization

## Contents
1. Accessibility baseline
2. VoiceOver in SwiftUI
3. Dynamic Type and layout
4. Color, contrast, motion, transparency
5. Input methods: Voice Control, Switch Control, keyboard, pointer
6. Testing accessibility
7. Localization with String Catalogs
8. Formatting data
9. Right-to-left and pseudolocalization
10. Localization pitfalls

---

## 1. Accessibility baseline (every screen)
- Every control reachable and operable with VoiceOver, Voice Control, Full Keyboard Access and Switch Control.
- Every non-text control has a meaningful label; images are either labeled or hidden.
- Text scales with Dynamic Type up to accessibility sizes without truncating critical info.
- Minimum hit target 44x44 pt.
- Information is never conveyed by color alone.
- Motion respects Reduce Motion; transparency respects Reduce Transparency.
- Status changes are announced.

## 2. VoiceOver in SwiftUI
```swift
HStack {
    Image(systemName: "airplane.departure")
        .accessibilityHidden(true)
    VStack(alignment: .leading) {
        Text(flight.number)
        Text(flight.departure, format: .dateTime.hour().minute())
    }
    Spacer()
    StatusBadge(status: flight.status)
}
.accessibilityElement(children: .combine)
.accessibilityAddTraits(.isButton)
.accessibilityHint("Opens flight details")
.accessibilityAction(named: "Acknowledge") { acknowledge(flight) }
```
- `accessibilityLabel`, `accessibilityValue`, `accessibilityHint` (short, optional), `accessibilityIdentifier` (UI tests only, not read aloud).
- Grouping: `.accessibilityElement(children: .combine | .contain | .ignore)`.
- Traits: `.isHeader` for section titles, `.isButton`, `.isSelected`, `.updatesFrequently`.
- Custom actions: `.accessibilityAction(named:)`; swipe actions and context menus are exposed automatically.
- Adjustable controls: `.accessibilityAdjustableAction { direction in }`.
- Rotors: `.accessibilityRotor("Alerts") { ForEach(alerts) { AccessibilityRotorEntry($0.title, id: $0.id) } }`.
- Sort order: `.accessibilitySortPriority`.
- Announcements: `AccessibilityNotification.Announcement("Sync complete").post()`.
- Charts: `accessibilityLabel`/`accessibilityValue` per mark and `AXChartDescriptor` for audio graphs.
- `.accessibilityRepresentation { }` to expose a custom control as a standard one (e.g. a custom slider as `Slider`).
- `Label` and `Button("Title", systemImage:)` provide labels automatically; icon-only buttons still need `labelStyle(.iconOnly)` with a real title.

## 3. Dynamic Type and layout
- Use text styles (`.body`, `.headline`) or `Font.custom(_:size:relativeTo:)`.
- `@ScaledMetric(relativeTo: .body) private var iconSize = 24` for non-text dimensions.
- Switch layouts at large sizes:
```swift
@Environment(\.dynamicTypeSize) private var typeSize
var body: some View {
    let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading)) : AnyLayout(HStackLayout())
    layout { Label(title, systemImage: icon); Spacer(); Text(value) }
}
```
- Or `ViewThatFits`.
- Avoid fixed heights on text containers. Allow wrapping (`lineLimit(nil)`), use `fixedSize(horizontal: false, vertical: true)` where needed.
- `dynamicTypeSize(...DynamicTypeSize.accessibility2)` to cap only where layout truly cannot adapt (tab bars, compact badges), never for body content.

## 4. Color, contrast, motion, transparency
- Semantic colors adapt to Dark Mode and Increase Contrast. Custom asset colors need high-contrast variants.
- Target WCAG AA contrast (4.5:1 body text, 3:1 large text and UI components).
- `@Environment(\.colorSchemeContrast)`, `\.accessibilityDifferentiateWithoutColor` (add shapes/icons), `\.accessibilityReduceMotion`, `\.accessibilityReduceTransparency`, `\.accessibilityInvertColors` (mark photos `.accessibilityIgnoresInvertColors()`).
- Replace motion with fades when Reduce Motion is on.

## 5. Input methods
- Voice Control uses labels; keep them short and match visible text. Provide `.accessibilityInputLabels(["Sync", "Refresh"])` for alternatives.
- Full Keyboard Access and hardware keyboards: focusable controls, `.keyboardShortcut`, `.focusable()`, `onKeyPress`.
- Pointer on iPad/Mac: `.hoverEffect(.highlight)`, `.pointerStyle`.
- Large hit targets: `.contentShape(.rect)` and padding.

## 6. Testing accessibility
- Accessibility Inspector (Xcode > Open Developer Tool) with Audit.
- Xcode Previews: Dynamic Type variants, Dark Mode, Increase Contrast.
- XCUITest: `try app.performAccessibilityAudit()` (iOS 17+) with filters for known issues.
- Manual passes with VoiceOver and Voice Control on device for critical flows.

## 7. Localization with String Catalogs
- String Catalogs (`.xcstrings`) extract strings automatically from `Text("...")`, `String(localized:)`, `LocalizedStringResource`, `Button("...")`, `navigationTitle("...")`.
- SwiftUI literal strings are `LocalizedStringKey`. Variables passed as `String` are **not** localized; use `Text(verbatim:)` for non-localized strings and `LocalizedStringKey(variable)` only when the variable is a key.
- Comments for translators: `Text("Gate", comment: "Airport gate label on boarding card")`, `String(localized: "Gate", comment: "...")`.
- Interpolation creates format specifiers: `Text("\(count) legs remaining")`. Configure plural variants in the catalog (vary by plural, device).
- Tables: `String(localized: "Title", table: "Settings")`.
- Packages and frameworks: pass the bundle (`bundle: .module`) or use `#bundle`.
- `LocalizedStringResource` for App Intents, widgets, notifications and deferred localization.
- Grammatical agreement: `AttributedString(localized: "^[\(count) leg](inflect: true)")` for languages that support automatic inflection.
- Export/import `.xcloc` for translators; Xcode can generate state tracking (new, needs review, translated, stale).

## 8. Formatting data
Never hand-format user-visible numbers, dates, measurements or lists.
```swift
Text(fuel, format: .number.precision(.fractionLength(0)))
Text(price, format: .currency(code: "USD"))
Text(departure, format: .dateTime.weekday().day().month().hour().minute())
Text(Measurement(value: altitude, unit: UnitLength.feet), format: .measurement(width: .abbreviated))
Text(duration, format: .units(allowed: [.hours, .minutes], width: .abbreviated))
Text(crewNames, format: .list(type: .and))
Text(ratio, format: .percent)
Text(departure, style: .relative)
```
- Honor `\.locale`, `\.calendar`, `\.timeZone` environment values. For operational apps that must show UTC or station local time, format with an explicit `TimeZone` and label it.
- Parse user input with format styles: `try Double("1,234.5", format: .number)` or `TextField(value:format:)`.
- ISO 8601 for data interchange (`Date.ISO8601FormatStyle`), never localized formats in APIs.

## 9. Right-to-left and pseudolocalization
- Use leading/trailing, not left/right. SwiftUI mirrors automatically.
- Flip directional images: `Image(systemName: "chevron.forward")` or `.flipsForRightToLeftLayoutDirection(true)`.
- Test with Right-to-Left Pseudolanguage and Double-Length Pseudolanguage in scheme options or preview variants.

## 10. Localization pitfalls
- Concatenating localized fragments (`"Hello " + name`). Use one interpolated string.
- Using `String` variables in `Text` and expecting localization.
- Hard-coded date formats (`"MM/dd/yyyy"`) for display.
- Assuming plural rules like English.
- Text in images.
- Truncation in German/Finnish; test double-length.
- Logging localized strings for analytics; log keys or enums instead.
