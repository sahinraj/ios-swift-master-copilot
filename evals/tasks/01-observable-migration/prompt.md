Convert this view model to the modern Observation framework and update the view that owns it.

```swift
final class ProfileViewModel: ObservableObject {
    @Published var name = ""
    @Published var isLoading = false
}

struct ProfileView: View {
    @StateObject private var model = ProfileViewModel()
    var body: some View { Text(model.name) }
}
```
