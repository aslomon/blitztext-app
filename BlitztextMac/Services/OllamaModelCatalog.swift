import Foundation

/// A curated catalog of local LLMs that run well through Ollama on Apple Silicon, with realistic
/// download sizes and estimated runtime memory. There is no official Ollama registry API that lists
/// models with sizes, so this list is hand-maintained against the public Ollama library. Sizes are
/// the default (Q4_K_M-class) tags and are approximate — the UI labels them "ca.".
///
/// Installed models report their *actual* on-disk size via `/api/tags`; this catalog only drives the
/// "available to download" suggestions, the RAM/disk planning, and the hardware recommendation.
enum OllamaModelCatalog {
  /// One curated, downloadable model.
  struct Model: Identifiable, Hashable {
    /// The exact Ollama tag used for `ollama pull` (e.g. "gemma3:12b").
    let tag: String
    /// Short human label (e.g. "Gemma 3 · 12B").
    let displayName: String
    /// Model family, for grouping ("Gemma 3", "Qwen 3", …).
    let family: String
    /// Parameter-count label as advertised ("12B", "30B (MoE)", …).
    let parameterLabel: String
    /// Approx. download size in gigabytes (GB, base-1000 to match Ollama's UI).
    let downloadGB: Double
    /// One-line purpose hint shown under the model.
    let blurb: String
    /// Higher = more capable (rough ordering across the whole catalog), used for the recommendation.
    let qualityRank: Int

    var id: String { tag }

    /// Estimated memory the model occupies at runtime (weights + a working context budget).
    /// Q4 weights dominate; ~1.2× file size plus a fixed headroom is a realistic, slightly
    /// conservative estimate for everyday context lengths. Labeled "ca." in the UI.
    var estimatedRuntimeRAMGB: Double {
      (downloadGB * 1.2) + 1.5
    }
  }

  /// The curated list, ordered small → large within families, families ordered by general appeal.
  static let models: [Model] = [
    // — Gemma 3 (Google) — strong all-rounders, great German —
    .init(
      tag: "gemma3:1b", displayName: "Gemma 3 · 1B", family: "Gemma 3",
      parameterLabel: "1B", downloadGB: 0.8,
      blurb: "Winzig & schnell — für schwache Macs oder reine Umformulierung.", qualityRank: 10),
    .init(
      tag: "gemma3:4b", displayName: "Gemma 3 · 4B", family: "Gemma 3",
      parameterLabel: "4B", downloadGB: 3.3,
      blurb: "Guter Kompromiss aus Tempo und Qualität für E-Mails/Diktat.", qualityRank: 40),
    .init(
      tag: "gemma3:12b", displayName: "Gemma 3 · 12B", family: "Gemma 3",
      parameterLabel: "12B", downloadGB: 8.1,
      blurb: "Spürbar bessere Formulierungen, noch flott auf M-Chips.", qualityRank: 70),
    .init(
      tag: "gemma3:27b", displayName: "Gemma 3 · 27B", family: "Gemma 3",
      parameterLabel: "27B", downloadGB: 17.0,
      blurb: "Höchste Gemma-Qualität — braucht viel RAM, aber sehr gut.", qualityRank: 90),

    // — Qwen 3 (Alibaba) — strong reasoning, multilingual —
    .init(
      tag: "qwen3:1.7b", displayName: "Qwen 3 · 1.7B", family: "Qwen 3",
      parameterLabel: "1.7B", downloadGB: 1.4,
      blurb: "Sehr schnell, kompakt — solide für kurze Texte.", qualityRank: 25),
    .init(
      tag: "qwen3:4b", displayName: "Qwen 3 · 4B", family: "Qwen 3",
      parameterLabel: "4B", downloadGB: 2.6,
      blurb: "Effizient & mehrsprachig — guter Alltagsbegleiter.", qualityRank: 45),
    .init(
      tag: "qwen3:8b", displayName: "Qwen 3 · 8B", family: "Qwen 3",
      parameterLabel: "8B", downloadGB: 5.2,
      blurb: "Kräftig bei Umformulierung und Prompts.", qualityRank: 65),
    .init(
      tag: "qwen3:14b", displayName: "Qwen 3 · 14B", family: "Qwen 3",
      parameterLabel: "14B", downloadGB: 9.3,
      blurb: "Sehr gute Qualität, ausgewogener RAM-Bedarf.", qualityRank: 80),
    .init(
      tag: "qwen3:30b", displayName: "Qwen 3 · 30B (MoE)", family: "Qwen 3",
      parameterLabel: "30B (MoE)", downloadGB: 19.0,
      blurb: "Mixture-of-Experts: Top-Qualität, läuft erstaunlich flott.", qualityRank: 95),

    // — Llama 3.x (Meta) —
    .init(
      tag: "llama3.2:3b", displayName: "Llama 3.2 · 3B", family: "Llama 3.2",
      parameterLabel: "3B", downloadGB: 2.0,
      blurb: "Klein & schnell, gut für einfache Umformulierungen.", qualityRank: 35),
    .init(
      tag: "llama3.1:8b", displayName: "Llama 3.1 · 8B", family: "Llama 3.1",
      parameterLabel: "8B", downloadGB: 4.9,
      blurb: "Bewährter Allrounder mit breiter Tool-Unterstützung.", qualityRank: 60),

    // — Specialists —
    .init(
      tag: "phi4:14b", displayName: "Phi-4 · 14B", family: "Phi-4",
      parameterLabel: "14B", downloadGB: 9.1,
      blurb: "Microsofts starkes Reasoning-Modell, dicht & präzise.", qualityRank: 78),
    .init(
      tag: "mistral:7b", displayName: "Mistral · 7B", family: "Mistral",
      parameterLabel: "7B", downloadGB: 4.4,
      blurb: "Schnell und sehr zuverlässig fürs Umschreiben.", qualityRank: 55),
    .init(
      tag: "deepseek-r1:8b", displayName: "DeepSeek-R1 · 8B", family: "DeepSeek-R1",
      parameterLabel: "8B", downloadGB: 5.2,
      blurb: "Denkt in Schritten — stark für komplexe Prompts.", qualityRank: 68),
  ]

  /// Look up a catalog entry by its exact tag.
  static func model(forTag tag: String) -> Model? {
    models.first { $0.tag == tag }
  }
}
