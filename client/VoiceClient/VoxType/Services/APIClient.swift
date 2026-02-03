import Foundation

/// Response from the transcription API.
struct TranscribeResponse: Codable {
    let text: String
    let processingTime: Double?

    enum CodingKeys: String, CodingKey {
        case text
        case processingTime = "processing_time"
    }
}

/// API client for communicating with VoxType server.
@MainActor
class APIClient: ObservableObject {
    /// Shared instance.
    static let shared = APIClient()

    // MARK: - Published Properties

    /// Whether a request is currently in progress.
    @Published private(set) var isLoading = false

    /// Last error message.
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private let settings = AppSettings.shared
    private let authService = AuthService.shared

    /// URL session configured for API requests.
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60 // 60 seconds for audio upload
        config.timeoutIntervalForResource = 120
        return URLSession(configuration: config)
    }()

    private init() {}

    // MARK: - Public Methods

    /// Transcribe an audio file.
    /// - Parameter audioURL: URL of the audio file to transcribe.
    /// - Returns: The transcription response.
    func transcribe(audioURL: URL) async throws -> TranscribeResponse {
        guard let token = authService.token else {
            throw APIError.notAuthenticated
        }

        guard let baseURL = URL(string: settings.serverURL) else {
            throw APIError.invalidURL
        }

        let url = baseURL.appendingPathComponent("/api/transcribe")

        // Create multipart form data request
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Build multipart body
        let httpBody = try createMultipartBody(audioURL: audioURL, boundary: boundary)
        request.httpBody = httpBody

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                return try decoder.decode(TranscribeResponse.self, from: data)

            case 401:
                // Token expired or invalid
                authService.logout()
                throw APIError.unauthorized

            case 403:
                throw APIError.notWhitelisted

            case 400:
                if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                    throw APIError.serverError(errorResponse.detail)
                }
                throw APIError.badRequest

            case 413:
                throw APIError.fileTooLarge

            case 415:
                throw APIError.unsupportedFormat

            case 500, 502, 503:
                throw APIError.serverUnavailable

            default:
                throw APIError.serverError("Server returned status \(httpResponse.statusCode)")
            }
        } catch let error as APIError {
            errorMessage = error.localizedDescription
            throw error
        } catch {
            let apiError = APIError.networkError(error.localizedDescription)
            errorMessage = apiError.localizedDescription
            throw apiError
        }
    }

    /// Check server status.
    /// - Returns: `true` if server is reachable and healthy.
    func checkServerStatus() async -> Bool {
        guard let baseURL = URL(string: settings.serverURL) else {
            return false
        }

        let url = baseURL.appendingPathComponent("/api/status")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        do {
            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            return httpResponse.statusCode == 200
        } catch {
            return false
        }
    }

    // MARK: - Private Methods

    private func createMultipartBody(audioURL: URL, boundary: String) throws -> Data {
        var body = Data()

        // Read audio file
        let audioData = try Data(contentsOf: audioURL)
        let fileName = audioURL.lastPathComponent

        // Add audio file part
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        return body
    }
}

// MARK: - Error Types

/// API error response from the server.
struct APIErrorResponse: Codable {
    let detail: String
}

/// API client errors.
enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case notAuthenticated
    case unauthorized
    case notWhitelisted
    case badRequest
    case fileTooLarge
    case unsupportedFormat
    case serverUnavailable
    case serverError(String)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .notAuthenticated:
            return "Please log in to use transcription"
        case .unauthorized:
            return "Session expired. Please log in again"
        case .notWhitelisted:
            return "You are not authorized to use this service"
        case .badRequest:
            return "Invalid request"
        case .fileTooLarge:
            return "Audio file is too large"
        case .unsupportedFormat:
            return "Unsupported audio format"
        case .serverUnavailable:
            return "Server is temporarily unavailable"
        case .serverError(let message):
            return message
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }

    /// Whether this error should trigger a notification.
    var shouldNotify: Bool {
        switch self {
        case .notAuthenticated, .unauthorized, .notWhitelisted,
             .serverUnavailable, .networkError:
            return true
        default:
            return false
        }
    }
}
