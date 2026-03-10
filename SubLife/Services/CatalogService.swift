import Foundation

protocol CatalogServicing {
  func searchApps(query: String) async throws -> [CatalogAppSummary]
}

struct CatalogServiceConfig {
  let baseURL: URL
  let apiKey: String?
  let timeout: TimeInterval

  init(baseURL: URL, apiKey: String? = nil, timeout: TimeInterval = 15) {
    self.baseURL = baseURL
    self.apiKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines)
    self.timeout = timeout
  }

  static var live: CatalogServiceConfig {
    let info = Bundle.main.infoDictionary
    let baseURLString = (info?["CatalogAPIBaseURL"] as? String) ?? "https://api.example.com"
    let apiKey = info?["CatalogAPIKey"] as? String
    let timeout = (info?["CatalogAPITimeout"] as? NSNumber)?.doubleValue ?? 15
    let baseURL = URL(string: baseURLString) ?? URL(string: "https://api.example.com")!
    return CatalogServiceConfig(baseURL: baseURL, apiKey: apiKey, timeout: timeout)
  }
}

enum CatalogServiceError: LocalizedError, Equatable {
  case invalidQuery
  case invalidRequest
  case transport(String)
  case invalidResponse
  case httpStatus(Int)
  case decoding

  var errorDescription: String? {
    switch self {
    case .invalidQuery:
      return "検索キーワードを入力してください。"
    case .invalidRequest:
      return "リクエストの生成に失敗しました。"
    case .transport:
      return "ネットワークエラーが発生しました。"
    case .invalidResponse:
      return "サーバー応答が不正です。"
    case .httpStatus(let status):
      return "検索に失敗しました。(HTTP \(status))"
    case .decoding:
      return "検索結果の解析に失敗しました。"
    }
  }
}

struct CatalogService: CatalogServicing {
  let session: URLSession
  let config: CatalogServiceConfig

  init(session: URLSession = .shared, config: CatalogServiceConfig = .live) {
    self.session = session
    self.config = config
  }

  static var live: CatalogService {
    CatalogService()
  }

  func searchApps(query: String) async throws -> [CatalogAppSummary] {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      throw CatalogServiceError.invalidQuery
    }

    var components = URLComponents(
      url: config.baseURL.appendingPathComponent("v1/catalog/apps/search"),
      resolvingAgainstBaseURL: false
    )
    components?.queryItems = [URLQueryItem(name: "q", value: trimmed)]
    guard let url = components?.url else {
      throw CatalogServiceError.invalidRequest
    }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.timeoutInterval = config.timeout
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if let key = config.apiKey, !key.isEmpty {
      request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
    }

    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await session.data(for: request)
    } catch {
      throw CatalogServiceError.transport(error.localizedDescription)
    }

    guard let httpResponse = response as? HTTPURLResponse else {
      throw CatalogServiceError.invalidResponse
    }

    guard (200...299).contains(httpResponse.statusCode) else {
      throw CatalogServiceError.httpStatus(httpResponse.statusCode)
    }

    do {
      let payload = try JSONDecoder().decode(CatalogSearchResponse.self, from: data)
      return payload.items
    } catch {
      throw CatalogServiceError.decoding
    }
  }
}

private struct CatalogSearchResponse: Decodable {
  let items: [CatalogAppSummary]
}
