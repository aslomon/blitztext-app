import Foundation

/// Lightweight client for the local Ollama server (https://ollama.com).
/// Used by the settings UI to show a reachability status and the list of installed models,
/// plus a curated default list for the model picker. No SPM dependency — plain `URLSession`.
/// All traffic targets `localhost` only; nothing leaves the machine.
enum OllamaService {
  /// Default local Ollama base URL.
  static let baseURLString = "http://localhost:11434"

  /// User-facing label for the local backend.
  static let backendLabel = "Lokal (Ollama)"

  /// No model is pre-selected for new installs. Pre-selecting a curated name (e.g. "gemma3")
  /// would falsely imply readiness before the user has actually pulled anything, so a fresh
  /// install starts in the honest "Kein lokales Modell" state. An empty string is the sentinel
  /// for "nothing selected" and is treated as not-configured everywhere downstream.
  static let defaultModelName = ""

  /// Friendly suggestion surfaced in copy/hints (`ollama pull <name>`). NOT auto-selected.
  static let suggestedModelName = "gemma3"

  /// Curated picker suggestions. These are real Ollama tags (verified against the Ollama library):
  /// `gemma3`/`gemma3:12b` (Gemma 3), `qwen3`/`qwen3:8b` (Qwen 3), `llama3.2` (Llama 3.2). They are
  /// only shown as "nicht geladen" suggestions — never as installed unless `/api/tags` confirms it.
  static let curatedModelNames = [
    "gemma3",
    "gemma3:12b",
    "qwen3",
    "qwen3:8b",
    "llama3.2",
  ]

  private static let tagsURL = URL(string: "\(baseURLString)/api/tags")!
  private static let pullURL = URL(string: "\(baseURLString)/api/pull")!
  private static let deleteURL = URL(string: "\(baseURLString)/api/delete")!

  private static let session: URLSession = {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.waitsForConnectivity = false
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    // Short budget: this only gates a status line / picker, never the actual rewrite.
    configuration.timeoutIntervalForRequest = 2
    configuration.timeoutIntervalForResource = 2
    return URLSession(configuration: configuration)
  }()

  /// Long-lived session for model downloads (pull) and deletes — these can take many minutes,
  /// so the 2-second status session must never be used for them.
  private static let transferSession: URLSession = {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.waitsForConnectivity = true
    configuration.timeoutIntervalForRequest = 60
    configuration.timeoutIntervalForResource = 60 * 60 * 6  // 6h ceiling for very large pulls
    return URLSession(configuration: configuration)
  }()

  private struct TagsResponse: Decodable {
    struct Details: Decodable {
      let parameterSize: String?
      let quantizationLevel: String?

      enum CodingKeys: String, CodingKey {
        case parameterSize = "parameter_size"
        case quantizationLevel = "quantization_level"
      }
    }

    struct Model: Decodable {
      let name: String
      let size: Int64?
      let details: Details?
    }

    let models: [Model]?
  }

  /// A model that is actually pulled into the local Ollama install, with its real on-disk size.
  struct InstalledModel: Identifiable, Hashable {
    /// Fully-qualified tag, e.g. "gemma3:latest".
    let name: String
    /// On-disk size in bytes, as reported by Ollama.
    let sizeBytes: Int64
    /// Advertised parameter count (e.g. "4.3B"), if Ollama reports it.
    let parameterSize: String?
    /// Quantization level (e.g. "Q4_K_M"), if reported.
    let quantization: String?

    var id: String { name }

    /// Size in gigabytes (base-1000 to match Ollama's own UI).
    var sizeGB: Double { Double(sizeBytes) / 1_000_000_000.0 }
  }

  /// Streamed progress for an in-flight `pull`.
  struct PullProgress: Equatable {
    /// Server status line, e.g. "pulling manifest", "downloading", "verifying sha256 digest".
    let status: String
    /// Bytes downloaded so far for the current layer, if known.
    let completed: Int64?
    /// Total bytes for the current layer, if known.
    let total: Int64?

    /// 0...1 fraction for the current layer, or nil when the server hasn't sent byte counts yet.
    var fraction: Double? {
      guard let total, total > 0, let completed else { return nil }
      return min(1.0, max(0.0, Double(completed) / Double(total)))
    }
  }

  /// Errors surfaced by `pull`/`delete`.
  enum OllamaTransferError: LocalizedError {
    case serverUnreachable
    case httpStatus(Int)
    case server(String)

    var errorDescription: String? {
      switch self {
      case .serverUnreachable:
        return "Ollama ist nicht erreichbar. Läuft die Ollama-App?"
      case .httpStatus(let code):
        return "Ollama antwortete mit Status \(code)."
      case .server(let message):
        return message
      }
    }
  }

  /// True when the local Ollama server answers `GET /api/tags`. Never throws — a down server
  /// (connection refused / timeout) simply returns `false`.
  static func statusCheck() async -> Bool {
    do {
      let (_, response) = try await session.data(from: tagsURL)
      return (response as? HTTPURLResponse)?.statusCode == 200
    } catch {
      return false
    }
  }

  /// Names of the models currently pulled into the local Ollama install (e.g. "gemma3:latest").
  /// Returns an empty array when the server is unreachable or has no models.
  static func installedModels() async -> [String] {
    do {
      let (data, response) = try await session.data(from: tagsURL)
      guard (response as? HTTPURLResponse)?.statusCode == 200 else { return [] }
      let decoded = try JSONDecoder().decode(TagsResponse.self, from: data)
      return decoded.models?.map(\.name) ?? []
    } catch {
      return []
    }
  }

  /// Installed models with their real on-disk size and details, sorted largest-first.
  /// Returns an empty array when the server is unreachable or has no models.
  static func installedModelsDetailed() async -> [InstalledModel] {
    do {
      let (data, response) = try await session.data(from: tagsURL)
      guard (response as? HTTPURLResponse)?.statusCode == 200 else { return [] }
      let decoded = try JSONDecoder().decode(TagsResponse.self, from: data)
      let models =
        decoded.models?.map {
          InstalledModel(
            name: $0.name,
            sizeBytes: $0.size ?? 0,
            parameterSize: $0.details?.parameterSize,
            quantization: $0.details?.quantizationLevel
          )
        } ?? []
      return models.sorted { $0.sizeBytes > $1.sizeBytes }
    } catch {
      return []
    }
  }

  // MARK: - Pull (download) & delete

  private struct PullRequest: Encodable {
    let model: String
    let stream: Bool
  }

  private struct PullLine: Decodable {
    let status: String?
    let completed: Int64?
    let total: Int64?
    let error: String?
  }

  private struct DeleteRequest: Encodable {
    let model: String
  }

  /// Download (`ollama pull`) a model by tag, streaming progress. Throws `OllamaTransferError`
  /// on an unreachable server, a non-200 response, or a server-reported error line. Honors task
  /// cancellation — cancelling the surrounding `Task` aborts the download.
  static func pull(
    _ tag: String,
    onProgress: @escaping @Sendable (PullProgress) -> Void
  ) async throws {
    var request = URLRequest(url: pullURL)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(PullRequest(model: tag, stream: true))

    let (bytes, response): (URLSession.AsyncBytes, URLResponse)
    do {
      (bytes, response) = try await transferSession.bytes(for: request)
    } catch {
      throw OllamaTransferError.serverUnreachable
    }

    guard let http = response as? HTTPURLResponse else {
      throw OllamaTransferError.serverUnreachable
    }
    guard http.statusCode == 200 else {
      throw OllamaTransferError.httpStatus(http.statusCode)
    }

    let decoder = JSONDecoder()
    for try await line in bytes.lines {
      try Task.checkCancellation()
      let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { continue }
      guard let parsed = try? decoder.decode(PullLine.self, from: data) else { continue }
      if let serverError = parsed.error {
        throw OllamaTransferError.server(serverError)
      }
      onProgress(
        PullProgress(
          status: parsed.status ?? "",
          completed: parsed.completed,
          total: parsed.total
        )
      )
    }
  }

  /// Delete (`ollama rm`) an installed model by tag. Throws `OllamaTransferError` on failure.
  static func delete(_ tag: String) async throws {
    var request = URLRequest(url: deleteURL)
    request.httpMethod = "DELETE"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(DeleteRequest(model: tag))

    let (_, response): (Data, URLResponse)
    do {
      (_, response) = try await transferSession.data(for: request)
    } catch {
      throw OllamaTransferError.serverUnreachable
    }
    guard let http = response as? HTTPURLResponse else {
      throw OllamaTransferError.serverUnreachable
    }
    guard http.statusCode == 200 else {
      throw OllamaTransferError.httpStatus(http.statusCode)
    }
  }

}
