import SwiftUI

/// Tab "Prompts": every visible mode. Each card owns its name, hotkey, behavior and reset.
struct PromptsSettingsView: View {
  @Bindable var appState: AppState
  /// Jump to another settings tab (e.g. "Zu Modelle" when no rewrite engine is connected yet).
  let selectTab: (Int) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack(spacing: 8) {
        SectionLabel(text: "Modi")
        BlitzStatusPill(
          state: appState.hasAnyRewriteEngine ? .ready : .warning,
          label: appState.hasAnyRewriteEngine ? "Bereit" : "Modell fehlt"
        )
        Spacer()
        addModeMenu
      }

      if !appState.hasAnyRewriteEngine {
        EmptyStateCard(
          icon: "wand.and.stars",
          title: "Noch kein Umschreib-Modell verbunden",
          caption:
            "Modi formulieren Text nur um, wenn ein Umschreib-Modell bereitsteht — der OpenAI-Key "
            + "oder ein lokales llama.cpp-Modell. Richte zuerst eine Engine ein.",
          accent: .purple,
          buttonLabel: "Zu Modelle",
          action: { selectTab(1) }
        )
      }

      ForEach(visibleModes) { config in
        ModeCardView(appState: appState, config: config)
      }

      InfoDisclosure("Was Modi tun") {
        Text(
          "Freitext fügt nur das Diktat ein. E-Mail, Prompt und Social formulieren dein Diktat mit eigenen Anweisungen um."
        )
      }
    }
    .padding(16)
  }

  private var visibleModes: [ModeConfig] {
    appState.orderedModeConfigs.filter { $0.slot != .localTranscription }
  }

  private var addModeMenu: some View {
    Menu {
      ForEach(ModeTemplate.allCases) { template in
        Button {
          appState.addMode(template: template)
        } label: {
          Label(template.displayName, systemImage: template.icon)
        }
      }
    } label: {
      Image(systemName: "plus")
    }
    .buttonStyle(PopoverIconButtonStyle(.secondary))
    .help("Modus hinzufügen")
    .accessibilityLabel("Modus hinzufügen")
  }
}
