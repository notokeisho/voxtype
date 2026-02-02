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
    let githubAvatar: String?
    let isAdmin: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case githubId = "github_id"
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
    let sub: String
    let githubId: String

    enum CodingKeys: String, CodingKey {
        case exp
        case sub
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
    private let callbackScheme = "voiceclient"

    /// Current web authentication session.
    private var authSession: ASWebAuthenticationSession?

    private override init() {
        super.init()
    }

    // MARK: - Public Methods

    /// Check current authentication status on app launch.
    func checkAuthStatus() async {
        guard let token = KeychainHelper.load(forKey: KeychainHelper.tokenKey) else {
            state = .notAuthenticated
            return
        }

        // Check if token is expired
        if isTokenExpired(token) {
            logout()
            return
        }

        // Validate token with server
        do {
            let user = try await validateToken(token)
            state = .authenticated(user)
        } catch {
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
        KeychainHelper.delete(forKey: KeychainHelper.tokenKey)
        state = .notAuthenticated
    }

    /// Refresh authentication if token is about to expire.
    func refreshIfNeeded() async {
        guard let token = self.token else { return }

        // Refresh if token expires within 1 hour
        if let payload = decodeJWTPayload(token),
           payload.exp - Date().timeIntervalSince1970 < 3600 {
            await refreshToken()
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
            state = .error("Invalid callback: missing token")
            return
        }

        // Save token and validate
        KeychainHelper.save(token, forKey: KeychainHelper.tokenKey)

        do {
            let user = try await validateToken(token)
            state = .authenticated(user)
        } catch {
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
        guard let currentToken = token else { return }

        let settings = AppSettings.shared
        guard let baseURL = URL(string: settings.serverURL) else { return }

        let url = baseURL.appendingPathComponent("/auth/refresh")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(currentToken)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return
            }

            struct RefreshResponse: Codable {
                let accessToken: String

                enum CodingKeys: String, CodingKey {
                    case accessToken = "access_token"
                }
            }

            let refreshResponse = try JSONDecoder().decode(RefreshResponse.self, from: data)
            KeychainHelper.save(refreshResponse.accessToken, forKey: KeychainHelper.tokenKey)
        } catch {
            // Silently fail, will retry on next check
        }
    }

    /// Check if JWT token is expired.
    func isTokenExpired(_ token: String) -> Bool {
        guard let payload = decodeJWTPayload(token) else {
            return true
        }
        return Date().timeIntervalSince1970 >= payload.exp
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
