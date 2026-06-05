import SwiftUI

/// Inline control for choosing the local rewrite model served by Ollama. State-driven and honest —
/// it NEVER shows a dropdown of un-downloaded suggestions. Three states, fed by the shared
/// `AppState.localModelManager` so it stays in sync with the "Lokale Modelle" window:
///   1. Ollama not running → short hint + "Prüfen".
///   2. Running, no models  → guided recommendation card with an inline "Laden" (no dropdown).
///   3. Running, ≥1 model   → a real picker over the ACTUALLY-installed models only.
/// The selection is global, bound to `appSettings.selectedLocalLLMModelName`.
struct LocalLLMModelPicker: View {
  @Bindable var appState: AppState

  private var manager: LocalModelManager { appState.localModelManager }

  private var selectedName: String {
    appState.appSettings.selectedLocalLLMModelName.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Lokales Sprachmodell (Ollama)")
        .font(.system(size: 11))
        .foregroundStyle(.secondary)

      content

      manageButton
    }
    .task {
      await manager.refresh()
      autoSelectIfNeeded()
    }
    .onChange(of: manager.installed) { _, _ in autoSelectIfNeeded() }
  }

  @ViewBuilder private var content: some View {
    if !manager.serverReachable {
      serverDownHint
    } else if manager.installed.isEmpty {
      emptyStateGuidance
    } else {
      installedSelector
    }
  }

  // MARK: - State 1: server down

  private var serverDownHint: some View {
    HStack(alignment: .top, spacing: 6) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 10, weight: .semibold)).foregroundStyle(.orange)
      Text("Ollama läuft nicht — im Verwalten-Fenster kannst du es starten/installieren.")
        .font(.system(size: 10)).foregroundStyle(.orange)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 6)
      Button("Prüfen") { Task { await manager.refresh() } }
        .font(.system(size: 10, weight: .medium))
        .buttonStyle(SubtleButtonStyle()).foregroundStyle(.blue)
    }
  }

  // MARK: - State 2: no models → guided recommendation (no dropdown)

  @ViewBuilder private var emptyStateGuidance: some View {
    Text("Noch kein lokales Modell geladen.")
      .font(.system(size: 10.5)).foregroundStyle(.secondary)

    if let recommended = manager.recommended {
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 6) {
          Image(systemName: "sparkles").font(.system(size: 10, weight: .semibold))
          Text("Empfohlen: \(recommended.displayName)")
            .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(.blue)

        Text(
          "ca. \(SystemCapabilities.formatGB(recommended.downloadGB)) · "
            + "~\(SystemCapabilities.formatGB(recommended.estimatedRuntimeRAMGB)) RAM"
        )
        .font(.system(size: 10)).foregroundStyle(.secondary)

        if let pull = manager.pulls[recommended.tag] {
          inlinePullProgress(pull, tag: recommended.tag)
        } else {
          Button {
            manager.pull(recommended.tag)
          } label: {
            Label("Empfohlenes Modell laden", systemImage: "arrow.down.circle.fill")
              .font(.system(size: 11, weight: .semibold))
          }
          .buttonStyle(.borderless)
        }
      }
      .padding(8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(RoundedRectangle(cornerRadius: 8).fill(Color.blue.opacity(0.07)))
    }
  }

  // MARK: - State 3: installed → real selector over installed models

  private var installedSelector: some View {
    VStack(alignment: .leading, spacing: 4) {
      Picker("", selection: $appState.appSettings.selectedLocalLLMModelName) {
        ForEach(manager.installed) { model in
          Text(model.name).tag(model.name)
        }
        // Keep a persisted-but-unlisted selection visible so the picker never loses it.
        if !selectedName.isEmpty,
          !manager.installed.contains(where: { $0.name == selectedName })
        {
          Text("\(selectedName) · nicht geladen").tag(selectedName)
        }
      }
      .labelsHidden()
      .controlSize(.small)
      .pickerStyle(.menu)

      HStack(spacing: 6) {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 10, weight: .semibold)).foregroundStyle(.green)
        Text("\(manager.installed.count) Modell(e) geladen")
          .font(.system(size: 10)).foregroundStyle(.secondary)
      }
    }
  }

  // MARK: - Shared bits

  private func inlinePullProgress(_ pull: LocalModelManager.PullUIState, tag: String) -> some View {
    HStack(spacing: 8) {
      if let fraction = pull.fraction {
        ProgressView(value: fraction).frame(width: 90)
      } else {
        ProgressView().controlSize(.small)
      }
      Text(pull.statusText).font(.system(size: 9.5)).foregroundStyle(.secondary).lineLimit(1)
      Spacer(minLength: 6)
      Button("Abbrechen") { manager.cancelPull(tag) }
        .buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(.secondary)
        .help(
          "Abbrechen — der Teil-Download bleibt erhalten und wird beim erneuten Laden fortgesetzt.")
    }
  }

  private var manageButton: some View {
    Button {
      NotificationCenter.default.post(name: .openLocalModelsWindow, object: nil)
    } label: {
      Label(
        manager.installed.isEmpty ? "Mehr Modelle …" : "Modelle verwalten & laden …",
        systemImage: "square.and.arrow.down.on.square"
      )
      .font(.system(size: 10.5, weight: .medium))
    }
    .buttonStyle(SubtleButtonStyle())
    .foregroundStyle(.blue)
  }

  /// Auto-select the first installed model when nothing is chosen yet, so the user is never left
  /// with an empty selection after a download finishes (better guidance, no manual step).
  private func autoSelectIfNeeded() {
    guard selectedName.isEmpty, let first = manager.installed.first else { return }
    appState.appSettings.selectedLocalLLMModelName = first.name
  }
}
