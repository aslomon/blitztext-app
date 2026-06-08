import Foundation

protocol EmbeddingProvider: Sendable {
  var modelID: String { get }
  func embed(_ text: String) async throws -> [Double]
}

struct OllamaEmbeddingProvider: EmbeddingProvider {
  static let defaultModelID = "nomic-embed-text"

  let modelID: String
  private let session: URLSession
  private let endpointURL: URL?

  init(
    modelID: String = Self.defaultModelID,
    session: URLSession = .shared,
    baseURLString: String = OllamaService.baseURLString
  ) {
    self.modelID = modelID
    self.session = session
    self.endpointURL = URL(string: "\(baseURLString)/api/embed")
  }

  func embed(_ text: String) async throws -> [Double] {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { throw OllamaEmbeddingError.emptyInput }
    guard let endpointURL else { throw OllamaEmbeddingError.invalidBaseURL }

    var request = URLRequest(url: endpointURL)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(EmbedRequest(model: modelID, input: trimmed))

    let (data, response): (Data, URLResponse)
    do {
      (data, response) = try await session.data(for: request)
    } catch {
      throw OllamaEmbeddingError.serverUnreachable
    }

    guard let http = response as? HTTPURLResponse else {
      throw OllamaEmbeddingError.serverUnreachable
    }
    guard http.statusCode == 200 else {
      throw OllamaEmbeddingError.httpStatus(http.statusCode)
    }
    return try Self.decodeEmbeddingResponse(data)
  }

  static func decodeEmbeddingResponse(_ data: Data) throws -> [Double] {
    let decoder = JSONDecoder()
    if let response = try? decoder.decode(EmbedResponse.self, from: data),
      let embedding = response.embeddings.first,
      !embedding.isEmpty
    {
      return embedding
    }
    if let response = try? decoder.decode(LegacyEmbeddingResponse.self, from: data),
      !response.embedding.isEmpty
    {
      return response.embedding
    }
    throw OllamaEmbeddingError.invalidResponse
  }

  private struct EmbedRequest: Encodable {
    let model: String
    let input: String
  }

  private struct EmbedResponse: Decodable {
    let embeddings: [[Double]]
  }

  private struct LegacyEmbeddingResponse: Decodable {
    let embedding: [Double]
  }
}

enum OllamaEmbeddingError: LocalizedError, Equatable {
  case emptyInput
  case serverUnreachable
  case invalidBaseURL
  case httpStatus(Int)
  case invalidResponse

  var errorDescription: String? {
    switch self {
    case .emptyInput:
      return "Kein Text für das lokale Embedding vorhanden."
    case .serverUnreachable:
      return "Ollama ist nicht erreichbar. Läuft die Ollama-App?"
    case .invalidBaseURL:
      return "Die lokale Ollama-Adresse ist ungültig."
    case .httpStatus(let code):
      return "Ollama antwortete beim Embedding mit Status \(code)."
    case .invalidResponse:
      return "Ollama lieferte kein gültiges Embedding."
    }
  }
}
