import SwiftUI

/// Tab "Modelle": the engines that power Blitztext — "Online" (the OpenAI API key) and "Lokal" (the
/// local Whisper transcription engine, the local Ollama rewrite model and the secure-local master
/// switch). All word handling (Eigennamen, gelernte Begriffe, Ersetzungen) lives in the Vokabular tab.
struct ModelsSettingsView: View {
  @Bindable var appState: AppState
  /// Reserved for cross-tab navigation from empty-state CTAs (kept for parity with Prompts tab).
  let selectTab: (Int) -> Void

  /// Bumped by the "Prüfen" button to force a fresh disk read of the installed WhisperKit models.
  /// The disk scan is synchronous, so re-reading inside a recomputed `body` reflects reality.
  @State private var transcriptionRecheckToken = 0

  private var installedLocalModels: [LocalTranscriptionModel] {
    _ = transcriptionRecheckToken
    return LocalTranscriptionService.installedModels()
  }

  private var localModelOptions: [LocalTranscriptionModel] {
    _ = transcriptionRecheckToken
    return LocalTranscriptionService.modelOptions()
  }

  /// Honest one-liner about the selected Whisper model: confirms it is on disk and how many models
  /// total are installed, or states the exact download size still pending for the selection.
  private var transcriptionStateText: String {
    if appState.selectedLocalModelIsInstalled {
      let count = installedLocalModels.count
      return count == 1
        ? "„\(appState.selectedLocalModelDisplayName)“ ist geladen (1 Whisper-Modell auf diesem Mac)."
        : "„\(appState.selectedLocalModelDisplayName)“ ist geladen (\(count) Whisper-Modelle auf diesem Mac)."
    }
    if let size = LocalTranscriptionModel.sizeLabel(for: appState.selectedLocalModelName) {
      return
        "„\(appState.selectedLocalModelDisplayName)“ ist nicht geladen — \(size). Wird beim Installieren lokal gespeichert."
    }
    return
      "„\(appState.selectedLocalModelDisplayName)“ ist nicht geladen. Wird beim Installieren lokal gespeichert."
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack(spacing: 6) {
        BlitzStatusPill(state: appState.hasOpenAIKey ? .online : .warning, label: appState.hasOpenAIKey ? "Online bereit" : "OpenAI fehlt")
        BlitzStatusPill(state: appState.hasAnyTranscriptionEngine ? .local : .download, label: appState.hasAnyTranscriptionEngine ? "Whisper lokal" : "Whisper laden")
      }
      onlineBand
      Divider().opacity(0.5)
      localBand
      vocabularyPointer
    }
    .padding(16)
  }

  /// Vocabulary moved to its own "Vokabular" tab — leave a one-line pointer so anyone who looks for
  /// Eigennamen/Wörterbuch here finds them.
  private var vocabularyPointer: some View {
    Text("Eigennamen, gelernte Begriffe und Ersetzungen findest du jetzt im Tab „Vokabular“.")
      .font(.system(size: 10))
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
      .padding(.top, 4)
  }

  // MARK: - Online band (OpenAI)

  private var onlineBand: some View {
    SettingsSection("Online") {
      if !appState.hasOpenAIKey {
        SettingsStatusBadge(.warning, label: "OpenAI nicht eingerichtet")
        Text(
          "Ohne Key bleiben die Online-Modelle deaktiviert. Trage deinen OpenAI-Key ein, um sie "
            + "für Transkription und Umschreiben zu nutzen."
        )
        .font(.system(size: 10.5))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      }
      OpenAIKeySection(appState: appState)
    }
  }

  // MARK: - Local band (Whisper + Ollama + secure-local switch)

  private var localBand: some View {
    SettingsSection(
      "Lokal",
      caption:
        "Zwei getrennte lokale Engines: Whisper wandelt Sprache → Text, Ollama formuliert um."
    ) {
      Toggle("Sicherer Lokaler Modus", isOn: $appState.appSettings.secureLocalModeEnabled)
        .toggleStyle(.switch)
        .controlSize(.small)
        .onChange(of: appState.appSettings.secureLocalModeEnabled) { _, newValue in
          if newValue && !appState.selectedLocalModelIsInstalled {
            appState.installSelectedLocalModel()
          }
        }

      localTranscriptionSection
      localLLMSection
      localEmbeddingSection
    }
  }

  // MARK: - Lokale Transkription (Whisper) — speech -> text engine

  private var localTranscriptionSection: some View {
    SettingsSection(
      "Lokale Transkription (Whisper)",
      action: appState.isDownloadingLocalModel
        ? nil : (label: "Prüfen", perform: { transcriptionRecheckToken += 1 })
    ) {
      Text(
        "Die Transkriptions-Engine (Sprache → Text) läuft über WhisperKit lokal auf diesem Mac. "
          + "Das Modell wird beim ersten Einsatz automatisch geladen und auf dem Gerät gespeichert."
      )
      .font(.system(size: 10.5))
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)

      if !appState.hasAnyTranscriptionEngine {
        EmptyStateCard(
          icon: "waveform",
          title: "Kein Whisper-Modell geladen",
          caption:
            "Lade ein Whisper-Modell, damit Blitztext Sprache lokal in Text umwandeln kann.",
          accent: .blue,
          buttonLabel: "Modell laden",
          action: { appState.installSelectedLocalModel() }
        )
      }

      transcriptionStateRow
      transcriptionModelPicker
      transcriptionDownloadControls

      if let errorText = appState.localModelDownloadErrorText {
        Text(errorText)
          .font(.system(size: 10.5))
          .foregroundStyle(.red)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var transcriptionStateRow: some View {
    HStack(spacing: 6) {
      Image(
        systemName: appState.selectedLocalModelIsInstalled
          ? "checkmark.circle.fill" : "arrow.down.circle.fill"
      )
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(appState.selectedLocalModelIsInstalled ? .green : .blue)
      Text(transcriptionStateText)
        .font(.system(size: 10.5))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      Spacer()
    }
  }

  private var transcriptionModelPicker: some View {
    HStack(spacing: 8) {
      Text("Whisper-Modell")
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
  private var transcriptionDownloadControls: some View {
    if let progress = appState.localModelDownloadProgress {
      VStack(alignment: .leading, spacing: 4) {
        ProgressView(value: progress)
        Text(appState.localModelDownloadStatusText ?? "Modell wird geladen...")
          .font(.system(size: 10.5))
          .foregroundStyle(.secondary)
      }
    } else {
      HStack(spacing: 10) {
        Button(appState.localModelDownloadButtonTitle) {
          appState.installSelectedLocalModel()
        }
        .controlSize(.small)
        .buttonStyle(PopoverActionButtonStyle(appState.selectedLocalModelIsInstalled ? .secondary : .primary))
        .disabled(appState.selectedLocalModelIsInstalled)

        Link(
          "Modellseite",
          destination: LocalTranscriptionService.modelPageURL(
            for: appState.selectedLocalModelName)
        )
        .font(.system(size: 10.5, weight: .medium))
      }
    }
  }

  // MARK: - Lokales Sprachmodell (Ollama) — rewrite/LLM, NOT transcription

  private var localLLMSection: some View {
    SettingsSection(
      "Lokales Sprachmodell (Ollama)",
      caption:
        "Etwas anderes als die Transkription oben: Dieses Sprachmodell formuliert Texte um "
        + "(E-Mail, Prompt, Social) und läuft über Ollama lokal auf diesem Mac. Kein Server, keine Cloud."
    ) {
      LocalLLMModelPicker(appState: appState)
    }
  }

  private var localEmbeddingSection: some View {
    SettingsSection(
      "Lokale Embeddings (E-Mail Memory)",
      caption:
        "Dieses Ollama-Modell erzeugt Vektoren für die semantische E-Mail-Memory. Speicherung bleibt separat opt-in."
    ) {
      HStack(spacing: 6) {
        Image(systemName: embeddingModelReady ? "checkmark.circle.fill" : "arrow.down.circle.fill")
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(embeddingModelReady ? .green : .blue)
        Text(embeddingStatusText)
          .font(.system(size: 10.5))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 0)
      }

      HStack(spacing: 8) {
        Text("Embedding-Modell")
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
        TextField(
          OllamaEmbeddingProvider.defaultModelID,
          text: $appState.appSettings.selectedEmbeddingModelName
        )
        .textFieldStyle(.roundedBorder)
        .font(.system(size: 11, design: .monospaced))
      }

      Toggle("Semantische E-Mail Memory aktivieren", isOn: $appState.appSettings.semanticEmailMemoryEnabled)
        .toggleStyle(.switch)
        .controlSize(.small)

      Text(
        "Erfordert Archiv und ein lokal geladenes Embedding-Modell. Speichert fertige E-Mail-Texte "
          + "mit lokalen Vektoren für 30 Tage. Sichere Felder werden nie gespeichert."
      )
        .font(.system(size: 10.5))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      Button("Semantische E-Mail Memory löschen") {
        appState.clearEmailSemanticMemory()
      }
      .buttonStyle(PopoverActionButtonStyle(.danger))
      .font(.system(size: 10.5, weight: .medium))
    }
  }

  private var selectedEmbeddingModelName: String {
    appState.appSettings.selectedEmbeddingModelName
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var embeddingModelReady: Bool {
    appState.localModelManager.isInstalled(selectedEmbeddingModelName)
  }

  private var embeddingStatusText: String {
    if selectedEmbeddingModelName.isEmpty {
      return "Kein Embedding-Modell ausgewählt."
    }
    if embeddingModelReady {
      return "„\(selectedEmbeddingModelName)“ ist lokal geladen."
    }
    return "„\(selectedEmbeddingModelName)“ ist noch nicht in Ollama geladen."
  }

}
