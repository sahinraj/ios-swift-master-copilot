This list flickers and loses scroll position on every refresh. Fix it.

```swift
List(items.indices, id: \.self) { i in Row(item: items[i]) }
```
