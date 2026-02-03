import Foundation

/// Service for managing user dictionary entries via the API.
@MainActor
class DictionaryService: ObservableObject {
    /// Shared instance.
    static let shared = DictionaryService()

    /// Published dictionary entries.
    @Published private(set) var entries: [DictionaryEntry] = []

    /// Published loading state.
    @Published private(set) var isLoading = false

    /// Published error message.
    @Published var errorMessage: String?

    /// Maximum number of entries allowed.
    let maxEntries = 100

    /// Current entry count.
    var entryCount: Int { entries.count }

    /// Whether user can add more entries.
    var canAddMore: Bool { entryCount < maxEntries }

    private init() {}

    // MARK: - API Methods

    /// Fetch all dictionary entries from the server.
    func fetchEntries(token: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await performRequest(
                endpoint: "/api/dictionary",
                method: "GET",
                token: token
            )

            let decoder = JSONDecoder()
            let result = try decoder.decode(DictionaryListResponse.self, from: response)
            entries = result.entries
        } catch {
            errorMessage = "Failed to load dictionary: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Add a new dictionary entry.
    func addEntry(pattern: String, replacement: String, token: String) async -> Bool {
        guard canAddMore else {
            errorMessage = "Dictionary limit reached (100 entries)"
            return false
        }

        isLoading = true
        errorMessage = nil

        do {
            let body = AddEntryRequest(pattern: pattern, replacement: replacement)
            let bodyData = try JSONEncoder().encode(body)

            let response = try await performRequest(
                endpoint: "/api/dictionary",
                method: "POST",
                token: token,
                body: bodyData
            )

            let decoder = JSONDecoder()
            let newEntry = try decoder.decode(DictionaryEntry.self, from: response)
            entries.append(newEntry)
            isLoading = false
            return true
        } catch {
            errorMessage = "Failed to add entry: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }

    /// Delete a dictionary entry.
    func deleteEntry(id: Int, token: String) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            _ = try await performRequest(
                endpoint: "/api/dictionary/\(id)",
                method: "DELETE",
                token: token
            )

            entries.removeAll { $0.id == id }
            isLoading = false
            return true
        } catch {
            errorMessage = "Failed to delete entry: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }

    // MARK: - Private Methods

    private func performRequest(
        endpoint: String,
        method: String,
        token: String,
        body: Data? = nil
    ) async throws -> Data {
        let settings = AppSettings.shared
        guard let baseURL = URL(string: settings.serverURL) else {
            throw DictionaryError.invalidURL
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
            throw DictionaryError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200, 201, 204:
            return data
        case 401:
            throw DictionaryError.unauthorized
        case 400:
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw DictionaryError.serverError(errorResponse.detail)
            }
            throw DictionaryError.badRequest
        case 404:
            throw DictionaryError.notFound
        default:
            throw DictionaryError.serverError("Server returned status \(httpResponse.statusCode)")
        }
    }
}

// MARK: - Data Models

/// A dictionary entry.
struct DictionaryEntry: Identifiable, Codable, Equatable {
    let id: Int
    let pattern: String
    let replacement: String
}

/// Response from GET /api/dictionary.
struct DictionaryListResponse: Codable {
    let entries: [DictionaryEntry]
    let count: Int
    let limit: Int
}

/// Request body for POST /api/dictionary.
struct AddEntryRequest: Codable {
    let pattern: String
    let replacement: String
}

/// Error response from the server.
struct ErrorResponse: Codable {
    let detail: String
}

/// Dictionary service errors.
enum DictionaryError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case badRequest
    case notFound
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
        case .notFound:
            return "Entry not found"
        case .serverError(let message):
            return message
        }
    }
}
