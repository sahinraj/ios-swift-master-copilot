---
applyTo: "**/*.swift"
description: Swift, SwiftUI and SwiftData coding rules applied to every Swift file
---
# Swift coding rules

- Swift 6 language mode with complete concurrency checking. Check the project's deployment target, default actor isolation and approachable concurrency settings before adding annotations.
- UI code and observable stores are `@MainActor`. Heavy work goes in `@concurrent` async functions. No new `DispatchQueue` or completion-handler code.
- Handle errors inside unstructured `Task {}` blocks. Respect cancellation. Prefer `.task` and `.task(id:)` in SwiftUI.
- No force unwraps, `try!` or `as!` in production code.
- Use `@Observable` for reference state, `@State` to own it, `@Bindable` for bindings, `@Environment(Type.self)` to read shared objects.
- Extract view sections into separate `View` structs with narrow inputs. Keep `init` and `body` cheap.
- Stable `ForEach` identity. Single root view per List row. No conditional `.if` modifiers.
- Xcode 27: never give a `@State` property a default value and also assign it in `init`.
- `NavigationStack` or `NavigationSplitView` with value-based destinations.
- Gate iOS 26 and iOS 27 APIs with `#available` or `@available(anyAppleOS 27, *)` when the deployment target is lower.
- SwiftData: `@Query` in views, `@ModelActor` for background writes, versioned schemas and migration plans for shipped schema changes, never pass models across actors.
- Localize user-facing strings, format numbers and dates with `FormatStyle`, label icon-only controls, support Dynamic Type.
- Log with `Logger`, never `print`. Never log secrets.
- New tests use Swift Testing (`@Test`, `#expect`, `#require`).
- For deeper guidance, read the ios-swift-master skill references if they are present in `.github/skills/` or `~/.copilot/skills/`.
