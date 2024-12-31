import Foundation
import Alamofire

enum APIError: Error {
    case invalidURL
    case decodingError
    case networkError(Error)
    case serverError(Int)
    case unauthorized
    
    var message: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .decodingError:
            return "Failed to decode response"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let code):
            return "Server error: \(code)"
        case .unauthorized:
            return "Unauthorized access"
        }
    }
}

class APIClient {
    static let shared = APIClient()
    private let baseURL = "https://api.runon.app/v1" // Replace with actual API URL
    
    private var headers: HTTPHeaders {
        var headers: HTTPHeaders = [
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
        
        if let token = UserDefaults.standard.string(forKey: "auth_token") {
            headers["Authorization"] = "Bearer \(token)"
        }
        
        return headers
    }
    
    private init() {}
    
    func request<T: Decodable>(_ endpoint: String,
                              method: HTTPMethod = .get,
                              parameters: Parameters? = nil,
                              encoding: ParameterEncoding = URLEncoding.default) async throws -> T {
        let url = baseURL + endpoint
        
        return try await withCheckedThrowingContinuation { continuation in
            AF.request(url,
                      method: method,
                      parameters: parameters,
                      encoding: encoding,
                      headers: headers)
            .validate()
            .responseDecodable(of: T.self) { response in
                switch response.result {
                case .success(let value):
                    continuation.resume(returning: value)
                case .failure(let error):
                    if let statusCode = response.response?.statusCode {
                        switch statusCode {
                        case 401:
                            continuation.resume(throwing: APIError.unauthorized)
                        default:
                            continuation.resume(throwing: APIError.serverError(statusCode))
                        }
                    } else {
                        continuation.resume(throwing: APIError.networkError(error))
                    }
                }
            }
        }
    }
    
    func setAuthToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: "auth_token")
    }
    
    func clearAuthToken() {
        UserDefaults.standard.removeObject(forKey: "auth_token")
    }
} 