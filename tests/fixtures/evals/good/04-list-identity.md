```swift
struct Item: Identifiable { let id: UUID; var title: String }
List(items) { item in Row(item: item) }
```
