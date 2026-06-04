import SwiftUI

// MARK: - Archive + Memory settings (Tab 2: Archiv)

/// Phase 4 UI: the opt-in transcription archive (text only) plus the two-speed Memory
/// curation surface. Everything here is privacy-first — opt-in, default OFF, on-device,
/// purgeable. The services layer (AppState) does the work; this view only presents it.
struct ArchiveSettingsView: View {
  @Bindable var appState: AppState

  @State private var showClearArchiveConfirm = false
  @State private var showClearMemoryConfirm = false

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      archiveSection
      Divider().opacity(0.5)
      memorySection
    }
    .padding(16)
  }

  // MARK: - Archive

  private var archiveSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      SectionLabel(text: "Transkriptions-Archiv")

      Toggle(
        "Transkriptionen lokal archivieren",
        isOn: $appState.isArchiveEnabled
      )
      .toggleStyle(.switch)
      .controlSize(.small)

      Text(
        "Aus für maximale Privatsphäre. Wenn aktiv, werden Roh- und Endtext der letzten "
          + "90 Tage on-device gespeichert (0600, kein Audio, nichts verlässt den Mac)."
      )
      .font(.system(size: 10.5))
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)

      if appState.isArchiveEnabled {
        archiveList
      }
    }
  }

  @ViewBuilder
  private var archiveList: some View {
    let grouped = appState.archiveStore.entriesByDay()

    if grouped.isEmpty {
      Text("Noch keine Einträge. Neue Transkriptionen erscheinen hier nach Tag.")
        .font(.system(size: 10.5))
        .foregroundStyle(.secondary)
        .padding(.top, 2)
    } else {
      VStack(alignment: .leading, spacing: 12) {
        ForEach(grouped, id: \.day) { group in
          VStack(alignment: .leading, spacing: 6) {
            Text(dayHeader(for: group.day))
              .font(.system(size: 10, weight: .semibold))
              .foregroundStyle(.secondary)

            VStack(spacing: 6) {
              ForEach(group.entries) { entry in
                ArchiveEntryRow(
                  entry: entry,
                  displayName: appState.displayName(for: entry.mode),
                  onDelete: { appState.archiveStore.delete(entry.id) }
                )
              }
            }
          }
        }

        clearArchiveButton
      }
      .padding(.top, 4)
    }
  }

  private var clearArchiveButton: some View {
    HStack {
      Spacer()
      if showClearArchiveConfirm {
        Button("Abbrechen") { showClearArchiveConfirm = false }
          .font(.system(size: 10, weight: .medium))
          .buttonStyle(SubtleButtonStyle())
          .foregroundStyle(.secondary)
        Button("Wirklich löschen") {
          appState.clearArchive()
          showClearArchiveConfirm = false
        }
        .font(.system(size: 10, weight: .medium))
        .buttonStyle(SubtleButtonStyle())
        .foregroundStyle(.red)
      } else {
        Button("Archiv löschen") { showClearArchiveConfirm = true }
          .font(.system(size: 10, weight: .medium))
          .buttonStyle(SubtleButtonStyle())
          .foregroundStyle(.red)
      }
    }
  }

  // MARK: - Memory

  private var memorySection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        SectionLabel(text: "Memory")
        Spacer()
        if appState.isRecomputingMemory {
          ProgressView()
            .controlSize(.small)
            .scaleEffect(0.7)
        }
      }

      Toggle(
        "Memory als Kontext nutzen",
        isOn: $appState.isMemoryContextEnabled
      )
      .toggleStyle(.switch)
      .controlSize(.small)

      Text(
        "Leitet on-device wiederkehrende Namen, Fachbegriffe und Fremdwörter aus deinem "
          + "Archiv ab. Wirkt nur in Modi, in denen du Memory zusätzlich einschaltest. "
          + "Nichts wird automatisch übernommen — du bestätigst jeden Begriff selbst."
      )
      .font(.system(size: 10.5))
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)

      if appState.isMemoryContextEnabled {
        HStack(spacing: 8) {
          Button("Jetzt analysieren") {
            appState.recomputeMemory()
          }
          .buttonStyle(SubtleButtonStyle())
          .disabled(appState.isRecomputingMemory || !appState.isArchiveEnabled)

          if !appState.isArchiveEnabled {
            Text("Archiv aktivieren, um Begriffe zu finden.")
              .font(.system(size: 10))
              .foregroundStyle(.secondary)
          }
        }

        suggestionsBlock
        confirmedBlock
        clearMemoryButton
      }
    }
  }

  @ViewBuilder
  private var suggestionsBlock: some View {
    let suggestions = appState.memorySuggestions

    if !suggestions.isEmpty {
      VStack(alignment: .leading, spacing: 10) {
        Text("Vorschläge")
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

  @ViewBuilder
  private var confirmedBlock: some View {
    let confirmed = appState.memoryConfirmedTerms

    if !confirmed.isEmpty {
      VStack(alignment: .leading, spacing: 6) {
        Text("Bestätigt — fließt als Kontext in deine Modi")
          .font(.system(size: 10, weight: .semibold))
          .foregroundStyle(.secondary)

        FlowLayout(spacing: 5) {
          ForEach(confirmed) { term in
            ConfirmedChip(
              term: term,
              onRemove: { appState.unconfirmMemory(term.id) }
            )
          }
        }
      }
    }
  }

  private var clearMemoryButton: some View {
    HStack {
      Spacer()
      if showClearMemoryConfirm {
        Button("Abbrechen") { showClearMemoryConfirm = false }
          .font(.system(size: 10, weight: .medium))
          .buttonStyle(SubtleButtonStyle())
          .foregroundStyle(.secondary)
        Button("Wirklich löschen") {
          appState.clearMemory()
          showClearMemoryConfirm = false
        }
        .font(.system(size: 10, weight: .medium))
        .buttonStyle(SubtleButtonStyle())
        .foregroundStyle(.red)
      } else {
        Button("Memory löschen") { showClearMemoryConfirm = true }
          .font(.system(size: 10, weight: .medium))
          .buttonStyle(SubtleButtonStyle())
          .foregroundStyle(.red)
      }
    }
  }

  // MARK: - Helpers

  private func dayHeader(for day: Date) -> String {
    let calendar = Calendar.current
    if calendar.isDateInToday(day) { return "Heute" }
    if calendar.isDateInYesterday(day) { return "Gestern" }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "de_DE")
    formatter.dateFormat = "EEEE, d. MMMM"
    return formatter.string(from: day)
  }
}

// MARK: - Archive entry row (raw -> final on disclosure)

private struct ArchiveEntryRow: View {
  let entry: ArchiveEntry
  let displayName: String
  let onDelete: () -> Void

  @State private var expanded = false

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Button {
        withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() }
      } label: {
        HStack(spacing: 8) {
          Circle()
            .fill(entry.mode.accentColorValue)
            .frame(width: 6, height: 6)

          VStack(alignment: .leading, spacing: 1) {
            Text(displayName)
              .font(.system(size: 11.5, weight: .semibold))
              .foregroundStyle(.primary)
            Text(timeLabel)
              .font(.system(size: 10))
              .foregroundStyle(.secondary)
          }

          Spacer()

          Image(systemName: expanded ? "chevron.up" : "chevron.down")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(SubtleButtonStyle())

      if !expanded {
        Text(entry.finalText)
          .font(.system(size: 10.5))
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.tail)
      } else {
        VStack(alignment: .leading, spacing: 8) {
          labelledText(label: "Roh", text: entry.rawTranscript)
          if entry.finalText != entry.rawTranscript {
            labelledText(label: "Endtext", text: entry.finalText)
          }
          HStack {
            Spacer()
            Button {
              onDelete()
            } label: {
              Image(systemName: "trash")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.red.opacity(0.85))
            }
            .buttonStyle(SubtleButtonStyle())
          }
        }
        .padding(.top, 2)
      }
    }
    .padding(10)
    .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
    )
  }

  private func labelledText(label: String, text: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(label.uppercased())
        .font(.system(size: 9, weight: .medium))
        .foregroundStyle(.tertiary)
      Text(text.isEmpty ? "—" : text)
        .font(.system(size: 11))
        .foregroundStyle(.primary)
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var timeLabel: String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "de_DE")
    formatter.dateFormat = "HH:mm"
    let time = formatter.string(from: entry.date)
    let duration = String(format: "%.0f s", entry.durationSec)
    return "\(time) · \(duration)"
  }
}

// MARK: - Memory chips

/// A suggested candidate: leading "+" confirms (append to confirmed), trailing "x" denies.
private struct SuggestionChip: View {
  let candidate: MemoryCandidate
  let onConfirm: () -> Void
  let onDeny: () -> Void

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
    .background(Capsule().fill(Color(nsColor: .controlBackgroundColor)))
    .overlay(Capsule().strokeBorder(Color.primary.opacity(0.04), lineWidth: 0.5))
  }
}

/// A confirmed term: trailing "x" removes it from the injected set.
private struct ConfirmedChip: View {
  let term: MemoryConfirmedTerm
  let onRemove: () -> Void

  var body: some View {
    HStack(spacing: 3) {
      Text(term.term)
        .font(.system(size: 10.5))
        .foregroundStyle(.primary)

      Button {
        withAnimation(.easeOut(duration: 0.15)) { onRemove() }
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
    .background(Capsule().fill(Color.green.opacity(0.10)))
    .overlay(Capsule().strokeBorder(Color.green.opacity(0.18), lineWidth: 0.5))
  }
}

// MARK: - Mode accent color

extension WorkflowType {
  /// The mode accent as a SwiftUI Color (DESIGN.md per-mode palette).
  var accentColorValue: Color {
    switch self {
    case .transcription: return .blue
    case .localTranscription: return .green
    case .textImprover: return .purple
    case .dampfAblassen: return .orange
    case .emojiText: return .cyan
    }
  }
}
