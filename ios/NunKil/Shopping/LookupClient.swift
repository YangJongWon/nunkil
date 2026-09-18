import Foundation

struct BackendConfig {
  let baseURL: URL
  let token: String

  /// Reads the values Secrets.xcconfig substitutes into Info.plist.
  static func fromBundle(_ bundle: Bundle = .main) -> BackendConfig? {
    guard
      let urlString = bundle.object(forInfoDictionaryKey: "NunKilBackendURL") as? String,
      let token = bundle.object(forInfoDictionaryKey: "NunKilBackendToken") as? String,
      !urlString.isEmpty, !token.isEmpty, !urlString.contains("$("),
      let url = URL(string: urlString)
    else { return nil }
    return BackendConfig(baseURL: url, token: token)
  }
}

enum LookupError: LocalizedError {
  case notConfigured
  case unreachable
  case http(status: Int, detail: String)

  var errorDescription: String? {
    switch self {
    case .notConfigured:
      return "조회 서버 주소가 설정되지 않았어요."
    case .unreachable:
      return "조회 서버에 연결할 수 없어요."
    case .http(let status, let detail):
      return detail.isEmpty ? "조회 서버 오류 \(status)" : detail
    }
  }
}

/// Asks the backend what a barcode or a piece of text is, and what it costs.
final class LookupClient: Sendable {
  private let config: BackendConfig?
  private let session: URLSession

  init(config: BackendConfig?, session: URLSession = .shared) {
    self.config = config
    self.session = session
  }

  static func fromBundle() -> LookupClient {
    LookupClient(config: .fromBundle())
  }

  static let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return decoder
  }()

  func lookup(jan: String, region: Region) async throws -> ProductLookup {
    try await get([
      URLQueryItem(name: "jan", value: jan), URLQueryItem(name: "region", value: region.rawValue),
    ])
  }

  func lookup(text: String, region: Region) async throws -> ProductLookup {
    try await get([
      URLQueryItem(name: "q", value: text), URLQueryItem(name: "region", value: region.rawValue),
    ])
  }

  private func get(_ query: [URLQueryItem]) async throws -> ProductLookup {
    guard let config,
      var components = URLComponents(url: config.baseURL.appendingPathComponent("product"), resolvingAgainstBaseURL: false)
    else { throw LookupError.notConfigured }
    components.queryItems = query
    guard let url = components.url else { throw LookupError.notConfigured }

    var request = URLRequest(url: url)
    request.setValue("Bearer \(config.token)", forHTTPHeaderField: "Authorization")
    // The wearer is standing in a shop holding something up: a slow answer is a
    // failed answer.
    request.timeoutInterval = 8

    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await session.data(for: request)
    } catch is URLError {
      throw LookupError.unreachable
    }
    guard let http = response as? HTTPURLResponse else { throw LookupError.unreachable }
    guard (200..<300).contains(http.statusCode) else {
      struct ErrorBody: Decodable { let detail: String }
      let detail = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.detail ?? ""
      throw LookupError.http(status: http.statusCode, detail: detail)
    }
    return try Self.decoder.decode(ProductLookup.self, from: data)
  }
}
