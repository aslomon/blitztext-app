import Foundation

/// Picker-facing helpers for `OllamaService`: turning the curated suggestions + actually-pulled
/// models into the menu rows shown by `LocalLLMModelPicker`, with honest "geladen/nicht geladen"
/// labelling. Split out of `OllamaService` to keep the core query/transfer file under the size cap.
extension OllamaService {
  /// One selectable picker entry plus its honest pulled/not-pulled state. Installed models are
  /// listed first (so the user's real models are most prominent), curated suggestions follow.
  struct PickerModel: Identifiable, Hashable {
    let name: String
    let isInstalled: Bool

    var id: String { name }

    /// Picker-ready label. Installed reads "name · geladen"; a curated-but-missing model reads
    /// "name · nicht geladen" so it can never be mistaken for something ready to run.
    var menuLabel: String {
      isInstalled ? "\(name) · geladen" : "\(name) · nicht geladen"
    }
  }

  /// Curated defaults unioned with any installed models, de-duplicated, preserving curated order
  /// first. Used to populate the picker so a model the user already pulled is always selectable.
  static func pickerModelNames(installed: [String]) -> [String] {
    var seen = Set<String>()
    var result: [String] = []
    for name in curatedModelNames + installed {
      let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty, !seen.contains(trimmed) else { continue }
      seen.insert(trimmed)
      result.append(trimmed)
    }
    return result
  }

  /// True when `candidate` matches one of the actually-pulled `installed` tags. Ollama reports
  /// fully-qualified tags (e.g. "gemma3:latest"); a curated bare name like "gemma3" must match
  /// "gemma3:latest", while an explicit tag like "gemma3:12b" must match exactly.
  static func isInstalled(_ candidate: String, in installed: [String]) -> Bool {
    let target = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !target.isEmpty else { return false }
    let normalizedTarget = target.contains(":") ? target : "\(target):latest"
    return installed.contains { rawInstalled in
      let name = rawInstalled.trimmingCharacters(in: .whitespacesAndNewlines)
      let normalizedInstalled = name.contains(":") ? name : "\(name):latest"
      return normalizedInstalled == normalizedTarget || name == target
    }
  }

  /// Ordered picker rows: actually-installed models first (each flagged installed), then curated
  /// suggestions that are NOT yet pulled (flagged not-installed). De-duplicated across both.
  static func pickerModels(installed: [String]) -> [PickerModel] {
    var seen = Set<String>()
    var result: [PickerModel] = []

    func add(_ name: String, isInstalled: Bool) {
      let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { return }
      result.append(PickerModel(name: trimmed, isInstalled: isInstalled))
    }

    for name in installed { add(name, isInstalled: true) }
    for name in curatedModelNames where !isInstalled(name, in: installed) {
      add(name, isInstalled: false)
    }
    return result
  }
}
