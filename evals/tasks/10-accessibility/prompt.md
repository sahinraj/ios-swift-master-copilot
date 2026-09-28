Make this custom rating control accessible to VoiceOver users.

```swift
HStack { ForEach(1...5, id: \.self) { i in Image(systemName: i <= rating ? "star.fill" : "star").onTapGesture { rating = i } } }
```
