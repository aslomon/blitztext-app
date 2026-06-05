import SwiftUI

// MARK: - Vocabulary settings (Tab: Vokabular)

/// ONE page for everything word-related, grouped by INTENT instead of being scattered across the
/// Modelle and Archiv tabs as three overlapping mechanisms:
///  1. "Richtig erkennen" — known words Whisper should hear + spell correctly. This MERGES the old
///     Eigennamen (manual) and the confirmed Memory terms (learned) into ONE list, since they were
///     functionally identical and edited in two places.
///  2. "Aus dem Archiv lernen" — the Memory engine that proposes recurring terms to confirm.
///  3. "Fest ersetzen" — the dictation dictionary (say A → write B) + spoken punctuation.
/// The underlying stores and the term-injection pipeline are unchanged; this only unifies the UI.
struct VocabularySettingsView: View {
  @Bindable var appState: AppState

  @Environment(\.colorScheme) private var colorScheme

  @State private var newTerm = ""
  @State private var showClearMemoryConfirm = false

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      intro
      recognizeSection
      Divider().opacity(0.5)
      learnSection
      Divider().opacity(0.5)
      DictationDictionarySection(appState: appState)
    }
    .padding(16)
  }

  private var intro: some View {
    Text(
      "Alles rund um Wörter an einem Ort. Begriffe richtig erkennen lassen (Namen, Marken, "
        + "Fachbegriffe), aus deinem Archiv lernen — und feste Ersetzungen, wenn du A sagst, aber B "
        + "geschrieben haben willst."
    )
    .font(.system(size: 10.5))
    .foregroundStyle(.secondary)
    .fixedSize(horizontal: false, vertical: true)
  }

  // MARK: - Recognize (merged manual + memory)

  private var recognizeSection: some View {
    SettingsSection(
      "Begriffe richtig erkennen",
      caption:
        "Namen, Marken und Fachwörter, die korrekt gehört und geschrieben werden sollen. "
        + "Manuell hinzugefügte und aus dem Archiv gelernte Begriffe stehen hier gemeinsam."
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
            .font(.system(size: 16))
            .foregroundStyle(.blue.opacity(0.7))
        }
        .buttonStyle(SubtleButtonStyle())
        .disabled(newTerm.trimmingCharacters(in: .whitespaces).isEmpty)
      }

      fuzzyToggle
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

      Text("Korrigiert Tippfehler-nahe Schreibweisen deiner Begriffe (z. B. „Rinert“ → „Rinnert“).")
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

  // MARK: - Learn from archive (Memory engine)

  private var learnSection: some View {
    SettingsSection(
      "Aus dem Archiv lernen",
      caption:
        "Findet on-device wiederkehrende Namen, Fachbegriffe und Fremdwörter in deinem Archiv und "
        + "schlägt sie vor. Du bestätigst jeden Begriff selbst — bestätigte erscheinen oben."
    ) {
      HStack {
        Toggle("Begriffe aus dem Archiv lernen", isOn: $appState.isMemoryContextEnabled)
          .toggleStyle(.switch)
          .controlSize(.small)
          .disabled(!appState.isArchiveEnabled)
        Spacer()
        if appState.isRecomputingMemory {
          ProgressView().controlSize(.small).scaleEffect(0.7)
        }
      }

      if !appState.isArchiveEnabled {
        Text("Zuerst das Archiv aktivieren (Tab „Archiv“).")
          .font(.system(size: 10))
          .foregroundStyle(.secondary)
      }

      if appState.isMemoryContextEnabled {
        Button("Jetzt analysieren") { appState.recomputeMemory() }
          .buttonStyle(SubtleButtonStyle())
          .disabled(appState.isRecomputingMemory || !appState.isArchiveEnabled)

        memoryEmptyStateLine
        suggestionsBlock
        clearMemoryButton
      }
    }
  }

  @ViewBuilder
  private var memoryEmptyStateLine: some View {
    if appState.memorySuggestions.isEmpty && appState.memoryConfirmedTerms.isEmpty {
      Text(
        "Noch keine Begriffe gefunden. Nimm etwas auf und tippe „Jetzt analysieren“, um Vorschläge "
          + "aus deinem Archiv zu erzeugen."
      )
      .font(.system(size: 10.5))
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
    }
  }

  @ViewBuilder
  private var suggestionsBlock: some View {
    let suggestions = appState.memorySuggestions
    if !suggestions.isEmpty {
      VStack(alignment: .leading, spacing: 10) {
        Text("Vorschläge (\(suggestions.count))")
          .font(.system(size: 10, weight: .semibold))
          .foregroundStyle(.secondary)

        ForEach(MemoryCategory.allCases, id: \.self) { category in
          let inCategory = suggestions.filter { $0.category == category }
          if !inCategory.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
              Text(category.displayName)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
              FlowLayout(spacing: 5) {
                ForEach(inCategory) { candidate in
                  SuggestionChip(
                    candidate: candidate,
                    onConfirm: { appState.confirmMemory(candidate) },
                    onDeny: { appState.denyMemory(candidate) }
                  )
                }
              }
            }
          }
        }
      }
    }
  }

  private var clearMemoryButton: some View {
    DestructiveClearButton(
      "Memory löschen",
      message:
        "Alle abgeleiteten und bestätigten Begriffe werden entfernt. Das lässt sich nicht rückgängig machen."
    ) {
      appState.clearMemory()
    }
  }
}

// MARK: - Chips

/// A recognize term in the merged list. Shows a small source glyph (person = manual, sparkle =
/// learned from Memory) and a trailing ✕ that removes it from whichever store owns it.
private struct RecognizeChip: View {
  let term: AppState.RecognizeTerm
  let onRemove: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: term.fromMemory ? "sparkles" : "person.fill")
        .font(.system(size: 8, weight: .semibold))
        .foregroundStyle(term.fromMemory ? AnyShapeStyle(.purple) : AnyShapeStyle(.secondary))
        .help(term.fromMemory ? "Aus dem Archiv gelernt" : "Manuell hinzugefügt")
      Text(term.text)
        .font(.system(size: 10.5))
        .foregroundStyle(.primary)
      Button {
        onRemove()
      } label: {
        Image(systemName: "xmark")
          .font(.system(size: 7, weight: .bold))
          .foregroundStyle(.tertiary)
      }
      .buttonStyle(SubtleButtonStyle())
      .help("Entfernen")
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(Capsule().fill(MenuBarTokens.cardFill(colorScheme: colorScheme)))
    .overlay(
      Capsule().strokeBorder(MenuBarTokens.cardStroke(colorScheme: colorScheme), lineWidth: 0.5))
  }
}

/// A Memory suggestion: leading "+" confirms, trailing "x" denies. (Moved here from ArchiveSettings
/// when the Memory curation UI joined the unified Vokabular page.)
private struct SuggestionChip: View {
  let candidate: MemoryCandidate
  let onConfirm: () -> Void
  let onDeny: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    HStack(spacing: 4) {
      Button {
        withAnimation(.easeOut(duration: 0.15)) { onConfirm() }
      } label: {
        Image(systemName: "plus")
          .font(.system(size: 8, weight: .bold))
          .foregroundStyle(.green)
      }
      .buttonStyle(SubtleButtonStyle())
      .help("Bestätigen")

      Text(candidate.surfaceForm)
        .font(.system(size: 10.5))
        .foregroundStyle(.primary)

      Button {
        withAnimation(.easeOut(duration: 0.15)) { onDeny() }
      } label: {
        Image(systemName: "xmark")
          .font(.system(size: 7, weight: .bold))
          .foregroundStyle(.tertiary)
      }
      .buttonStyle(SubtleButtonStyle())
      .help("Nie vorschlagen")
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(Capsule().fill(MenuBarTokens.cardFill(colorScheme: colorScheme)))
    .overlay(
      Capsule().strokeBorder(MenuBarTokens.cardStroke(colorScheme: colorScheme), lineWidth: 0.5))
  }
}
