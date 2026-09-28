We no longer need ObservableObject or @Published here.

```swift
@Observable
final class ProfileViewModel {
    var name = ""
    var isLoading = false
}

struct ProfileView: View {
    @State private var model = ProfileViewModel()
    var body: some View { Text(model.name) }
}
```
