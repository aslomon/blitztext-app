import SwiftUI

// MARK: - Archive + Memory settings (Tab 2: Archiv)

/// Phase 4 UI: the opt-in transcription archive (text only) plus the two-speed Memory
/// curation surface. Everything here is privacy-first — opt-in, default OFF, on-device,
/// purgeable. The services layer (AppState) does the work; this view only presents it.
struct ArchiveSettingsView: View {
  @Bindable var appState: AppState

  @State private var showClearArchiveConfirm = false

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text(
        "Privatsphäre zuerst: Alles hier ist opt-in, standardmäßig aus und bleibt on-device. "
          + "Das Archiv speichert nur Text. Gelernte Begriffe pflegst du im Tab „Vokabular“."
      )
      .font(.system(size: 10.5))
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)

      archiveSection
      Divider().opacity(0.5)
      improvementSection
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
      } else {
        EmptyStateCard(
          icon: "archivebox",
          title: "Archiv ist aus",
          caption:
            "Es wird nichts gespeichert. Aktiviere das Archiv, um Transkriptionen on-device "
            + "festzuhalten und Memory zu speisen.",
          accent: .primary
        )
      }

      // Always reachable — opens the full window (Verlauf · Diktate · Kontext · Verbesserungen).
      // Crucially this works even with the archive OFF/empty, so its off-state + facets are
      // discoverable (and the user learns what to enable) instead of being a hidden dead end.
      openArchiveWindowButton
    }
  }

  private var openArchiveWindowButton: some View {
    HStack {
      Button("Archiv-Fenster öffnen …") {
        NotificationCenter.default.post(name: .openArchiveWindow, object: nil)
      }
      .font(.system(size: 10, weight: .medium))
      .buttonStyle(SubtleButtonStyle())
      .foregroundStyle(.blue)
      Spacer()
    }
    .padding(.top, 2)
  }

  /// Inline condensed list: only the newest few entries, with a button that opens the full
  /// archive in its own standalone window. The full list lives in `ArchiveWindowView`.
  private static let inlinePreviewLimit = 3

  @ViewBuilder
  private var archiveList: some View {
    let all = appState.archiveStore.entries
    let preview = Array(all.prefix(Self.inlinePreviewLimit))

    if preview.isEmpty {
      Text("Noch keine Einträge. Neue Transkriptionen erscheinen hier nach Tag.")
        .font(.system(size: 10.5))
        .foregroundStyle(.secondary)
        .padding(.top, 2)
    } else {
      VStack(alignment: .leading, spacing: 8) {
        VStack(spacing: 6) {
          ForEach(preview) { entry in
            ArchiveEntryRow(
              entry: entry,
              appState: appState,
              showActions: false,
              onDelete: { appState.archiveStore.delete(entry.id) }
            )
          }
        }

        HStack {
          Spacer()
          clearArchiveButton
        }
      }
      .padding(.top, 4)
    }
  }

  private var clearArchiveButton: some View {
    HStack {
      Spacer()
      Button("Archiv löschen") { showClearArchiveConfirm = true }
        .font(.system(size: 10, weight: .medium))
        .buttonStyle(SubtleButtonStyle())
        .foregroundStyle(.red)
        .accessibilityLabel("Archiv löschen")
        .confirmationDialog(
          "Archiv löschen?",
          isPresented: $showClearArchiveConfirm,
          titleVisibility: .visible
        ) {
          Button("Löschen", role: .destructive) { appState.clearArchive() }
          Button("Abbrechen", role: .cancel) {}
        } message: {
          Text(
            "Alle archivierten Transkriptionen werden on-device entfernt. Das lässt sich nicht rückgängig machen."
          )
        }
    }
  }

  // MARK: - Improvement detection (MEM-2, experimental)

  /// Opt-in "Verbesserungs-Erkennung": re-reads the field after a paste to learn from manual
  /// corrections. PRIVACY-SENSITIVE → gated on the archive opt-in, default OFF, clearly labeled.
  private var improvementSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      SectionLabel(text: "Verbesserungen erkennen")

      Toggle(
        "Verbesserungen erkennen (experimentell)",
        isOn: $appState.isImprovementDetectionEnabled
      )
      .toggleStyle(.switch)
      .controlSize(.small)
      .disabled(!appState.isArchiveEnabled)

      Text(
        "Liest nach dem Einfügen den Feldinhalt erneut, um aus deinen Korrekturen zu lernen. "
          + "Bleibt lokal."
      )
      .font(.system(size: 10.5))
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)

      improvementSuggestionsNudge

      // When detection is ON but nothing has been mined yet, say where results will appear so the
      // feature doesn't read as "advertised but empty" (the popover shows no inline list by design).
      if appState.isImprovementDetectionEnabled, appState.improvementSuggestions.isEmpty {
        Text(
          "Erkannte Korrekturen und Lern-Vorschläge erscheinen im Archiv-Fenster unter Verbesserungen."
        )
        .font(.system(size: 10))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      }

      if !appState.isArchiveEnabled {
        Text("Zuerst Archiv aktivieren.")
          .font(.system(size: 10))
          .foregroundStyle(.secondary)
      }
    }
  }

  /// Discoverability nudge for MEM-2b: the mined "Lern-Vorschläge" only live in the standalone
  /// archive window's Verbesserungen facet, so surface their count here with a one-tap jump.
  @ViewBuilder
  private var improvementSuggestionsNudge: some View {
    let count = appState.improvementSuggestions.count
    if count > 0 {
      Button {
        NotificationCenter.default.post(name: .openArchiveWindow, object: nil)
      } label: {
        HStack(spacing: 6) {
          Image(systemName: "wand.and.stars")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.blue)
          Text(
            count == 1
              ? "1 neuer Lern-Vorschlag — ansehen"
              : "\(count) neue Lern-Vorschläge — ansehen"
          )
          .font(.system(size: 10.5, weight: .medium))
          .foregroundStyle(.blue)
        }
      }
      .buttonStyle(SubtleButtonStyle())
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

// accentColorValue is defined in MenuBarStyle.swift
