# Networking, Security, Privacy

## Contents
1. HTTP client design
2. URLSession with async/await
3. Codable
4. Authentication and token refresh
5. Offline, retries, reachability
6. Real-time: WebSocket, SSE, streaming
7. Keychain and secrets
8. Data protection and file security
9. App Transport Security and certificate pinning
10. CryptoKit
11. Privacy: permissions, manifests, tracking
12. Secure coding checklist

---

## 1. HTTP client design
```swift
struct Endpoint<Response: Decodable & Sendable>: Sendable {
    var path: String
    var method: String = "GET"
    var query: [URLQueryItem] = []
    var body: Data? = nil
}

enum APIError: Error, Equatable {
    case unauthorized
    case http(status: Int)
    case decoding(String)
    case transport(URLError.Code)
}

actor APIClient {
    private let baseURL: URL
    private let session: URLSession
    private let tokens: TokenStore
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    init(baseURL: URL, session: URLSession = .shared, tokens: TokenStore) {
        self.baseURL = baseURL
        self.session = session
        self.tokens = tokens
    }

    func send<Response: Decodable & Sendable>(_ endpoint: Endpoint<Response>) async throws(APIError) -> Response {
        var components = URLComponents(url: baseURL.appending(path: endpoint.path), resolvingAgainstBaseURL: false)
        if !endpoint.query.isEmpty { components?.queryItems = endpoint.query }
        guard let url = components?.url else { throw APIError.http(status: -1) }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method
        request.httpBody = endpoint.body
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let token = try await tokens.validToken()
            request.setValue("Bearer \(token.value)", forHTTPHeaderField: "Authorization")
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.http(status: -1) }
            switch http.statusCode {
            case 200..<300: break
            case 401: throw APIError.unauthorized
            default: throw APIError.http(status: http.statusCode)
            }
            return try decoder.decode(Response.self, from: data)
        } catch let error as APIError {
            throw error
        } catch let error as URLError {
            throw APIError.transport(error.code)
        } catch let error as DecodingError {
            throw APIError.decoding(String(describing: error))
        } catch {
            throw APIError.http(status: -1)
        }
    }
}
```
- One client per base URL, injected. Endpoints are values.
- Map transport, HTTP and decoding errors to a domain error.
- Configure timeouts on `URLSessionConfiguration` (`timeoutIntervalForRequest`, `waitsForConnectivity = true`).
- Use `URL.appending(path:)` and `URLComponents`, never string concatenation.
- Consider swift-openapi-generator when the backend publishes an OpenAPI spec.

## 2. URLSession with async/await
- `data(for:)`, `upload(for:from:)`, `download(for:)`, `bytes(for:)` for streaming lines/bytes.
- Task cancellation cancels the request.
- Background sessions for large transfers (delegate-based; handle `handleEventsForBackgroundURLSession`).
- `URLSessionTaskDelegate` per task for progress/metrics (`didFinishCollecting metrics`).
- HTTP caching through `URLCache` and `cachePolicy`.

## 3. Codable
- `CodingKeys` for renames, or `keyDecodingStrategy = .convertFromSnakeCase` (consistent APIs only).
- Custom `init(from:)` for defaults and lenient decoding of optional fields; do not crash on unknown enum values:
```swift
enum LegStatus: String, Codable, Sendable {
    case planned, active, complete, unknown
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = LegStatus(rawValue: raw) ?? .unknown
    }
}
```
- Dates: agree on ISO 8601 with fractional seconds if needed (`.iso8601` does not accept fractions; use a custom `Date.ISO8601FormatStyle`).
- Decimal money values as strings or `Decimal`, not `Double`.
- Keep DTOs `Sendable` structs separate from UI/persistence models.

## 4. Authentication and token refresh
- OAuth 2.0 / OIDC with PKCE through `ASWebAuthenticationSession` (`prefersEphemeralWebBrowserSession` for shared devices).
- Passkeys (`ASAuthorizationPlatformPublicKeyCredentialProvider`) and Sign in with Apple where applicable.
- Enterprise SSO: Extensible Enterprise SSO via MDM, or the identity provider's SDK.
- Store refresh tokens in Keychain; access tokens in memory.
- Single-flight refresh inside an actor (see swift-concurrency.md TokenStore pattern). Retry the original request once after refresh; on failure, sign out cleanly.
- Biometrics: `LAContext` for local re-authentication; bind Keychain items to biometry with access control flags for high-value secrets.

## 5. Offline, retries, reachability
- Do not pre-check reachability to decide whether to send; send and handle errors. Use `NWPathMonitor` to update UI and trigger queued work when connectivity returns.
- `waitsForConnectivity` for requests that should wait instead of failing.
- Retry idempotent requests with exponential backoff and jitter; cap attempts; respect `Retry-After`.
- Queue mutations locally (SwiftData outbox or history-based sync), make server endpoints idempotent (client-generated request IDs).
- Show freshness ("Updated 4 min ago") for cached data.

## 6. Real-time
- `URLSessionWebSocketTask` with an async receive loop and ping/pong; reconnect with backoff.
- Server-Sent Events via `session.bytes(for:)` and parsing `lines`.
- Network framework (`NWConnection`) for custom protocols.
- gRPC Swift 2 for bidirectional streaming with Swift concurrency.

## 7. Keychain and secrets
```swift
enum Keychain {
    static func save(_ data: Data, account: String, service: String = "com.example.ops") throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.status(status) }
    }
}
```
- Choose accessibility carefully: `WhenUnlockedThisDeviceOnly` for most secrets, `AfterFirstUnlockThisDeviceOnly` if background access is needed.
- Access groups to share with extensions.
- Never store secrets in `UserDefaults`, `@AppStorage`, plist, source code, xcconfig, or logs.
- API keys that must ship in the app are not secrets; protect server-side with App Attest / DeviceCheck and rate limiting.

## 8. Data protection and file security
- Enable Data Protection entitlement; default class `NSFileProtectionComplete` for sensitive apps (files unavailable while locked).
- Per file: `try data.write(to: url, options: [.atomic, .completeFileProtection])`.
- Exclude caches from backup when appropriate (`isExcludedFromBackup`).
- Clear sensitive data on sign-out (Keychain items, SwiftData stores, caches, URLCache, cookies).
- Hide sensitive content in the app switcher snapshot (overlay on `scenePhase != .active`).
- Disable screenshots/screen recording only if policy requires; detect with `UIScreen.capturedDidChangeNotification` / `sceneCaptureState`.

## 9. ATS and pinning
- App Transport Security on by default: HTTPS with TLS 1.2+. Do not add `NSAllowsArbitraryLoads`. Use narrowly scoped exceptions only for legacy internal hosts with documented approval.
- Certificate/public key pinning: prefer `NSPinnedDomains` in Info.plist (declarative) over custom delegate code. Pin to intermediate or public keys with backup pins; plan rotation.
- Validate server trust in `URLSessionDelegate` only when you know exactly what you are doing.

## 10. CryptoKit
- Hashing: `SHA256.hash(data:)`.
- Symmetric encryption: `AES.GCM.seal`/`open`, `ChaChaPoly`.
- Keys: `SymmetricKey(size: .bits256)`, store raw representation in Keychain; `SecureEnclave.P256` for hardware-backed keys.
- Signatures: `P256.Signing`, `Curve25519.Signing`.
- Key agreement: `P256.KeyAgreement`, HPKE. Post-quantum ML-KEM / ML-DSA APIs are available in recent SDKs; check availability before use.
- Never roll your own crypto; never use `Insecure.MD5`/`SHA1` for security.

## 11. Privacy
- Info.plist purpose strings for every protected resource (camera, photos, location, contacts, Bluetooth, local network, microphone, motion, health).
- Privacy manifest (`PrivacyInfo.xcprivacy`): declare collected data types, tracking domains, and required-reason APIs (e.g. `UserDefaults`, file timestamps, system boot time, disk space). Third-party SDKs need their own manifests and signatures.
- App Tracking Transparency only if tracking across apps/websites; otherwise do not prompt.
- Request permissions in context with a pre-prompt explaining value.
- Minimize data collection; process on device when possible.
- Age assurance and declared age range APIs where legally required for your audience and regions.
- Pasteboard access shows a notice; use `PasteButton` for user-initiated paste.

## 12. Secure coding checklist
- [ ] No secrets in source, logs, analytics, crash reports.
- [ ] TLS everywhere, no ATS exceptions without approval.
- [ ] Tokens in Keychain with correct accessibility.
- [ ] Sensitive files with complete protection; caches cleared on sign-out.
- [ ] Input validation for deep links, URL schemes, universal links, pasteboard and file imports.
- [ ] WebViews: no arbitrary JavaScript bridges to untrusted content; restrict navigation.
- [ ] Jailbreak detection only if policy demands; never rely on it for security.
- [ ] Dependencies pinned, reviewed, and scanned; Package.resolved committed.
- [ ] Privacy manifest complete and accurate.
