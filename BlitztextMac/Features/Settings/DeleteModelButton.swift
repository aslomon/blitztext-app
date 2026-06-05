import SwiftUI

/// A red "Entfernen" button that confirms before deleting an installed Ollama model (which frees
/// several GB on disk). Shared by the inline catalog rows and the installed-models list so the
/// destructive flow + copy stays consistent in both places.
struct DeleteModelButton: View {
  /// Label shown in the confirmation title (e.g. "Gemma 3 · 12B" or the raw tag).
  let displayName: String
  /// The exact tag passed to `ollama rm` / DELETE /api/delete.
  let deleteTag: String
  /// On-disk size freed by the delete, if known (for the confirmation message).
  let freedSizeGB: Double?
  let manager: LocalModelManager

  @State private var confirming = false

  var body: some View {
    Button("Entfernen") { confirming = true }
      .buttonStyle(.plain)
      .font(.system(size: 10.5, weight: .medium))
      .foregroundStyle(.red.opacity(0.85))
      .confirmationDialog(
        "\(displayName) entfernen?",
        isPresented: $confirming,
        titleVisibility: .visible
      ) {
        Button("Entfernen", role: .destructive) { manager.delete(deleteTag) }
        Button("Abbrechen", role: .cancel) {}
      } message: {
        if let freedSizeGB {
          Text(
            "Gibt \(SystemCapabilities.formatGB(freedSizeGB)) auf der Disk frei. "
              + "Du kannst das Modell später jederzeit neu laden.")
        } else {
          Text("Du kannst das Modell später jederzeit neu laden.")
        }
      }
  }
}
