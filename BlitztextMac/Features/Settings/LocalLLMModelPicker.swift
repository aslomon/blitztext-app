import SwiftUI

/// Inline status for the local rewrite model.
///
/// Selection and downloads live in the standalone "Lokale Modelle" window so there is only one
/// place where the active model can be chosen. This view only reports the current state and opens
/// that window.
struct LocalLLMModelPicker: View {
  @Bindable var appState: AppState

  private var manager: LocalModelManager { appState.localModelManager }

  private var selection: LocalLLMSelection {
    appState.appSettings.selectedLocalLLM
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
    if selection.runtime == .llamaCpp {
      if selectedLlamaCppModel != nil {
        BlitzStatusPill(state: .ready, label: "Gewählt")
      } else if manager.llamaCppInstalled.isEmpty {
        BlitzStatusPill(state: .download, label: "Laden")
      } else {
        BlitzStatusPill(state: .warning, label: "Auswählen")
      }
    } else if !manager.serverReachable {
      BlitzStatusPill(state: .warning, label: manager.ollamaAppInstalled ? "Starten" : "Setup")
    } else if selectedInstalledRecord != nil {
      BlitzStatusPill(state: .ready, label: "Aktiv")
    } else if manager.installed.isEmpty {
      BlitzStatusPill(state: .download, label: "Laden")
    } else {
      BlitzStatusPill(state: .warning, label: "Auswählen")
    }
  }

  // spec #6: model selected → name at 12pt .semibold; offline/no model → compact single-line hint.
  // Runtime-aware: shows the active Ollama record OR the active llama.cpp model name.
  @ViewBuilder
  private var inlineStatusRow: some View {
    if let name = selectedModelName {
      Text(name)
        .font(.system(size: 12, weight: .semibold))
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
    } else {
      Text(compactStatusHint)
        .font(.system(size: 10.5))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  /// Active model name for the current runtime (Ollama record or llama.cpp model), or nil.
  private var selectedModelName: String? {
    if selection.runtime == .llamaCpp {
      return selectedLlamaCppModel?.displayName
    }
    return selectedInstalledRecord?.name
  }

  private var compactStatusHint: String {
    if selection.runtime == .llamaCpp {
      return manager.llamaCppInstalled.isEmpty
        ? "Noch kein GGUF-Modell — Modelle einrichten."
        : "Kein Modell gewählt — Modelle verwalten."
    }
    if !manager.serverReachable {
      return "Ollama offline — Modelle einrichten."
    }
    if manager.installed.isEmpty {
      return "Noch kein Modell geladen — Modelle einrichten."
    }
    return "Kein Modell gewählt — Modelle verwalten."
  }

  private var selectedInstalledRecord: OllamaService.InstalledModel? {
    guard selection.runtime == .ollama, selection.isConfigured else { return nil }
    return manager.installed.first { OllamaService.isInstalled(selection.modelID, in: [$0.name]) }
  }

  private var selectedLlamaCppModel: LlamaCppModelCatalog.Model? {
    guard selection.runtime == .llamaCpp, selection.isConfigured else { return nil }
    return manager.installedLlamaCppModel(for: selection.modelID)
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
