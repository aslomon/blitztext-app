import SwiftUI

/// Tab "Prompts": the three configurable rewrite modes (Textverbesserung, Dampf ablassen,
/// Emoji/Social). Each card owns its name, backend, model, prompt and reset.
struct PromptsSettingsView: View {
  @Bindable var appState: AppState
  /// Jump to another settings tab (e.g. "Zu Modelle" when no rewrite engine is connected yet).
  let selectTab: (Int) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Modi formulieren deinen Text um — Schreibstil, Kontext und eigene Anweisung pro Modus.")
        .font(.system(size: 10.5))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      if !appState.hasAnyRewriteEngine {
        EmptyStateCard(
          icon: "wand.and.stars",
          title: "Noch kein Umschreib-Modell verbunden",
          caption:
            "Modi formulieren Text nur um, wenn ein Umschreib-Modell bereitsteht — der OpenAI-Key "
            + "oder ein lokales Ollama-Modell. Richte zuerst eine Engine ein.",
          accent: .purple,
          buttonLabel: "Zu Modelle",
          action: { selectTab(1) }
        )
      }

      ModeCardView(appState: appState, type: .textImprover)
      ModeCardView(appState: appState, type: .dampfAblassen)
      ModeCardView(appState: appState, type: .emojiText)
    }
    .padding(16)
  }
}
