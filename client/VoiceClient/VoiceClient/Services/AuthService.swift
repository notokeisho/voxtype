import Foundation
import AuthenticationServices

/// Authentication state.
enum AuthState: Equatable {
    case unknown
    case notAuthenticated
    case authenticating
    case authenticated(User)
    case error(String)

    static func == (lhs: AuthState, rhs: AuthState) -> Bool {
        switch (lhs, rhs) {
        case (.unknown, .unknown),
             (.notAuthenticated, .notAuthenticated),
             (.authenticating, .authenticating):
            return true
        case (.authenticated(let lUser), .authenticated(let rUser)):
            return lUser.id == rUser.id
        case (.error(let lMsg), .error(let rMsg)):
            return lMsg == rMsg
        default:
            return false
        }
    }
}

/// User information from the server.
struct User: Codable, Identifiable {
    let id: Int
    let githubId: String
    let githubUsername: String?
    let githubAvatar: String?
    let isAdmin: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case githubId = "github_id"
        case githubUsername = "github_username"
        case githubAvatar = "github_avatar"
        case isAdmin = "is_admin"
    }
}

/// Authentication response from the server.
struct AuthResponse: Codable {
    let accessToken: String
    let tokenType: String
    let user: User

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case user
    }
}

/// JWT token payload for expiration checking.
struct JWTPayload: Codable {
    let exp: TimeInterval
    let userId: Int
    let githubId: String

    enum CodingKeys: String, CodingKey {
        case exp
        case userId = "user_id"
        case githubId = "github_id"
    }
}

/// Service for managing OAuth authentication with the server.
@MainActor
class AuthService: NSObject, ObservableObject {
    /// Shared instance.
    static let shared = AuthService()

    /// Current authentication state.
    @Published private(set) var state: AuthState = .unknown

    /// Current user if authenticated.
    var currentUser: User? {
        if case .authenticated(let user) = state {
            return user
        }
        return nil
    }

    /// Whether user is currently authenticated.
    var isAuthenticated: Bool {
        if case .authenticated = state {
            return true
        }
        return false
    }

    /// Current auth token if available.
    var token: String? {
        KeychainHelper.load(forKey: KeychainHelper.tokenKey)
    }

    /// Callback scheme for OAuth redirect.
    private let callbackScheme = "voxtype"

    /// Current web authentication session.
    private var authSession: ASWebAuthenticationSession?

    private override init() {
        super.init()
    }

    // MARK: - Public Methods

    /// Check current authentication status on app launch.
    func checkAuthStatus() async {
        print("🔍 [Auth] checkAuthStatus: 開始")

        guard let token = KeychainHelper.load(forKey: KeychainHelper.tokenKey) else {
            print("❌ [Auth] checkAuthStatus: トークンがKeychainにない")
            state = .notAuthenticated
            return
        }
        print("✅ [Auth] checkAuthStatus: トークン読み込み成功 (長さ: \(token.count))")

        // Check if token is expired
        if isTokenExpired(token) {
            print("⏰ [Auth] checkAuthStatus: トークン期限切れ → logout()呼び出し")
            logout()
            return
        }
        print("✅ [Auth] checkAuthStatus: トークン有効期限内")

        // Validate token with server
        do {
            print("🌐 [Auth] checkAuthStatus: サーバー検証開始...")
            let user = try await validateToken(token)
            print("✅ [Auth] checkAuthStatus: サーバー検証成功 (user.id: \(user.id))")
            state = .authenticated(user)
        } catch {
            print("❌ [Auth] checkAuthStatus: サーバー検証失敗 - \(error) → logout()呼び出し")
            // Token is invalid, clear it
            logout()
        }
    }

    /// Start OAuth login flow.
    func login() {
        state = .authenticating

        let settings = AppSettings.shared
        guard let baseURL = URL(string: settings.serverURL) else {
            state = .error("Invalid server URL")
            return
        }

        let authURL = baseURL.appendingPathComponent("/auth/github/login")

        // Add callback URL parameter
        var components = URLComponents(url: authURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "callback", value: "\(callbackScheme)://callback")
        ]

        guard let url = components?.url else {
            state = .error("Failed to create auth URL")
            return
        }

        authSession = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: callbackScheme
        ) { [weak self] callbackURL, error in
            Task { @MainActor in
                await self?.handleAuthCallback(callbackURL: callbackURL, error: error)
            }
        }

        authSession?.presentationContextProvider = self
        authSession?.prefersEphemeralWebBrowserSession = false
        authSession?.start()
    }

    /// Logout and clear stored credentials.
    func logout() {
        print("🚪 [Auth] logout: 呼び出された")
        KeychainHelper.delete(forKey: KeychainHelper.tokenKey)
        state = .notAuthenticated
        print("🚪 [Auth] logout: 完了 (トークン削除、状態をnotAuthenticatedに)")
    }

    /// Refresh authentication if token is about to expire.
    func refreshIfNeeded() async {
        guard let token = self.token else {
            print("🔄 [Auth] refreshIfNeeded: トークンがない")
            return
        }

        // Refresh if token expires within 3 days (259200 seconds)
        if let payload = decodeJWTPayload(token) {
            let remaining = payload.exp - Date().timeIntervalSince1970
            print("🔄 [Auth] refreshIfNeeded: 残り\(Int(remaining))秒 (\(Int(remaining/86400))日)")
            if remaining < 259200 {
                print("🔄 [Auth] refreshIfNeeded: 閾値以内なのでリフレッシュ実行")
                await refreshToken()
            } else {
                print("🔄 [Auth] refreshIfNeeded: 十分な期間があるのでスキップ")
            }
        }
    }

    // MARK: - Private Methods

    private func handleAuthCallback(callbackURL: URL?, error: Error?) async {
        if let error = error {
            if let authError = error as? ASWebAuthenticationSessionError,
               authError.code == .canceledLogin {
                state = .notAuthenticated
            } else {
                state = .error(error.localizedDescription)
            }
            return
        }

        guard let callbackURL = callbackURL,
              let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
            state = .error("Invalid callback URL")
            return
        }

        // Check for error from server
        if let errorCode = components.queryItems?.first(where: { $0.name == "error" })?.value {
            let errorMessage = components.queryItems?.first(where: { $0.name == "message" })?.value ?? "Authentication failed"

            switch errorCode {
            case "not_whitelisted":
                state = .error("Your account is not in the whitelist. Please contact an administrator.")
            case "github_error":
                state = .error("GitHub authentication failed: \(errorMessage)")
            case "github_auth_failed":
                state = .error("Failed to authenticate with GitHub: \(errorMessage)")
            default:
                state = .error(errorMessage)
            }
            return
        }

        // Check for token from server
        guard let token = components.queryItems?.first(where: { $0.name == "token" })?.value else {
            print("❌ [Auth] handleAuthCallback: トークンがコールバックにない")
            state = .error("Invalid callback: missing token")
            return
        }
        print("✅ [Auth] handleAuthCallback: トークン受信 (長さ: \(token.count))")

        // Save token and validate
        let saveResult = KeychainHelper.save(token, forKey: KeychainHelper.tokenKey)
        print("💾 [Auth] handleAuthCallback: Keychain保存結果 = \(saveResult)")

        do {
            let user = try await validateToken(token)
            print("✅ [Auth] handleAuthCallback: 認証成功 (user.id: \(user.id))")
            state = .authenticated(user)
        } catch {
            print("❌ [Auth] handleAuthCallback: 検証失敗 - \(error)")
            // Token validation failed, clear it
            KeychainHelper.delete(forKey: KeychainHelper.tokenKey)
            state = .error(error.localizedDescription)
        }
    }

    private func validateToken(_ token: String) async throws -> User {
        let settings = AppSettings.shared
        guard let baseURL = URL(string: settings.serverURL) else {
            throw AuthError.invalidURL
        }

        let url = baseURL.appendingPathComponent("/api/me")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            return try decoder.decode(User.self, from: data)
        case 401:
            throw AuthError.unauthorized
        case 403:
            throw AuthError.notWhitelisted
        default:
            throw AuthError.serverError("Server returned status \(httpResponse.statusCode)")
        }
    }

    private func refreshToken() async {
        print("🔄 [Auth] refreshToken: 開始")
        guard let currentToken = token else { return }

        let settings = AppSettings.shared
        guard let baseURL = URL(string: settings.serverURL) else { return }

        let url = baseURL.appendingPathComponent("/auth/refresh")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(currentToken)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [Auth] refreshToken: レスポンスが不正")
                return
            }

            print("🔄 [Auth] refreshToken: ステータス \(httpResponse.statusCode)")

            switch httpResponse.statusCode {
            case 200:
                // Success: save new token
                struct RefreshResponse: Codable {
                    let accessToken: String

                    enum CodingKeys: String, CodingKey {
                        case accessToken = "access_token"
                    }
                }

                let refreshResponse = try JSONDecoder().decode(RefreshResponse.self, from: data)
                KeychainHelper.save(refreshResponse.accessToken, forKey: KeychainHelper.tokenKey)
                print("✅ [Auth] refreshToken: 新しいトークンを保存")
            case 401, 403:
                // Token invalid or user not whitelisted: logout
                print("⚠️ [Auth] refreshToken: 認証エラー(\(httpResponse.statusCode)) → ログアウト")
                logout()
            default:
                // Other errors: silently fail, will retry on next check
                print("⚠️ [Auth] refreshToken: その他のエラー(\(httpResponse.statusCode)) → 次回再試行")
                break
            }
        } catch {
            // Network error: silently fail, will retry on next check
            print("⚠️ [Auth] refreshToken: ネットワークエラー - \(error.localizedDescription)")
        }
    }

    /// Check if JWT token is expired.
    func isTokenExpired(_ token: String) -> Bool {
        guard let payload = decodeJWTPayload(token) else {
            print("⏰ [Auth] isTokenExpired: JWTデコード失敗 → 期限切れとみなす")
            return true
        }
        let now = Date().timeIntervalSince1970
        let isExpired = now >= payload.exp
        print("⏰ [Auth] isTokenExpired: now=\(now), exp=\(payload.exp), 差分=\(payload.exp - now)秒, 期限切れ=\(isExpired)")
        return isExpired
    }

    /// Decode JWT payload without verification.
    private func decodeJWTPayload(_ token: String) -> JWTPayload? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }

        let payloadPart = String(parts[1])

        // Add padding if needed for base64 decoding
        var base64 = payloadPart
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        guard let data = Data(base64Encoded: base64) else {
            return nil
        }

        return try? JSONDecoder().decode(JWTPayload.self, from: data)
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension AuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Return the main window or create a new one
        NSApplication.shared.windows.first ?? ASPresentationAnchor()
    }
}

// MARK: - Errors

/// Authentication errors.
enum AuthError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case notWhitelisted
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Authentication failed"
        case .notWhitelisted:
            return "You are not authorized to use this service"
        case .serverError(let message):
            return message
        }
    }
}
