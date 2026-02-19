import Foundation

// MARK: - API Models

struct LoginRequest: Encodable {
    let email: String
    let password: String
    let oa: Bool
}

struct LoginResponse: Decodable {
    let token: String
}

struct OctopusService: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String

    // Accept additional fields without failing decode
    enum CodingKeys: String, CodingKey {
        case id
        case name
    }
}

/// Wrapper for the paginated /admin/api/services response.
struct ServicesListResponse: Decodable, Sendable {
    let data: [OctopusService]
    // Other fields (installedCount, total, page, etc.) are ignored.
}

// MARK: - SignOn Response Models

struct SignOnCertificate: Decodable, Sendable {
    let id: Int
    let publicKey: String  // Base64-encoded PEM certificate
}

struct SignOnServiceKey: Decodable, Sendable {
    let id: Int
    let name: String
    let enabled: Bool
    let key: String
}

struct SignOnResponse: Decodable, Sendable {
    let id: Int
    let restEndpoint: String           // → config.server
    let certificate: SignOnCertificate  // .publicKey → config.certificate
    let serviceKey: SignOnServiceKey    // .key → config.service

    // Accept additional fields (mfa, sso, tokenTimeout, bypass, message, etc.)
    // without failing decode by only declaring the fields we need.
}

// MARK: - API Errors

enum OctopusAPIError: LocalizedError {
    case invalidURL
    case invalidCredentials
    case authenticationTimeout
    case networkError(String)
    case serverError(Int, String)
    case decodingError(String)
    case noToken

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL. Please check the format (e.g. https://server.doubleoctopus.io)."
        case .invalidCredentials:
            return "Invalid email or password."
        case .authenticationTimeout:
            return "Authentication timed out. The push notification may not have been approved."
        case .networkError(let msg):
            return "Network error: \(msg)"
        case .serverError(let code, let msg):
            return "Server error (\(code)): \(msg)"
        case .decodingError(let msg):
            return "Failed to parse server response: \(msg)"
        case .noToken:
            return "No authentication token available. Please log in first."
        }
    }
}

// MARK: - API Client

final class OctopusAPIClient: Sendable {
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - Login (Password)

    /// Authenticate with email and password (oa: false). Returns Bearer token.
    func loginWithPassword(serverURL: String, email: String, password: String) async throws -> String {
        let url = try buildURL(serverURL: serverURL, path: "/admin/api/auth/login")
        let body = LoginRequest(email: email, password: password, oa: false)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        request.timeoutInterval = 30

        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response, data: data)

        do {
            let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
            return loginResponse.token
        } catch {
            throw OctopusAPIError.decodingError(error.localizedDescription)
        }
    }

    // MARK: - Login (Octopus Authenticator — long poll)

    /// Authenticate with Octopus Authenticator push (oa: true).
    /// This is a long-polling request — it blocks until the admin approves on their device.
    func loginWithAuthenticator(serverURL: String, email: String) async throws -> String {
        let url = try buildURL(serverURL: serverURL, path: "/admin/api/auth/login")
        let body = LoginRequest(email: email, password: "", oa: true)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        request.timeoutInterval = 120

        // Dedicated session with extended timeout for long-polling
        let longPollConfig = URLSessionConfiguration.default
        longPollConfig.timeoutIntervalForRequest = 120
        longPollConfig.timeoutIntervalForResource = 180
        let longPollSession = URLSession(configuration: longPollConfig)

        do {
            let (data, response) = try await longPollSession.data(for: request)
            try validateHTTPResponse(response, data: data)

            do {
                let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
                return loginResponse.token
            } catch {
                throw OctopusAPIError.decodingError(error.localizedDescription)
            }
        } catch let error as URLError where error.code == .timedOut {
            throw OctopusAPIError.authenticationTimeout
        }
    }

    // MARK: - List Services

    /// Fetch the list of available services from the Octopus server.
    func listServices(serverURL: String, token: String) async throws -> [OctopusService] {
        let url = try buildURL(serverURL: serverURL, path: "/admin/api/services")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response, data: data)

        do {
            let wrapper = try JSONDecoder().decode(ServicesListResponse.self, from: data)
            return wrapper.data
        } catch {
            throw OctopusAPIError.decodingError(error.localizedDescription)
        }
    }

    // MARK: - Fetch Service SignOn Configuration

    /// Fetch the signOn configuration (JSON) for a specific service.
    /// Returns parsed SignOnResponse with restEndpoint, certificate, and serviceKey.
    func fetchServiceSignOn(serverURL: String, token: String, serviceId: Int) async throws -> SignOnResponse {
        let url = try buildURL(serverURL: serverURL, path: "/admin/api/services/\(serviceId)/signOn")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response, data: data)

        do {
            return try JSONDecoder().decode(SignOnResponse.self, from: data)
        } catch {
            throw OctopusAPIError.decodingError(error.localizedDescription)
        }
    }

    // MARK: - Helpers

    private func buildURL(serverURL: String, path: String) throws -> URL {
        var baseURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !baseURL.hasPrefix("https://") && !baseURL.hasPrefix("http://") {
            baseURL = "https://" + baseURL
        }
        if baseURL.hasSuffix("/") {
            baseURL.removeLast()
        }

        guard let url = URL(string: baseURL + path) else {
            throw OctopusAPIError.invalidURL
        }
        return url
    }

    private func validateHTTPResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OctopusAPIError.networkError("Invalid response type")
        }
        switch httpResponse.statusCode {
        case 200...299:
            return // Success
        case 401:
            throw OctopusAPIError.invalidCredentials
        case 403:
            throw OctopusAPIError.serverError(403, "Access denied. Check admin permissions.")
        default:
            let body = String(data: data, encoding: .utf8) ?? "No response body"
            throw OctopusAPIError.serverError(httpResponse.statusCode, body)
        }
    }
}
