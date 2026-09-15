# Swift Language Reference (condensed)

Mirrors the Language Reference part of *The Swift Programming Language*: lexical structure, types, expressions, statements, declarations, attributes, patterns, generic parameters. Use this when exact syntax or rules matter.

## Contents
1. Lexical structure
2. Types
3. Expressions
4. Statements and compiler control
5. Declarations
6. Attributes (complete working list)
7. Patterns
8. Generic parameters and arguments
9. Availability cheat sheet

---

## 1. Lexical structure
- Identifiers: letters, digits, underscore, Unicode; cannot start with a digit. Escape keywords with backticks: `` `default` ``.
- Raw identifiers (Swift 6.2): any characters inside backticks, e.g. test names ``func `loads cached flights`() ``. Useful for Swift Testing function names.
- Keywords are reserved in declarations (`class`, `func`, `let`), statements (`if`, `guard`), expressions (`as`, `try`, `await`), and context-sensitive (`mutating`, `lazy`, `some`, `any`, `consume`, `borrowing`, `sending`, `nonisolated`).
- Literals: integer, floating, string (single, multiline, raw, extended delimiters), regex `/.../` and `#/.../#`, `nil`, `true`/`false`.
- Operators: custom operators from `/ = - + ! * % < > & | ^ ~ ?` plus Unicode operator characters. Whitespace around binary operators must be balanced.
- Comments `//`, `/* */` (nestable). Doc comments `///` and `/** */` with Markdown and `- Parameter`, `- Returns`, `- Throws`.
- Module selectors (Swift 6.3): `ModuleA::name` disambiguates same-named API from different imports; `Swift::Task` reaches standard library concurrency types.

## 2. Types
- Named types: structs, enums, classes, actors, protocols, type aliases.
- Compound: function types `(Int) async throws -> String`, tuple types `(x: Int, y: Int)`.
- Optional `T?`, implicitly unwrapped `T!`.
- Array `[T]`, dictionary `[K: V]`, inline array sugar `[N of T]`.
- Metatypes: `T.Type`, `P.Type` vs `any P.Type`, `type(of:)`, `.self`.
- Existentials: `any P`, `any P & Q`, `any P<Assoc>`.
- Opaque: `some P`, `some P<Assoc>` in returns and parameters.
- `Self` in protocols/classes refers to the dynamic conforming type.
- Function type attributes: `@escaping`, `@Sendable`, `@MainActor`, `@isolated(any)`, `@convention(c|block|thin)`, `@autoclosure`.
- Typed throws in function types: `() throws(E) -> Void`.
- Suppressed conformances in generic constraints: `~Copyable`, `~Escapable`.

## 3. Expressions
- Prefix/postfix/binary/ternary operators, `try`, `try?`, `try!`, `await`, `consume`, `copy`, `unsafe` (strict memory safety).
- Primary: literals, `self`, `super`, closures, implicit member `.value`, parenthesized, tuple, wildcard `_`, key-path `\Type.property`, selector `#selector`, `#keyPath`.
- Key paths: `\User.name`, `\.name` when inferred, applied with `value[keyPath:]`, usable as functions (`users.map(\.name)`), support optional chaining and subscripts.
- Macro expansion expressions: `#Predicate { }`, `#expect(...)`, `#fileID`, `#line`, `#function`, `#isolation`.
- `if` and `switch` expressions produce values (each branch a single expression, or `then`-less form).
- Postfix: function call, trailing closures, initializer `.init`, explicit member, optional chaining `?`, forced unwrap `!`, subscript.
- Literal type inference: `ExpressibleByStringLiteral`, `ExpressibleByArrayLiteral`, etc.
- `#isolation` default argument captures the caller's actor for `isolated (any Actor)? = #isolation` parameters.

## 4. Statements and compiler control
- Loops: `for-in` (with `where` clause and `case` patterns), `while`, `repeat-while`.
- Branches: `if`, `guard`, `switch` (with `where`, `fallthrough`, `@unknown default`).
- Labeled statements with `break label`, `continue label`.
- Control transfer: `break`, `continue`, `fallthrough`, `return`, `throw`.
- `defer` (async allowed in Swift 6.4 async contexts).
- `do` with `catch` clauses; `do throws(E)` for typed throws.
- Compiler control:
  - `#if DEBUG`, `#if os(iOS)`, `#if os(anyAppleOS)` (Swift 6.4), `#if arch(arm64)`, `#if canImport(UIKit)`, `#if targetEnvironment(simulator)`, `#if compiler(>=6.4)`, `#if swift(>=6)`, `#if hasFeature(StrictConcurrency)`, `#if hasAttribute(retroactive)`.
  - `#sourceLocation(file:line:)`, `#warning("...")`, `#error("...")`.
- Availability conditions: `if #available(iOS 27, macOS 27, *)`, `if #unavailable(iOS 27)`.

## 5. Declarations
- Top-level code only in `main.swift` or `@main` types.
- `import` with kinds (`import struct Foo.Bar`) and access (`public import`, `internal import`, `private import`), `@_exported` is private API; avoid.
- Constants and variables: stored, computed, observers, type properties, `lazy`.
- `typealias` with generics: `typealias Handler<T> = (Result<T, Error>) -> Void`.
- Functions: parameters, labels, defaults, variadics, `inout`, `borrowing`, `consuming`, `sending`, `isolated`, `rethrows`, `async`, `throws(E)`, `-> Never`.
- Enums: cases, associated values, raw values, `indirect`, methods, nested types.
- Structs, classes, actors: stored properties, inits, `deinit`, subscripts, nested types.
- Protocols: requirements, `associatedtype` with defaults and constraints, primary associated types.
- Initializers: designated, convenience, required, failable, throwing, async.
- Deinitializers: `deinit`, `isolated deinit`.
- Extensions with constraints and conformances.
- Subscripts: instance, static, generic, labeled.
- Macros: `@freestanding(expression) macro name(...) = #externalMacro(module:type:)`, `@attached(member) macro`.
- Operators and precedence groups: `precedencegroup Name { higherThan: AdditionPrecedence; associativity: left }`.
- Declaration modifiers: `class`, `static`, `final`, `lazy`, `optional` (ObjC protocols), `override`, `required`, `convenience`, `dynamic`, `mutating`, `nonmutating`, `weak`, `unowned`, `nonisolated`, `nonisolated(unsafe)`, `nonisolated(nonsending)`, `isolated`, access levels.

## 6. Attributes (working list)

### Declaration attributes
| Attribute | Use |
|---|---|
| `@available(...)` | Platform/version availability, `deprecated`, `obsoleted`, `renamed`, `message`, `unavailable`. `anyAppleOS` in Swift 6.4 |
| `@backDeployed(before:)` | Library functions with implementations embedded in clients for older OS versions |
| `@discardableResult` | Silence unused result warnings |
| `@dynamicCallable`, `@dynamicMemberLookup` | Dynamic call/member syntax |
| `@frozen` | Fixed layout for library evolution |
| `@inlinable`, `@usableFromInline` | Cross-module inlining |
| `@inline(__always)`, `@inline(never)`, `@inline(always)` (6.3, guaranteed for direct calls) | Inlining control |
| `@export(implementation)` (6.3) | Expose implementation of ABI-stable functions for optimization |
| `@specialize` (6.3) | Pre-specialized generic implementations |
| `@main` | Program entry point |
| `@nonobjc`, `@objc`, `@objcMembers`, `@objc @implementation` | Objective-C interop |
| `@c`, `@c(Name)`, `@c @implementation` (6.3) | Expose Swift functions/enums to C or implement C-declared functions in Swift |
| `@NSCopying`, `@NSManaged` | Foundation/Core Data interop |
| `@preconcurrency` | Soften concurrency checking for imports or conformances of legacy APIs |
| `@propertyWrapper`, `@resultBuilder` | Define wrappers/builders |
| `@requires_stored_property_inits` | All stored props must have defaults |
| `@retroactive` | Acknowledge retroactive conformance |
| `@Sendable` | Sendable function types |
| `@testable` | Import internal symbols in tests |
| `@unchecked Sendable` | Manual Sendable guarantee (document why) |
| `@warn_unqualified_access` | Force qualified calls |
| `@diagnose(...)` (Swift 6.4) | Per-declaration warning control: silence deprecation, escalate to error, downgrade future errors |
| `@concurrent` (6.2) | Async function always runs on the concurrent pool |
| `@MainActor`, `@globalActor` custom actors | Isolation |
| `@isolated(any)` | Function type carries its isolation |
| `@abi(...)` (6.2) | Change API while keeping ABI (library authors) |

### Type attributes
`@autoclosure`, `@convention`, `@escaping`, `@Sendable`, `@MainActor` on function types, `@isolated(any)`, `@unchecked` (in conformances).

### Switch case attribute
`@unknown` before `default` or `case _`.

### Framework macros written as attributes
`@Observable`, `@ObservationIgnored`, `@ObservationTracked`, `@Model`, `@Attribute`, `@Relationship`, `@Transient`, `@Query`, `@ModelActor`, `@State` (SwiftUI 2027 macro), `@Entry`, `@Previewable`, `@Animatable`, `@AnimatableIgnored`, `@ContentBuilder`, `@ViewBuilder`, `@Test`, `@Suite`, `@CasePathable` (TCA), `@DependencyClient` (third party).

## 7. Patterns
- Wildcard `_`, identifier `x`, value binding `let (x, y)`, tuple `(a, b)`.
- Enum case: `.loaded(let items)`, `case .some(let x)`, `case let .failed(error)`.
- Optional: `case let x?`.
- Type-casting: `case let s as String`, `case is Int`.
- Expression patterns with `~=`: ranges `case 0..<10`, custom `~=` overloads.
- `for case let .loaded(items) in states { }`, `if case`, `guard case`, `while case`.

## 8. Generic parameters and arguments
- Parameter clause `<T, U: Collection>` and `where` clause `where U.Element == T, T: Sendable`.
- Value generic parameters `<let N: Int>` (Swift 6.2).
- Parameter packs `<each T>` with `repeat each T` expansions.
- Suppressed constraints `<T: ~Copyable>`.
- Generic argument clauses: `Array<Int>`, `Dictionary<String, any Codable>`.
- Contextual `where` clauses on methods inside generic types.

## 9. Availability cheat sheet (2026)

| Release | OS | Swift | Xcode |
|---|---|---|---|
| 2023 | iOS 17 (Observation, SwiftData, `#Preview`, TipKit) | 5.9 | 15 |
| 2024 | iOS 18 (`@Entry`, `@Previewable`, zoom transitions, SwiftData history, `#Index`, `#Unique`) | 6.0 | 16 |
| 2025 | iOS 26 (Liquid Glass, `@Animatable`, SwiftUI `WebView`, Foundation Models, SwiftData inheritance) | 6.2 | 26 |
| Mar 2026 | | 6.3 | 26.x |
| 2026 | iOS 27 (Document API, reorderable containers, `@State` macro, `ContentBuilder`, SwiftData sections, observers) | 6.4 | 27 |

Pattern for gating:
```swift
if #available(iOS 27, *) {
    ReorderableStickerGrid(stickers: $stickers)
} else {
    LegacyStickerGrid(stickers: $stickers)
}
```
Or with the Swift 6.4 shorthand when all Apple platforms share the version:
```swift
@available(anyAppleOS 27, *)
func adoptNewDocumentAPI() { }
```
