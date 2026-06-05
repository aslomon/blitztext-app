import SwiftUI

/// Step 4: the local engines. The Whisper picker + install controls mirror `ModelsSettingsView`'s
/// transcription block (only relevant in offline mode); the Ollama rewrite model is always shown,
/// but labelled Optional because online rewriting never needs it.
struct ModelsStepView: View {
  @Bindable var appState: AppState
  @State private var transcriptionRecheckToken = 0

  private var installedLocalModels: [LocalTranscriptionModel] {
    _ = transcriptionRecheckToken
    return LocalTranscriptionService.installedModels()
  }

  private var localModelOptions: [LocalTranscriptionModel] {
    _ = transcriptionRecheckToken
    return LocalTranscriptionService.modelOptions()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: OnboardingChrome.contentSpacing) {
      OnboardingStepHeader(
        systemImage: "shippingbox",
        accent: .green,
        title: "Lokale Modelle",
        subtitle: "Die Engines, die auf diesem Mac laufen. Im Online-Modus ist hier nichts Pflicht."
      )

      whisperCard
      ollamaCard
    }
  }

  // MARK: - Whisper (transcription)

  private var whisperCard: some View {
    OnboardingCard(accent: needsWhisper && !appState.selectedLocalModelIsInstalled ? .orange : nil)
    {
      VStack(alignment: .leading, spacing: 10) {
        HStack(spacing: 6) {
          SectionLabel(text: "Whisper (Sprache → Text)")
          Spacer()
          Button("Prüfen") { transcriptionRecheckToken += 1 }
            .font(.system(size: 10, weight: .medium))
            .buttonStyle(SubtleButtonStyle())
            .foregroundStyle(.blue)
            .disabled(appState.isDownloadingLocalModel)
        }

        if needsWhisper {
          stateRow
          modelPicker
          downloadControls
          if let errorText = appState.localModelDownloadErrorText {
            Text(errorText)
              .font(.system(size: 10.5))
              .foregroundStyle(.red)
              .fixedSize(horizontal: false, vertical: true)
          }
        } else {
          Text(
            "Im Online-Modus läuft die Transkription über OpenAI Whisper. Ein lokales Modell brauchst du nur im sicheren lokalen Modus."
          )
          .font(.system(size: 10.5))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
  }

  private var needsWhisper: Bool { appState.appSettings.secureLocalModeEnabled }

  private var stateRow: some View {
    HStack(spacing: 6) {
      Image(
        systemName: appState.selectedLocalModelIsInstalled
          ? "checkmark.circle.fill" : "arrow.down.circle.fill"
      )
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(appState.selectedLocalModelIsInstalled ? .green : .blue)
      Text(stateText)
        .font(.system(size: 10.5))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      Spacer()
    }
  }

  private var stateText: String {
    if appState.selectedLocalModelIsInstalled {
      let count = installedLocalModels.count
      return "„\(appState.selectedLocalModelDisplayName)“ ist geladen (\(count) Whisper-Modell(e))."
    }
    if let size = LocalTranscriptionModel.sizeLabel(for: appState.selectedLocalModelName) {
      return "„\(appState.selectedLocalModelDisplayName)“ ist noch nicht geladen — \(size)."
    }
    return "„\(appState.selectedLocalModelDisplayName)“ ist noch nicht geladen."
  }

  private var modelPicker: some View {
    HStack(spacing: 8) {
      Text("Modell")
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
      Picker(
        "",
        selection: Binding(
          get: { appState.selectedLocalModelName },
          set: { appState.appSettings.selectedLocalTranscriptionModelName = $0 }
        )
      ) {
        ForEach(localModelOptions) { model in
          Text("\(model.displayName) · \(model.installStateLabel)").tag(model.id)
        }
      }
      .labelsHidden()
      .controlSize(.small)
      .disabled(appState.isDownloadingLocalModel)
    }
  }

  @ViewBuilder
  private var downloadControls: some View {
    if let progress = appState.localModelDownloadProgress {
      VStack(alignment: .leading, spacing: 4) {
        ProgressView(value: progress)
        Text(appState.localModelDownloadStatusText ?? "Modell wird geladen...")
          .font(.system(size: 10.5))
          .foregroundStyle(.secondary)
      }
    } else {
      Button(appState.localModelDownloadButtonTitle) {
        appState.installSelectedLocalModel()
      }
      .controlSize(.small)
      .disabled(appState.selectedLocalModelIsInstalled)
    }
  }

  // MARK: - Ollama (rewrite) — optional

  private var ollamaCard: some View {
    OnboardingCard {
      VStack(alignment: .leading, spacing: 8) {
        SectionLabel(text: "Optional – nur für lokales Umformen")
        Text(
          "Formuliert Texte lokal um (E-Mail, Prompt, Social) über Ollama. Nur nötig, wenn ein Modus offline umformen soll."
        )
        .font(.system(size: 10.5))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

        LocalLLMModelPicker(appState: appState)
      }
    }
  }
}
