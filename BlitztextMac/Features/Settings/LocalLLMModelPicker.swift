import SwiftUI

/// Inline status for the local rewrite model served by Ollama.
///
/// Selection and downloads live in the standalone "Lokale Modelle" window so there is only one
/// place where the active model can be chosen. This view only reports the current state and opens
/// that window.
struct LocalLLMModelPicker: View {
  @Bindable var appState: AppState

  private var manager: LocalModelManager { appState.localModelManager }

  private var selectedName: String {
    appState.appSettings.selectedLocalLLMModelName.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 6) {
        Text("Lokales Sprachmodell")
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
        Spacer()
        statusPill
      }

      // spec #6: two distinct inline states — model name + 'Aktiv' pill, or compact offline hint
      inlineStatusRow

      manageRow
    }
    .task {
      await manager.refresh()
    }
  }

  @ViewBuilder
  private var statusPill: some View {
    if !manager.serverReachable {
      BlitzStatusPill(state: .warning, label: manager.ollamaAppInstalled ? "Starten" : "Setup")
    } else if selectedInstalledRecord != nil {
      BlitzStatusPill(state: .ready, label: "Aktiv")
    } else if manager.installed.isEmpty {
      BlitzStatusPill(state: .download, label: "Laden")
    } else {
      BlitzStatusPill(state: .warning, label: "Auswählen")
    }
  }

  // spec #6: model selected → name at 12pt .semibold + trailing 'Aktiv' pill;
  //          offline/no model → compact single-line hint, no full sentences.
  @ViewBuilder
  private var inlineStatusRow: some View {
    if let record = selectedInstalledRecord {
      HStack(spacing: 6) {
        Text(record.name)
          .font(.system(size: 12, weight: .semibold))
          .lineLimit(1)
        Spacer()
        BlitzStatusPill(state: .ready, label: "Aktiv")
      }
    } else {
      Text(compactStatusHint)
        .font(.system(size: 10.5))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var compactStatusHint: String {
    if !manager.serverReachable {
      return "Ollama offline — Modelle einrichten."
    }
    if manager.installed.isEmpty {
      return "Noch kein Modell geladen — Modelle einrichten."
    }
    return "Kein Modell gewählt — Modelle verwalten."
  }

  private var selectedInstalledRecord: OllamaService.InstalledModel? {
    guard !selectedName.isEmpty else { return nil }
    return manager.installed.first { OllamaService.isInstalled(selectedName, in: [$0.name]) }
  }

  // MARK: - Actions
  // spec #7: 'Prüfen' demoted to icon-only PopoverIconButtonStyle(.quiet) with arrow.clockwise
  // spec #8: management button symbol changed from 'square.and.arrow.down.on.square' to 'macwindow'

  private var manageRow: some View {
    HStack(spacing: 8) {
      Button {
        NotificationCenter.default.post(name: .openLocalModelsWindow, object: nil)
      } label: {
        Label(manageButtonTitle, systemImage: "macwindow")
          .font(.system(size: 10.5, weight: .medium))
      }
      .buttonStyle(PopoverActionButtonStyle(.secondary))

      // spec #7: icon-only refresh button
      Button {
        Task { await manager.refresh() }
      } label: {
        Image(systemName: "arrow.clockwise")
      }
      .buttonStyle(PopoverIconButtonStyle(.quiet))
      .disabled(manager.isRefreshing)
      .help("Ollama-Status prüfen")
    }
  }

  private var manageButtonTitle: String {
    if !manager.serverReachable { return "Modelle einrichten …" }
    return manager.installed.isEmpty ? "Modelle laden …" : "Modelle verwalten …"
  }
}
