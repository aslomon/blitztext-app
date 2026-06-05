import SwiftUI

/// Tab "Modelle": the engines and vocabulary that power Blitztext. Engines on top — "Online" (the
/// OpenAI API key) and "Lokal" (the local Whisper transcription engine, the local Ollama rewrite
/// model and the secure-local master switch) — then a "Vokabular & Ersetzungen" group bundling the
/// three word-handling mechanisms (Eigennamen, fuzzy correction, dictation dictionary).
struct ModelsSettingsView: View {
  @Bindable var appState: AppState
  /// Reserved for cross-tab navigation from empty-state CTAs (kept for parity with Prompts tab).
  let selectTab: (Int) -> Void

  @Environment(\.colorScheme) private var colorScheme

  @State private var newTerm = ""
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
      onlineBand
      Divider().opacity(0.5)
      localBand
      Divider().opacity(0.5)
      vocabularyGroup
    }
    .padding(16)
  }

  // MARK: - Vokabular & Ersetzungen (Eigennamen + Fuzzy + Wörterbuch)

  /// Groups the three word-handling mechanisms under one heading so they read as related, with a
  /// short caption (R3-UX-vocabref) disambiguating which to reach for.
  private var vocabularyGroup: some View {
    VStack(alignment: .leading, spacing: 16) {
      SectionLabel(text: "Vokabular & Ersetzungen")
      vocabularyIntro
      customTermsSection
      Divider().opacity(0.5)
      DictationDictionarySection(appState: appState)
    }
  }

  private var vocabularyIntro: some View {
    Text(
      "Drei Wege, Wörter zu treffen: Eigennamen helfen Whisper, deine Begriffe richtig zu hören. "
        + "Die automatische Korrektur schnappt knappe Verhörer dieser Begriffe gerade. Das "
        + "Wörterbuch ersetzt fest, was du sagst, durch etwas anderes."
    )
    .font(.system(size: 10.5))
    .foregroundStyle(.secondary)
    .fixedSize(horizontal: false, vertical: true)
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

  // MARK: - Eigennamen

  private var customTermsSection: some View {
    SettingsSection(
      "Eigennamen",
      caption:
        "Eigene Namen, Marken und Fachbegriffe, die korrekt erkannt und geschrieben werden sollen."
    ) {
      if appState.textImprovementSettings.customTerms.isEmpty {
        Text("Noch keine Begriffe — füge unten Namen oder Fachwörter hinzu.")
          .font(.system(size: 10.5))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      } else {
        FlowLayout(spacing: 5) {
          ForEach(appState.textImprovementSettings.customTerms, id: \.self) { term in
            termChip(term)
          }
        }
      }

      HStack(spacing: 6) {
        TextField("Neuer Begriff", text: $newTerm)
          .textFieldStyle(.roundedBorder)
          .font(.system(size: 11))
          .onSubmit { addTerm() }

        Button {
          addTerm()
        } label: {
          Image(systemName: "plus.circle.fill")
            .font(.system(size: 16))
            .foregroundStyle(.blue.opacity(0.7))
        }
        .buttonStyle(SubtleButtonStyle())
        .disabled(newTerm.trimmingCharacters(in: .whitespaces).isEmpty)
      }

      fuzzyCorrectionToggle
    }
  }

  /// Conservative on-device fuzzy correction of the Eigennamen above: snaps near-miss spellings
  /// Whisper produces back to the canonical term. Default ON; only fires on clear, unambiguous
  /// near-misses, so it never corrupts unrelated words.
  private var fuzzyCorrectionToggle: some View {
    VStack(alignment: .leading, spacing: 3) {
      Toggle(
        "Eigennamen automatisch korrigieren",
        isOn: $appState.appSettings.fuzzyCorrectionEnabled
      )
      .toggleStyle(.switch)
      .controlSize(.small)
      .font(.system(size: 11.5))

      Text(
        "Korrigiert Tippfehler-nahe Schreibweisen deiner Begriffe (z. B. „Rinert“ → „Rinnert“)."
      )
      .font(.system(size: 10.5))
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
    }
  }

  private func termChip(_ term: String) -> some View {
    HStack(spacing: 3) {
      Text(term)
        .font(.system(size: 10.5))
      Button {
        withAnimation(.easeOut(duration: 0.15)) {
          appState.textImprovementSettings.customTerms.removeAll { $0 == term }
        }
      } label: {
        Image(systemName: "xmark")
          .font(.system(size: 7, weight: .bold))
          .foregroundStyle(.tertiary)
      }
      .buttonStyle(SubtleButtonStyle())
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(
      Capsule()
        .fill(MenuBarTokens.cardFill(colorScheme: colorScheme))
    )
    .overlay(
      Capsule()
        .strokeBorder(MenuBarTokens.cardStroke(colorScheme: colorScheme), lineWidth: 0.5)
    )
  }

  private func addTerm() {
    let trimmed = newTerm.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty, !appState.textImprovementSettings.customTerms.contains(trimmed) else {
      return
    }
    withAnimation(.easeOut(duration: 0.15)) {
      appState.textImprovementSettings.customTerms.append(trimmed)
    }
    newTerm = ""
  }
}
