# Swift Language Guide (condensed, Swift 6.4)

Mirrors the chapter order of *The Swift Programming Language* Language Guide. Each section lists the rules that matter in production plus the traps.

## Contents
1. The Basics
2. Basic Operators
3. Strings and Characters
4. Collection Types
5. Control Flow
6. Functions
7. Closures
8. Enumerations
9. Structures and Classes
10. Properties
11. Methods
12. Subscripts
13. Inheritance
14. Initialization
15. Deinitialization
16. Optional Chaining
17. Error Handling
18. Concurrency (summary, full detail in swift-concurrency.md)
19. Macros
20. Type Casting
21. Nested Types
22. Extensions
23. Protocols
24. Generics
25. Opaque and Boxed Protocol Types
26. Automatic Reference Counting
27. Memory Safety
28. Access Control
29. Advanced Operators
30. Ownership and noncopyable types

---

## 1. The Basics
- `let` for constants, `var` for variables. Default to `let`.
- Type inference is preferred; annotate when it improves clarity or fixes ambiguity (`let ratio: Double = 1`).
- Integers: `Int` is word-sized; use sized types (`Int32`, `UInt8`) only for interop, binary formats or memory layout. Swift 6 adds `Int128`/`UInt128`.
- Floating point: `Double` by default. Use `Decimal` for money, never `Double`.
- Numeric literals: `1_000_000`, `0xFF`, `0b1010`, `0o17`, `1.5e3`.
- Conversions are explicit: `Double(intValue)`. Overflow traps at runtime in debug and release unless you use `&+` etc.
- Type aliases: `typealias Coordinate = (lat: Double, lon: Double)`.
- Tuples: fine for small, local, unnamed groupings. Promote to a `struct` if it crosses an API boundary.
- Optionals: `T?` is `Optional<T>`. Unwrap with `if let x`, `guard let x`, `??`, optional chaining, `switch`. Shorthand `if let value { }` (Swift 5.7+).
- Implicitly unwrapped optionals (`T!`) only for IBOutlets and two-phase init you cannot avoid.
- Error handling basics: `throws`, `try`, `do/catch`, `try?`, `try!` (avoid).
- Assertions and preconditions: `assert` (debug only), `precondition` (debug and release), `assertionFailure`, `preconditionFailure`, `fatalError` (always traps; returns `Never`).

## 2. Basic Operators
- Assignment does not return a value (`if x = y` is a compile error).
- Arithmetic traps on overflow. Remainder `%` keeps the sign of the dividend.
- Comparison operators work on tuples up to 6 elements when elements are `Comparable`.
- Ternary `a ? b : c`; keep it simple, nest nothing.
- Nil-coalescing `a ?? b` short-circuits `b`.
- Ranges: closed `a...b`, half-open `a..<b`, one-sided `a...`, `..<b`, `...b`.
- Logical `!`, `&&`, `||` short-circuit, left-associative. Add parentheses for readability.

## 3. Strings and Characters
- `String` is a value type, Unicode-correct, a collection of `Character` (extended grapheme clusters).
- `count` is O(n). Indices are `String.Index`, not `Int`. Use `firstIndex(of:)`, `index(_:offsetBy:)`, `prefix`, `dropFirst`.
- `Substring` shares storage with the original. Convert to `String` before storing long-term.
- Multiline literals `""" ... """`; raw strings `#"no \n escape"#`; interpolation `\(value)`; in raw strings `\#(value)`.
- Compare with `==` (canonical equivalence). For user-facing search use `localizedStandardContains` / `localizedCaseInsensitiveCompare`.
- Views: `.utf8`, `.utf16`, `.unicodeScalars`.
- Regex: `Regex` literals `/\d+/`, `RegexBuilder` DSL, `firstMatch(of:)`, `wholeMatch(of:)`, `replacing(_:with:)`.
- Formatting: `value.formatted(.number.precision(.fractionLength(2)))`, `date.formatted(date: .abbreviated, time: .shortened)`. Never build display strings with manual concatenation for dates or numbers.

## 4. Collection Types
- `Array`, `Set`, `Dictionary` are value types with copy-on-write.
- Array: `append`, `insert(_:at:)`, `remove(at:)`, `firstIndex(where:)`, `contains(where:)`, `count(where:)` (Swift 6), `sorted(using:)` with `KeyPathComparator`/`SortDescriptor`.
- Safe access: never index blindly. `array.indices.contains(i) ? array[i] : nil` or `first`, `last`.
- Set: `Hashable` elements; `union`, `intersection`, `subtracting`, `symmetricDifference`, `isSubset(of:)`.
- Dictionary: subscript returns optional; `dict[key, default: 0] += 1`; `Dictionary(grouping:by:)`, `Dictionary(uniqueKeysWithValues:)` (traps on duplicates), `Dictionary(_:uniquingKeysWith:)`.
- Iteration order of `Set` and `Dictionary` is not stable. Sort before displaying.
- Lazy sequences: `array.lazy.filter { }.map { }` to avoid intermediate arrays.
- `InlineArray<N, Element>` (Swift 6.2) is fixed-size, stored inline, noncopyable-friendly; sugar `[5 of Int]`. Use for small fixed buffers in hot paths.
- `Span`/`MutableSpan`/`RawSpan` (Swift 6.2) give safe, non-escaping access to contiguous memory. Prefer over `UnsafeBufferPointer`.
- Swift Collections package adds `OrderedDictionary`, `OrderedSet`, `Deque`, `Heap`, `BitSet`.

## 5. Control Flow
- `for-in` over sequences, ranges, `stride(from:to:by:)`, `enumerated()`, `zip`.
- `while`, `repeat-while`.
- `if`, `guard` (must exit scope: `return`, `throw`, `break`, `continue`, or call a `Never` function).
- `if` and `switch` are expressions (Swift 5.9): `let label = if isOn { "On" } else { "Off" }`.
- `switch` must be exhaustive; no implicit fallthrough; use `fallthrough` explicitly. Patterns: ranges, tuples, `let` bindings, `where` clauses, `case .some(let x)`, `case let .loaded(value)`.
- `@unknown default` for non-frozen enums from other modules (SDK enums).
- Labeled statements: `outer: for ... { break outer }`.
- `defer` runs on scope exit in reverse order. Swift 6.4 allows `await` inside `defer` in async functions (SE-0493).
- Availability checks: `if #available(iOS 27, *)`, `if #unavailable(iOS 26)`. Swift 6.4 adds `anyAppleOS` for all Apple platforms at matching versions.

## 6. Functions
- Argument labels vs parameter names: `func move(from source: Int, to destination: Int)`. Omit with `_`.
- Default parameter values go at the end of the parameter list by convention.
- Variadic `Int...`; multiple variadic parameters allowed.
- `inout` parameters require `&` at call site; no aliasing (exclusivity).
- Multiple returns via tuples or, better, small structs.
- Implicit return for single-expression bodies.
- Function types `(Int, Int) -> Int` are first-class.
- Nested functions capture surrounding scope.
- `@discardableResult` when ignoring a result is normal.
- `rethrows` for higher-order functions that throw only if their closure throws.
- `async`, `throws`, `throws(E)`, `async throws` combine; order is `async throws`.
- `some Protocol` parameters (`func draw(_ shape: some Shape)`) are sugar for generics.
- Parameter modifiers for ownership: `borrowing`, `consuming`, `inout`, and `sending` for concurrency.

## 7. Closures
- Syntax: `{ (a: Int, b: Int) -> Bool in a < b }`, shorthand `$0`, trailing closures, multiple trailing closures with labels.
- Closures capture variables by reference; value types captured are shared boxes unless you use a capture list `[value]`.
- Escaping closures (`@escaping`) must reference `self` explicitly in classes; use `[weak self]` to avoid cycles when the closure is stored by `self` or something `self` owns.
- `[unowned self]` only when lifetime is guaranteed; a wrong `unowned` crashes.
- Structs (including SwiftUI views) do not create retain cycles through `self` capture; no `[weak self]` in view closures.
- Autoclosures (`@autoclosure`) delay evaluation; used by `assert`, `??`.
- `@Sendable` and `sending` closures for concurrency boundaries; `@isolated(any)` for closures that carry their isolation.
- Non-escaping closures cannot be stored; they are the default for parameters.

## 8. Enumerations
- Cases with associated values: `case loaded([Item])`, `case failed(any Error)`.
- Raw values: `enum Status: String { case active, inactive }` gives `"active"`; `init?(rawValue:)`.
- `CaseIterable` synthesizes `allCases` (no associated values).
- Recursive enums need `indirect`.
- Enums are the right tool for view state:
```swift
enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(String)
}
```
- `Equatable`, `Hashable`, `Codable`, `Comparable` synthesize for enums when associated values conform.
- Pattern match with `if case .failed(let message) = state { }`.
- Use `@frozen` only in ABI-stable libraries.

## 9. Structures and Classes
- Structs: value semantics, memberwise init, no inheritance, no deinit (unless `~Copyable`), mutation requires `var` instance and `mutating` methods.
- Classes: reference semantics, identity (`===`), inheritance, `deinit`, ARC.
- Choose struct by default. Choose class for shared identity, Objective-C interop, lifecycle hooks, `@Observable` state, or when copying is semantically wrong.
- Mark classes `final` unless designed for subclassing. It enables static dispatch and clearer intent.
- Memberwise initializers are internal. In Swift 6.4, when a struct mixes `private` and non-private stored properties, the compiler can synthesize an internal initializer for the accessible properties plus a private one with all of them. Declare your own init when the public shape matters.
- Equality for classes is not synthesized; implement `Equatable` explicitly if needed.

## 10. Properties
- Stored (`let`/`var`), computed (`get`/`set`), read-only computed (`var x: Int { ... }`).
- `lazy var` for expensive, rarely used stored properties (not thread-safe; not allowed on `let`).
- Property observers `willSet`/`didSet` (not called during init of the owning type).
- Type properties `static let` are lazily initialized and thread-safe.
- Property wrappers (`@propertyWrapper`) with `wrappedValue`, `projectedValue` (`$name`). SwiftUI's `@State` became a macro in the 2027 SDK; most wrappers remain wrappers.
- Effectful read-only properties: `var value: Int { get async throws }`.
- `weak let` (SE-0481) allows immutable weak references, which keeps `Sendable` classes checkable.
- Swift 6.4 adds borrow and mutate accessors for yielding access to storage without copies (advanced, library code).

## 11. Methods
- Instance methods, `mutating` methods for value types (can reassign `self`).
- Type methods: `static func` (not overridable) and `class func` (overridable in classes).
- `@discardableResult` for fluent APIs.
- Prefer methods on the type over free functions when there is a clear subject.

## 12. Subscripts
- `subscript(index: Int) -> Element { get set }`, multiple parameters, labels, `static subscript`.
- Can be generic and can throw/async on read-only subscripts.
- Add a safe subscript extension only if the codebase already uses one; otherwise use `indices.contains`.

## 13. Inheritance
- Single inheritance for classes. `override` is required. `super` calls parent implementations.
- Prevent overriding with `final` on members or the class.
- Override property observers or computed properties, never stored storage.
- Prefer protocol composition over deep class hierarchies.

## 14. Initialization
- All stored properties must be initialized before use of `self` (two-phase initialization).
- Structs: memberwise init if you do not declare one. Keep it by declaring custom inits in an extension.
- Classes: designated inits (`init`) must call a superclass designated init; convenience inits (`convenience init`) must call `self.init`.
- `required init` forces subclasses to implement it.
- Failable `init?` and throwing `init() throws`. Prefer throwing for rich errors.
- Default property values reduce init boilerplate, but for SwiftUI `@State` in the 2027 SDK do not both default a `@State` property and assign it in `init` (see swiftui-ios26-ios27-new.md).
- Closures to set defaults: `let formatter: DateFormatter = { ... }()`.

## 15. Deinitialization
- `deinit` only in classes, actors and noncopyable types. Runs when the last strong reference goes away.
- Do not rely on `deinit` for business logic. Use it for cleanup (cancel tasks, remove observers).
- Isolated `deinit` for actors and global actor classes (`isolated deinit`, Swift 6.2) when cleanup must run on the actor.

## 16. Optional Chaining
- `user?.address?.street` returns an optional; the chain stops at the first `nil`.
- Calling a method that returns `Void` through a chain returns `Void?`, useful for checking whether the call happened.
- Combine with `??` for defaults. Avoid long chains that hide data model problems.

## 17. Error Handling
- Errors conform to `Error`. Model them as enums with associated values; add `LocalizedError` for user-facing messages.
- `throws` (untyped, `any Error`) is the default. `throws(ParsingError)` for closed domains (parsers, low-level libs, embedded). `throws(Never)` is non-throwing.
- `do { try ... } catch let error as NetworkError { } catch { }`. In a typed-throws `do throws(E)` block, `catch` binds `error` as `E`.
- `try?` converts to optional (loses the error). Use only when the error truly does not matter.
- `defer` for cleanup on every exit path.
- `Result<Success, Failure>` for storing outcomes. Swift 6.4 adds an async catching initializer: `let result = await Result { try await load() }`.
- Never swallow errors silently in `catch {}`. Log them with `Logger` at minimum.

## 18. Concurrency (summary)
- `async`/`await`, `async let` for parallel child work, `withTaskGroup`/`withThrowingTaskGroup`, `withDiscardingTaskGroup`.
- `Task { }` inherits actor isolation and priority; `Task.detached` does not (rarely correct).
- `actor` protects mutable state; `@MainActor` global actor for UI.
- `Sendable` marks types safe to share across isolation domains.
- Swift 6.2 approachable concurrency: optional default MainActor isolation per module, `nonisolated(nonsending)` default for async functions under the upcoming feature, `@concurrent` to run off-actor.
- Full rules: swift-concurrency.md.

## 19. Macros
- Freestanding macros use `#`: `#Preview`, `#Predicate`, `#expect`, `#URL` style validators, `#warning`, `#error`.
- Attached macros use `@`: `@Observable`, `@Model`, `@Test`, `@Entry`, `@Animatable`, and `@State` (SwiftUI 2027).
- Roles: expression, declaration, peer, member, member attribute, accessor, extension, body.
- Macros are implemented in a separate compiler plugin target using swift-syntax. SwiftPM supports prebuilt swift-syntax for faster builds.
- Expand macros in Xcode (right click, Expand Macro) when debugging generated code.
- Macro-generated code must compile under the same isolation and access rules as handwritten code; errors often point into the expansion.

## 20. Type Casting
- `is` checks, `as?` conditional cast, `as!` forced (avoid), `as` for guaranteed upcasts and bridging.
- `Any` and `AnyObject` erase everything; avoid in APIs. Prefer generics or protocols.
- Casting to protocols with associated types requires `any P<Assoc>` primary associated types syntax (`any Collection<Int>`).

## 21. Nested Types
- Nest types that only make sense in context: `struct Flight { enum Phase { ... } }`.
- Refer to them as `Flight.Phase`. Keeps namespaces clean and enables `.phase` shorthand in context.

## 22. Extensions
- Add computed properties, methods, initializers (convenience for classes, any for structs without losing memberwise init), subscripts, nested types, protocol conformances.
- Cannot add stored properties (use associated storage patterns or wrapper types instead).
- Organize conformances in separate extensions: `extension Route: Hashable { }`.
- Retroactive conformance of a type you do not own to a protocol you do not own triggers a warning; mark `@retroactive` only when you accept the risk.
- Constrained extensions: `extension Array where Element: Numeric { }`.

## 23. Protocols
- Requirements: properties (`{ get }`, `{ get set }`), methods, `mutating` methods, initializers, static members, associated types.
- Protocol extensions provide default implementations. Methods declared only in extensions are statically dispatched; declare them in the protocol for dynamic dispatch.
- Primary associated types: `protocol Store<Item> { associatedtype Item }` enables `some Store<Book>` and `any Store<Book>`.
- Class-only protocols: `protocol Delegate: AnyObject`.
- Composition: `typealias Persistable = Codable & Identifiable & Sendable`.
- Synthesized conformances: `Equatable`, `Hashable`, `Comparable` (enums), `Codable`, `CaseIterable`, `RawRepresentable`.
- Isolated conformances (Swift 6.2): `extension MyView: @MainActor SomeProtocol` for MainActor types conforming to non-isolated protocols.
- Suppressible conformances: `~Copyable`, `~Escapable`, and `~Sendable` (Swift 6.4) express that a type intentionally does not conform.
- Use protocols for seams (testing, modules), not by reflex for every type.

## 24. Generics
- Generic functions and types: `func swap<T>(_ a: inout T, _ b: inout T)`.
- Constraints: `<T: Hashable>`, `where` clauses, same-type constraints `where C.Element == Int`.
- Associated types with constraints and `where` clauses in protocols.
- Generic subscripts and contextual `where` on members.
- Parameter packs (`each T`, `repeat each T`) for variadic generics, iterable with `for x in repeat each values` (Swift 6).
- Noncopyable generics: `<T: ~Copyable>` accepts noncopyable types.
- Integer generic parameters (Swift 6.2) power `InlineArray<let count: Int, Element>`.
- Specialization: Swift 6.3 `@specialize` for library authors.

## 25. Opaque and Boxed Protocol Types
- `some P` (opaque): one concrete type chosen by the implementation, fully optimized, preserves type identity. Use for return types and parameters by default.
- `any P` (existential box): dynamic type, dynamic dispatch, allocation cost. Use for heterogeneous collections or stored properties that must vary at runtime.
- Swift 6 requires explicit `any` for existentials.
- Swift 6.4 lets you drop parentheses in some existential type positions, e.g. `any P?` instead of `(any P)?` where unambiguous.
- Unboxing: pass `any P` to a function taking `some P` to open the existential implicitly.

## 26. Automatic Reference Counting
- Strong references keep objects alive. Cycles leak.
- `weak` references become `nil` automatically; must be optional. `weak var` or `weak let`.
- `unowned` for non-optional references that never outlive the owner; crashes if wrong. `unowned(unsafe)` avoids checks (almost never).
- Closure capture lists: `[weak self]`, `[weak delegate = self.delegate]`.
- Common leak sources: stored closures capturing `self`, `Timer` targets, `NotificationCenter` block observers stored on self, delegate properties declared strong, `Task` stored on self that captures self in an infinite loop.
- Tasks capture `self` strongly; for long-running tasks owned by an object, cancel them in `deinit` or use `[weak self]` inside loops.
- Verify with Xcode Memory Graph and the Leaks instrument.

## 27. Memory Safety
- Exclusivity: no overlapping access to the same variable when at least one is a write (`inout` plus another access). Enforced at compile and run time.
- Conflicts show up with `inout` arguments, `mutating` methods on the same value, and simultaneous access to struct properties through global variables.
- Strict memory safety mode (Swift 6.2, opt-in) flags uses of unsafe constructs; mark intentional uses with `unsafe` expressions.
- Prefer `Span` over unsafe pointers. When you must use pointers, keep them in the smallest scope with `withUnsafeBytes`.

## 28. Access Control
- Levels: `open` (subclass/override outside module), `public`, `package` (same SwiftPM package), `internal` (default), `fileprivate`, `private` (enclosing declaration and its same-file extensions).
- A type's members default to at most the type's access level (`internal` for public types).
- `private(set)` / `internal(set)` for read-only public surface.
- Import access levels (SE-0409): `internal import Foo`, `private import Foo` to avoid leaking dependencies.
- Tests: `@testable import` exposes internal symbols; do not make things public just for tests.

## 29. Advanced Operators
- Bitwise: `~`, `&`, `|`, `^`, `<<`, `>>` (smart shifts).
- Overflow operators `&+`, `&-`, `&*` wrap instead of trapping.
- Operator methods: `static func + (lhs: Vector, rhs: Vector) -> Vector`.
- Prefix/postfix operators, compound assignment `+=`, equivalence `==`.
- Custom operators need `prefix|infix|postfix operator` declarations and precedence groups. Use sparingly; readability first.
- Result builders (`@resultBuilder`) power SwiftUI's `ViewBuilder` and, in the 2027 SDK, `ContentBuilder`.

## 30. Ownership and noncopyable types
- `~Copyable` structs/enums model unique resources (file handles, tokens). They can have `deinit`.
- Parameter conventions: `borrowing` (read), `consuming` (take ownership), `inout` (mutate).
- `consume x` ends a binding's lifetime explicitly; `discard self` in consuming methods skips `deinit`.
- `~Escapable` types (lifetime-dependent) back `Span`.
- Swift 6.4 adds a borrowing iteration protocol so `for-in` works over noncopyable containers like `Span` and `InlineArray` without copying elements.
- Use these in performance-critical or safety-critical resource code, not in everyday app models.
