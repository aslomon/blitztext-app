import Foundation

enum LlamaCppModelCatalog {
  struct Model: Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
    let fileName: String
    let downloadURL: URL
    let sha256: String
    let sizeBytes: Int64
    let estimatedRuntimeRAMGB: Double
    let parameterSize: String
    let quantization: String
    let licenseName: String
    let licenseURL: URL?
    let blurb: String

    var downloadGB: Double { Double(sizeBytes) / 1_000_000_000.0 }
  }

  static let models: [Model] = [
    Model(
      id: "qwen3-1.7b-q4-k-m",
      displayName: "Qwen3 · 1.7B · Q4_K_M",
      fileName: "Qwen3-1.7B-Q4_K_M.gguf",
      downloadURL: URL(
        string:
          "https://huggingface.co/ggml-org/Qwen3-1.7B-GGUF/resolve/main/Qwen3-1.7B-Q4_K_M.gguf?download=true"
      )!,
      sha256: "d2387ca2dbfee2ffabce7120d3770dadca0b293052bc2f0e138fdc940d9bc7b5",
      sizeBytes: 1_280_000_000,
      estimatedRuntimeRAMGB: 2.8,
      parameterSize: "1.7B",
      quantization: "Q4_K_M",
      licenseName: "Apache-2.0",
      licenseURL: URL(string: "https://huggingface.co/ggml-org/Qwen3-1.7B-GGUF"),
      blurb: "Schnelles Standardmodell für lokale Umschreibungen auf kleinen und mittleren Macs."
    )
  ]

  /// Embedding models — deliberately separate from chat `models` so they never surface in the
  /// rewrite picker. Powers semantic e-mail memory via a dedicated llama.cpp embedding server.
  static let embeddingModels: [Model] = [
    Model(
      id: "nomic-embed-text-v1.5-q8",
      displayName: "Nomic Embed Text v1.5 · Q8_0",
      fileName: "nomic-embed-text-v1.5.Q8_0.gguf",
      downloadURL: URL(
        string:
          "https://huggingface.co/nomic-ai/nomic-embed-text-v1.5-GGUF/resolve/main/nomic-embed-text-v1.5.Q8_0.gguf?download=true"
      )!,
      sha256: "3e24342164b3d94991ba9692fdc0dd08e3fd7362e0aacc396a9a5c54a544c3b7",
      sizeBytes: 146_146_432,
      estimatedRuntimeRAMGB: 0.7,
      parameterSize: "137M",
      quantization: "Q8_0",
      licenseName: "Apache-2.0",
      licenseURL: URL(string: "https://huggingface.co/nomic-ai/nomic-embed-text-v1.5-GGUF"),
      blurb: "Lokales Embedding-Modell für das semantische E-Mail-Memory (768 Dimensionen)."
    )
  ]

  /// The default embedding model backing semantic e-mail memory.
  static var defaultEmbeddingModel: Model { embeddingModels[0] }

  /// Looks up any catalog model — chat or embedding — by id. Used by the runtime and store.
  static func model(for id: String) -> Model? {
    let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
    return (models + embeddingModels).first { $0.id == trimmed }
  }

  /// Looks up a chat/rewrite model only. Used to validate a stored rewrite selection so an
  /// embedding id can never be mistaken for a rewrite model.
  static func chatModel(for id: String) -> Model? {
    let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
    return models.first { $0.id == trimmed }
  }
}
