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
      .buttonStyle(PopoverActionButtonStyle(.secondary))
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
        .buttonStyle(PopoverActionButtonStyle(.danger))
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

}

// accentColorValue is defined in MenuBarStyle.swift
