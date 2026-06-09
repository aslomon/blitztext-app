import SwiftUI

// MARK: - Vocabulary settings (Tab: Vokabular)

/// ONE page for everything word-related, grouped by INTENT instead of being scattered across the
/// Modelle and Archiv tabs as three overlapping mechanisms:
///  1. "Memory" — master toggle + status = primary concern; sits at the top.
///  2. "Eigene Identität" — foundational, short.
///  3. "Begriffe" — known words Whisper should hear + spell correctly. Merges old Eigennamen
///     (manual) and auto-learned Memory terms into ONE list; functionally identical.
///  4. "Diktier-Wörterbuch" — say A → write B, plus spoken punctuation.
/// The underlying stores and the term-injection pipeline are unchanged; this only unifies the UI.
struct VocabularySettingsView: View {
  @Bindable var appState: AppState

  @State private var newTerm = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      memorySection
      Divider().opacity(0.5)
      identitySection
      recognizeSection
    }
    .padding(16)
    .task {
      await appState.localModelManager.refresh()
    }
  }

  // MARK: - Suggestions nudge banner

  /// Tinted EmptyStateCard-style banner with badge count + CTA. Shown at the top of memorySection
  /// body (below master toggle) when there are pending improvement suggestions.
  @ViewBuilder
  private var improvementSuggestionsNudge: some View {
    let count = appState.improvementSuggestions.count
    if count > 0 {
      Button {
        NotificationCenter.default.post(name: .openArchiveWindow, object: nil)
      } label: {
        HStack(spacing: 8) {
          // Badge count — prominent
          Text("\(count)")
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(.blue)
            .frame(minWidth: 20)
          VStack(alignment: .leading, spacing: 1) {
            Text(count == 1 ? "Neuer Lern-Vorschlag" : "\(count) neue Lern-Vorschläge")
              .font(.system(size: 11, weight: .semibold))
              .foregroundStyle(.primary)
            Text("Im Archiv ansehen →")
              .font(.system(size: 10.5))
              .foregroundStyle(.blue)
          }
          Spacer(minLength: 0)
          Image(systemName: "chevron.right")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlassInfoBanner(accent: .blue)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(
        count == 1
          ? "1 neuer Lern-Vorschlag — Im Archiv ansehen"
          : "\(count) neue Lern-Vorschläge — Im Archiv ansehen"
      )
    }
  }

  private var identitySection: some View {
    SettingsSection(
      "Eigene Identität",
      caption: "Dein Name als feste Schreibperspektive für E-Mail und Umschreiben."
    ) {
      TextField("Dein Name", text: $appState.appSettings.userDisplayName)
        .textFieldStyle(.roundedBorder)
        .font(.system(size: 11))

      Text(
        "Wird lokal gespeichert, als Schreibweise-Hinweis genutzt und im E-Mail-Modus als \u{201E}Ich schreibe als \u{2026}\u{201C} mitgegeben."
      )
      .font(.system(size: 10.5))
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
    }
  }

  // MARK: - Recognize (merged manual + memory)

  private var recognizeSection: some View {
    SettingsSection(
      "Begriffe",
      caption:
        "Exakte Schreibweisen für Namen, Marken und Fachwörter."
    ) {
      let terms = appState.recognizeTerms
      if terms.isEmpty {
        Text("Noch keine Begriffe — füge unten Namen oder Fachwörter hinzu.")
          .font(.system(size: 10.5))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      } else {
        FlowLayout(spacing: 5) {
          ForEach(terms) { term in
            RecognizeChip(
              term: term,
              onRemove: {
                withAnimation(.easeOut(duration: 0.15)) { appState.removeRecognizeTerm(term) }
              }
            )
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
        }
        .buttonStyle(PopoverIconButtonStyle(.primary))
        .disabled(newTerm.trimmingCharacters(in: .whitespaces).isEmpty)
      }

      fuzzyToggle

      Divider().opacity(0.4)

      // Replacements live here too — to the user they are the same idea as Begriffe.
      DictationReplacementsBlock(appState: appState)

      // Contextually relevant here — explains how Begriffe are used
      InfoDisclosure("Wie Begriffe genutzt werden") {
        VStack(alignment: .leading, spacing: 5) {
          Text(
            "Beim Diktieren werden sie als Whisper-Hinweis mitgegeben, damit ähnlich klingende Wörter eher richtig erkannt werden."
          )
          Text(
            "Beim Umschreiben werden sie dem Sprachmodell als Schreibweisen-Liste gegeben: Wenn der Begriff vorkommt, soll er exakt so geschrieben werden."
          )
          Text(
            "Manuell hinzugefügte und automatisch gelernte Begriffe landen in derselben sichtbaren Liste."
          )
          Divider().opacity(0.4)
          Text(
            "Memory: lernt aus deinem Archiv. Wiederkehrende Eigen- und Fachbegriffe werden automatisch normale Begriffe; bei E-Mail kann Memory zusätzlich ähnliche frühere Antworten als lokalen Hintergrund finden."
          )
          Text(
            "Wenn ein automatisch gelernter Begriff nicht passt, entfernst du ihn aus der Begriffsliste. Danach wird er nicht erneut gelernt."
          )
          Text(
            "Ersetzungen: feste Regeln wie gesagtes Wort A → geschriebener Text B. Sie werden direkt auf den transkribierten Text angewendet."
          )
        }
      }
    }
  }

  /// Conservative on-device fuzzy correction of the recognize terms above: snaps near-miss spellings
  /// back to the canonical word. Default ON; only fires on clear, unambiguous near-misses.
  private var fuzzyToggle: some View {
    VStack(alignment: .leading, spacing: 3) {
      Toggle(
        "Begriffe automatisch korrigieren",
        isOn: $appState.appSettings.fuzzyCorrectionEnabled
      )
      .toggleStyle(.switch)
      .controlSize(.small)
      .font(.system(size: 11.5))

      Text(
        "Korrigiert Tippfehler-nahe Schreibweisen deiner Begriffe (z. B. \u{201E}Rinert\u{201C} \u{2192} \u{201E}Rinnert\u{201C})."
      )
      .font(.system(size: 10.5))
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
    }
  }

  private func addTerm() {
    let trimmed = newTerm.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return }
    withAnimation(.easeOut(duration: 0.15)) { appState.addRecognizeTerm(trimmed) }
    newTerm = ""
  }

  // MARK: - Memory

  private var memorySection: some View {
    SettingsSection(
      "Memory",
      action: (
        label: "Prüfen",
        perform: { Task { await appState.localModelManager.refresh() } }
      )
    ) {
      // 1. Master toggle + status pill
      HStack {
        Toggle("Aktivieren", isOn: $appState.isUnifiedMemoryEnabled)
          .toggleStyle(.switch)
          .controlSize(.small)
        Spacer()
        BlitzStatusPill(state: memoryPillState, label: appState.unifiedMemoryStatusLabel)
      }

      if appState.isUnifiedMemoryEnabled {
        // 2. Suggestions nudge banner — top of expanded body, before InfoDisclosure
        improvementSuggestionsNudge

        // 3. "Jetzt analysieren" directly below master toggle (primary action)
        HStack(spacing: 8) {
          if appState.isRecomputingMemory {
            ProgressView()
              .controlSize(.small)
          }
          Button("Jetzt analysieren") { appState.recomputeMemory() }
            .buttonStyle(PopoverActionButtonStyle(.primary))
            .disabled(appState.isRecomputingMemory || !appState.isArchiveEnabled)
        }

        // 4. InfoDisclosure — optional details
        InfoDisclosure("Was Memory macht") {
          VStack(alignment: .leading, spacing: 5) {
            Text(
              "Vokabular-Memory: sucht im Archiv nach wiederkehrenden Namen und Fachbegriffen. Namen/Fremdwörter werden nach zwei Vorkommen übernommen, Fachbegriffe nach drei."
            )
            Text(
              "E-Mail Memory: speichert fertige E-Mail-Antworten lokal mit Embeddings und findet beim nächsten E-Mail-Modus ähnliche frühere Antworten als Hintergrund."
            )
            Text(
              "Korrekturlernen: liest nach dem Einfügen optional nochmal den Feldinhalt, um deine manuellen Korrekturen als Vorschläge zu erkennen."
            )
            Text(
              "Memory aus stoppt Lernen und Kontextsuche. Bereits gelernte Begriffe bleiben als Vokabular aktiv."
            )
          }
        }

        emailMemoryStatusRow

        Toggle("Aus Korrekturen lernen", isOn: $appState.isImprovementDetectionEnabled)
          .toggleStyle(.switch)
          .controlSize(.small)

        // 5. Destructive buttons stacked vertically — reduces mis-tap risk
        clearMemoryControls
      }
    }
  }

  private var emailMemoryStatusRow: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 8) {
        Text("E-Mail Memory")
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
        BlitzStatusPill(state: emailMemoryPillState, label: appState.semanticEmailMemoryStatusLabel)
        Spacer(minLength: 0)
      }

      HStack(spacing: 8) {
        Text("Embedding-Modell")
          .font(.system(size: 10.5))
          .foregroundStyle(.tertiary)
        Text(appState.selectedEmbeddingModelName)
          .font(.system(size: 11, design: .monospaced))
          .padding(.horizontal, 7)
          .padding(.vertical, 3)
          .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 5))
      }

      embeddingProgress

    }
  }

  @ViewBuilder
  private var embeddingProgress: some View {
    let modelID = appState.selectedEmbeddingModelName
    if let pull = appState.localModelManager.pulls[modelID] {
      VStack(alignment: .leading, spacing: 4) {
        ProgressView(value: pull.fraction)
        Text(pull.statusText)
          .font(.system(size: 10.5))
          .foregroundStyle(.secondary)
      }
    } else if let ollama = appState.localModelManager.ollamaInstallState {
      VStack(alignment: .leading, spacing: 4) {
        ProgressView(value: ollama.fraction)
        Text(ollama.statusText)
          .font(.system(size: 10.5))
          .foregroundStyle(.secondary)
      }
    } else if let error = appState.localModelManager.lastError,
      appState.appSettings.semanticEmailMemoryEnabled
    {
      Text(error)
        .font(.system(size: 10.5))
        .foregroundStyle(.red)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var emailMemoryPillState: BlitzStatusPill.State {
    if !appState.appSettings.semanticEmailMemoryEnabled { return .muted }
    if appState.semanticEmailMemoryIsReady { return .ready }
    if appState.semanticEmailEmbeddingIsPreparing { return .download }
    return .warning
  }

  private var memoryPillState: BlitzStatusPill.State {
    if !appState.isUnifiedMemoryEnabled { return .muted }
    if appState.semanticEmailEmbeddingIsPreparing { return .download }
    if appState.appSettings.semanticEmailMemoryEnabled, !appState.semanticEmailEmbeddingIsReady {
      return .warning
    }
    return .ready
  }

  private var clearMemoryButton: some View {
    DestructiveClearButton(
      "Memory löschen",
      message:
        "Alle automatisch gelernten Begriffe werden entfernt. Das lässt sich nicht rückgängig machen."
    ) {
      appState.clearMemory()
    }
  }

  private var clearEmailMemoryButton: some View {
    DestructiveClearButton(
      "E-Mail Memory löschen",
      message:
        "Alle semantisch gespeicherten E-Mail-Texte werden entfernt. Das lässt sich nicht rückgängig machen."
    ) {
      appState.clearEmailSemanticMemory()
    }
  }

  /// Two destructive buttons stacked vertically (6pt gap) instead of side-by-side HStack.
  /// Reduces mis-tap risk at 410pt popover width.
  private var clearMemoryControls: some View {
    VStack(alignment: .leading, spacing: 6) {
      clearMemoryButton
      clearEmailMemoryButton
    }
  }
}

// MARK: - Chips

/// A recognize term in the merged list. Shows a small source glyph (person = manual,
/// wand.and.stars = learned from Memory) and a trailing ✕ that removes it from whichever
/// store owns it.
private struct RecognizeChip: View {
  let term: AppState.RecognizeTerm
  let onRemove: () -> Void

  var body: some View {
    HStack(spacing: 4) {
      // "sparkles" (purple) replaced by "wand.and.stars" (.secondary) — avoids collision
      // with the textImprover mode accent (purple per DESIGN.md). Manual chips stay .tertiary
      // so the two source types are distinguishable without colour.
      Image(systemName: term.fromMemory ? "wand.and.stars" : "person.fill")
        .font(.system(size: 8, weight: .semibold))
        .foregroundStyle(term.fromMemory ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tertiary))
        .help(term.fromMemory ? "Aus dem Archiv gelernt" : "Manuell hinzugefügt")
      Text(term.text)
        .font(.system(size: 10.5))
        .foregroundStyle(.primary)
      // Replaced SubtleButtonStyle with .plain + .contentShape(Circle) for 18pt minimum tap area
      // without adding visual weight — keeps chip visually minimal.
      Button {
        onRemove()
      } label: {
        Image(systemName: "xmark")
          .font(.system(size: 7, weight: .bold))
          .foregroundStyle(.tertiary)
      }
      .buttonStyle(.plain)
      .contentShape(Circle().scale(1.6))
      .help("Entfernen")
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    // ChipBackgroundModifier: thinMaterial on macOS 26+, MenuBarTokens fill on 14–25.
    // Per no-stacking rule: .thinMaterial (not .glassEffect) inside GroupBox.
    .modifier(ChipBackgroundModifier(accent: .blue))
  }
}
