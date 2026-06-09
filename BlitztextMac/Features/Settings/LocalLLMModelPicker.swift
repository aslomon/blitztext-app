import SwiftUI

/// Inline status for the local rewrite model.
///
/// Selection and downloads live in the standalone "Lokale Modelle" window so there is only one
/// place where the active model can be chosen. This view only reports the current state and opens
/// that window. llama.cpp is the only local runtime.
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

      inlineStatusRow

      manageRow
    }
    .task {
      await manager.refresh()
    }
  }

  @ViewBuilder
  private var statusPill: some View {
    if selectedLlamaCppModel != nil {
      BlitzStatusPill(state: .ready, label: "Gewählt")
    } else if manager.llamaCppInstalled.isEmpty {
      BlitzStatusPill(state: .download, label: "Laden")
    } else {
      BlitzStatusPill(state: .warning, label: "Auswählen")
    }
  }

  @ViewBuilder
  private var inlineStatusRow: some View {
    if let name = selectedLlamaCppModel?.displayName {
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

  private var compactStatusHint: String {
    manager.llamaCppInstalled.isEmpty
      ? "Noch kein GGUF-Modell — Modelle einrichten."
      : "Kein Modell gewählt — Modelle verwalten."
  }

  private var selectedLlamaCppModel: LlamaCppModelCatalog.Model? {
    guard selection.isConfigured else { return nil }
    return manager.installedLlamaCppModel(for: selection.modelID)
  }

  // MARK: - Actions

  private var manageRow: some View {
    HStack(spacing: 8) {
      Button {
        NotificationCenter.default.post(name: .openLocalModelsWindow, object: nil)
      } label: {
        Label(manageButtonTitle, systemImage: "macwindow")
          .font(.system(size: 10.5, weight: .medium))
      }
      .buttonStyle(PopoverActionButtonStyle(.secondary))

      Button {
        Task { await manager.refresh() }
      } label: {
        Image(systemName: "arrow.clockwise")
      }
      .buttonStyle(PopoverIconButtonStyle(.quiet))
      .disabled(manager.isRefreshing)
      .help("Status prüfen")
    }
  }

  private var manageButtonTitle: String {
    manager.llamaCppInstalled.isEmpty ? "Modelle laden …" : "Modelle verwalten …"
  }
}
