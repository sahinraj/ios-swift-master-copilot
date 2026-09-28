Fix the compiler error 'Capture of non-Sendable type ImageCache in a @Sendable closure' without using @unchecked Sendable.

```swift
final class ImageCache { var store: [URL: Data] = [:] }
let cache = ImageCache()
Task.detached { cache.store[url] = data }
```
