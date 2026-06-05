import SwiftUI

/// Configurable card for one mode slot: rename, enable, backend, model, prompt, reset.
struct ModeCardView: View {
  @Bindable var appState: AppState
  let type: WorkflowType

  @Environment(\.colorScheme) private var colorScheme

  /// Progressive disclosure: tone / prompt / context / reply / memory / reset live behind this.
  @State private var showAdvanced = false

  var config: ModeConfig { appState.modeConfig(for: type) }
  private var forcedOffline: Bool { appState.appSettings.secureLocalModeEnabled }
  var effectiveBackend: RewriteBackend { appState.resolvedRewriteBackend(for: type) }

  /// Mirrors `ModeConfig.isAdvancedNonDefault` for the live config — drives the "angepasst" dot.
  private var isAdvancedNonDefault: Bool { config.isAdvancedNonDefault }

  /// The slots that run a rewrite step — only these expose the Memory-context toggle.
  private var isRewriteMode: Bool {
    type == .textImprover || type == .dampfAblassen || type == .emojiText
  }

  /// Memory context is only injected for the text-rewrite modes, not the Emoji/Social mode.
  var supportsMemoryContext: Bool {
    type == .textImprover || type == .dampfAblassen
  }

  func bind<V>(_ keyPath: WritableKeyPath<ModeConfig, V>) -> Binding<V> {
    Binding(
      get: { appState.modeConfig(for: type)[keyPath: keyPath] },
      set: { value in appState.updateMode(type) { $0[keyPath: keyPath] = value } }
    )
  }

  private var modelOptions: [RewriteModelOption] {
    var options = RewriteModelRegistry.options(includingFetched: appState.availableModelIDs)
    if !options.contains(where: { $0.id == config.rewrite.modelID }) {
      options.append(RewriteModelRegistry.option(for: config.rewrite.modelID))
    }
    return options
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      header

      // Basic controls — always visible.
      nameField
      backendPicker

      if effectiveBackend == .openai {
        modelPicker
      } else if effectiveBackend == .local {
        LocalLLMModelPicker(appState: appState)
      }

      if type == .emojiText {
        emojiDensityPicker
      }

      advancedDisclosure
    }
    .padding(12)
    .background(
      MenuBarTokens.cardFill(colorScheme: colorScheme), in: RoundedRectangle(cornerRadius: 10)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .strokeBorder(MenuBarTokens.cardStroke(colorScheme: colorScheme), lineWidth: 0.5)
    )
    .opacity(config.isEnabled ? 1 : 0.6)
  }

  // MARK: - Advanced (progressive disclosure)

  private var advancedDisclosure: some View {
    VStack(alignment: .leading, spacing: 10) {
      advancedToggleRow

      if showAdvanced {
        advancedContent
      }
    }
  }

  private var advancedToggleRow: some View {
    Button {
      withAnimation(.easeInOut(duration: 0.15)) { showAdvanced.toggle() }
    } label: {
      HStack(spacing: 6) {
        Image(systemName: showAdvanced ? "chevron.down" : "chevron.right")
          .font(.system(size: 9, weight: .semibold))
          .foregroundStyle(.secondary)
        Text("Erweitert")
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(.secondary)
        if !showAdvanced && isAdvancedNonDefault {
          Circle()
            .fill(Color.orange)
            .frame(width: 5, height: 5)
            .help("angepasst")
        }
        Spacer()
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(SubtleButtonStyle())
  }

  @ViewBuilder
  private var advancedContent: some View {
    if type == .emojiText {
      // Emoji/Social has no tone/prompt/context — only the reset action lives here.
      footer
    } else {
      if type == .textImprover {
        tonePicker
      }
      systemPromptEditor
      if type == .textImprover {
        contextField
        replyContextPicker
      }
      if hasCustomPrompt {
        Text("Deaktiviert, solange eine eigene Anweisung gesetzt ist.")
          .font(.system(size: 10))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      if supportsMemoryContext {
        memoryToggle
      }
      footer
    }
  }

  // MARK: - Header

  private var header: some View {
    HStack {
      Image(systemName: type.icon)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.secondary)
      Text(appState.displayName(for: type).uppercased())
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
      Text(type.hotkeyLabel)
        .font(.system(size: 9.5, design: .monospaced))
        .foregroundStyle(.quaternary)
      Spacer()
      Toggle("Aktiv", isOn: bind(\.isEnabled))
        .toggleStyle(.switch)
        .controlSize(.mini)
        .labelsHidden()
    }
  }

  // MARK: - Name

  private var nameField: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Name")
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
      TextField(ModeConfig.defaultUserName(for: type), text: bind(\.userName))
        .textFieldStyle(.roundedBorder)
        .font(.system(size: 11))
    }
  }

  // MARK: - Backend

  private var backendPicker: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Verarbeitung")
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
      Picker(
        "",
        selection: forcedOffline
          ? .constant(RewriteBackend.local) : bind(\.rewrite.rewriteBackend)
      ) {
        ForEach(RewriteBackend.allCases) { backend in
          Text(backend.displayName).tag(backend)
        }
      }
      .labelsHidden()
      .controlSize(.small)
      .pickerStyle(.menu)
      .disabled(forcedOffline)

      if forcedOffline {
        Text("Sicherer lokaler Modus erzwingt lokale Verarbeitung.")
          .font(.system(size: 10))
          .foregroundStyle(.secondary)
      } else if effectiveBackend == .local {
        Text(
          "Lokal auf diesem Mac über Ollama, ohne Cloud. Ollama muss laufen (Modell unten wählen)."
        )
        .font(.system(size: 10))
        .foregroundStyle(.secondary)
      } else {
        Text("Text wird zur Formulierung an die OpenAI-API gesendet.")
          .font(.system(size: 10))
          .foregroundStyle(.secondary)
      }
    }
  }

  // MARK: - Model

  private var modelPicker: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Text("Modell")
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
        Spacer()
        Button(appState.isLoadingModels ? "Lädt …" : "Modelle vom Account laden") {
          appState.loadAvailableModels()
        }
        .font(.system(size: 10, weight: .medium))
        .buttonStyle(SubtleButtonStyle())
        .foregroundStyle(.blue)
        .disabled(appState.isLoadingModels)
      }
      Picker("", selection: bind(\.rewrite.modelID)) {
        ForEach(modelOptions) { option in
          Text(option.menuLabel).tag(option.id)
        }
      }
      .labelsHidden()
      .controlSize(.small)

      if let error = appState.modelLoadError {
        Text(error)
          .font(.system(size: 10))
          .foregroundStyle(.red)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  /// Tone + context only take effect when no custom prompt is set (see
  /// `LLMService.rewriteSystemPrompt`); mirror the `forcedOffline` disabled pattern.
  var hasCustomPrompt: Bool { !config.rewrite.systemPrompt.isEmpty }
}

// MARK: - Local LLM model picker (Ollama)
//
// The redesigned, state-driven `LocalLLMModelPicker` lives in `LocalLLMModelPicker.swift`.
// The advanced-section subviews (tone / prompt / context / reply / emoji / memory / footer)
// live in `ModeCardAdvanced.swift`.
