```swift
final class ProfileViewModel: ObservableObject {
    @Published var name = ""
}
struct ProfileView: View {
    @StateObject private var model = ProfileViewModel()
}
```
