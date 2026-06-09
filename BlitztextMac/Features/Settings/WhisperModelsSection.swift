import SwiftUI

/// Whisper (WhisperKit) transcription models inside the unified "Lokale Modelle" window. Mirrors the
/// Ollama installed-row pattern so all local model types are loaded, activated, re-downloaded and
/// deleted the same way. Disk-truth state comes from `LocalTranscriptionService`; mutations route
/// through `AppState`. Everything stays on the device.
struct WhisperModelsSection: View {
  @Bindable var appState: AppState

  /// All catalog + installed Whisper models. Recomputed whenever observed AppState mutates (download
  /// progress, selection, error) — each recompute re-reads the disk so install/delete reflect live.
  private var models: [LocalTranscriptionModel] {
    LocalTranscriptionService.modelOptions()
  }

  private var installedCount: Int {
    models.filter(\.isInstalled).count
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      SectionLabel(text: "Transkription · Whisper (\(installedCount))")

      ForEach(models) { model in
        modelRow(model)
      }

      if appState.isDownloadingLocalModel {
        downloadProgressRow
      }

      if let error = appState.localModelDownloadErrorText {
        Text(error)
          .font(.system(size: 10.5)).foregroundStyle(.red)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func modelRow(_ model: LocalTranscriptionModel) -> some View {
    let isActive = appState.selectedLocalModelName == model.id
    let sizeText = LocalTranscriptionModel.sizeLabel(for: model.id)
    return HStack(spacing: 10) {
      Image(systemName: model.isInstalled ? "checkmark.circle.fill" : "arrow.down.circle")
        .font(.system(size: 13))
        .foregroundStyle(model.isInstalled ? .green : .blue)
      VStack(alignment: .leading, spacing: 1) {
        Text(model.displayName).font(.system(size: 12, weight: .semibold))
        Text(subtitle(installed: model.isInstalled, sizeText: sizeText))
          .font(.system(size: 10)).foregroundStyle(.secondary)
      }
      Spacer()
      rowActions(model, isActive: isActive, sizeText: sizeText)
        .disabled(appState.isDownloadingLocalModel)
    }
    .padding(10)
    .liquidGlassCard(cornerRadius: 8)
  }

  @ViewBuilder
  private func rowActions(
    _ model: LocalTranscriptionModel, isActive: Bool, sizeText: String?
  ) -> some View {
    if model.isInstalled {
      if isActive {
        BlitzStatusPill(state: .ready, label: "Aktiv")
      } else {
        Button {
          appState.appSettings.selectedLocalTranscriptionModelName = model.id
        } label: {
          Label("Nutzen", systemImage: "checkmark.circle")
        }
        .buttonStyle(PopoverActionButtonStyle(.primary))
      }
      Button {
        appState.reinstallLocalTranscriptionModel(model.id)
      } label: {
        Image(systemName: "arrow.clockwise")
      }
      .buttonStyle(PopoverIconButtonStyle(.quiet))
      .help("Neu laden (löscht und lädt frisch)")
      DeleteModelButton(
        displayName: model.displayName,
        freedSizeText: sizeText,
        onDelete: { appState.deleteLocalTranscriptionModel(model.id) }
      )
    } else {
      Button {
        appState.installLocalModel(named: model.id)
      } label: {
        Label("Laden", systemImage: "arrow.down.circle.fill")
          .font(.system(size: 11.5, weight: .semibold))
      }
      .buttonStyle(PopoverActionButtonStyle(.primary))
    }
  }

  private var downloadProgressRow: some View {
    VStack(alignment: .leading, spacing: 4) {
      ProgressView(value: appState.localModelDownloadProgress ?? 0)
      Text(appState.localModelDownloadStatusText ?? "Modell wird geladen …")
        .font(.system(size: 10.5)).foregroundStyle(.secondary)
    }
  }

  private func subtitle(installed: Bool, sizeText: String?) -> String {
    let size = sizeText ?? "—"
    return installed ? "Lokal · \(size)" : "Nicht geladen · \(size)"
  }
}
