import Foundation

/// Service for managing global dictionary requests via the API.
@MainActor
class GlobalDictionaryRequestService: ObservableObject {
    /// Shared instance.
    static let shared = GlobalDictionaryRequestService()

    /// Published loading state.
    @Published private(set) var isLoading = false

    /// Published error message.
    @Published var errorMessage: String?

    private init() {}

    /// Submit a new dictionary request.
    func submitRequest(pattern: String, replacement: String, token: String) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            let body = AddGlobalRequest(pattern: pattern, replacement: replacement)
            let bodyData = try JSONEncoder().encode(body)

            _ = try await performRequest(
                endpoint: "/api/dictionary-requests",
                method: "POST",
                token: token,
                body: bodyData
            )

            isLoading = false
            return true
        } catch let error as GlobalDictionaryRequestError {
            if case .serverError(let message) = error,
               message == "Dictionary request limit reached" {
                errorMessage = LocalizationManager.shared.t("globalRequest.limitReached")
            } else {
                errorMessage = "Failed to submit request: \(error.localizedDescription)"
            }
            isLoading = false
            return false
        } catch {
            errorMessage = "Failed to submit request: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }

    private func performRequest(
        endpoint: String,
        method: String,
        token: String,
        body: Data? = nil
    ) async throws -> Data {
        let settings = AppSettings.shared
        guard let baseURL = URL(string: settings.serverURL) else {
            throw GlobalDictionaryRequestError.invalidURL
        }

        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            request.httpBody = body
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GlobalDictionaryRequestError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200, 201, 204:
            return data
        case 401:
            throw GlobalDictionaryRequestError.unauthorized
        case 400:
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw GlobalDictionaryRequestError.serverError(errorResponse.detail)
            }
            throw GlobalDictionaryRequestError.badRequest
        default:
            throw GlobalDictionaryRequestError.serverError(
                "Server returned status \(httpResponse.statusCode)"
            )
        }
    }
}

/// Request body for POST /api/dictionary-requests.
struct AddGlobalRequest: Codable {
    let pattern: String
    let replacement: String
}

/// Global dictionary request service errors.
enum GlobalDictionaryRequestError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case badRequest
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Please log in again"
        case .badRequest:
            return "Invalid request"
        case .serverError(let message):
            return message
        }
    }
}
