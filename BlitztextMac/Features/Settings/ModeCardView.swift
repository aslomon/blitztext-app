import SwiftUI

/// Configurable card for one mode slot: rename, enable, backend, model, prompt, reset.
struct ModeCardView: View {
  @Bindable var appState: AppState
  let type: WorkflowType

  @Environment(\.colorScheme) private var colorScheme

  /// Progressive disclosure: tone / prompt / context / reply / memory / reset live behind this.
  @State private var showAdvanced = false
  @State private var showEditor = false

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

  var supportsAutomaticFieldContext: Bool {
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
    GroupBox {
      if showEditor {
        editorContent
      } else {
        summaryContent
      }
    } label: {
      header
    }
    .opacity(config.isEnabled ? 1 : 0.68)
  }

  private var editorContent: some View {
    VStack(alignment: .leading, spacing: 10) {
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
      editorFooter
    }
  }

  private var summaryContent: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 6) {
        BlitzStatusPill(state: config.isEnabled ? .ready : .muted, label: config.isEnabled ? "Aktiv" : "Aus")
        BlitzStatusPill(state: backendPillState, label: effectiveBackend == .local ? "Lokal" : "Online")
        if isAdvancedNonDefault {
          BlitzStatusPill(state: .warning, label: "Angepasst")
        }
        Spacer(minLength: 0)
      }

      Text(summaryLine)
        .font(.system(size: 10.5))
        .foregroundStyle(.secondary)
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)

      Button {
        withAnimation(.easeInOut(duration: 0.16)) { showEditor = true }
      } label: {
        Label("Bearbeiten", systemImage: "pencil")
      }
      .buttonStyle(PopoverActionButtonStyle(.secondary))
    }
  }

  private var backendPillState: BlitzStatusPill.State {
    effectiveBackend == .local ? .local : .online
  }

  private var summaryLine: String {
    if type == .emojiText {
      return "Emoji-Dichte: \(config.rewrite.emojiDensity.displayName)."
    }
    if effectiveBackend == .local {
      return "Umformung läuft lokal über Ollama."
    }
    return "Umformung über \(config.rewrite.modelID)."
  }

  private var editorFooter: some View {
    HStack {
      Spacer()
      Button {
        withAnimation(.easeInOut(duration: 0.16)) { showEditor = false }
      } label: {
        Label("Fertig", systemImage: "checkmark")
      }
      .buttonStyle(PopoverActionButtonStyle(.primary))
    }
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
    .buttonStyle(PopoverActionButtonStyle(.quiet))
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
      if supportsAutomaticFieldContext {
        automaticFieldContextToggle
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
      Button {
        withAnimation(.easeInOut(duration: 0.16)) { showEditor.toggle() }
      } label: {
        Image(systemName: showEditor ? "checkmark" : "pencil")
      }
      .buttonStyle(PopoverIconButtonStyle(showEditor ? .primary : .quiet))
      .help(showEditor ? "Bearbeitung schließen" : "Modus bearbeiten")
      .accessibilityLabel(showEditor ? "Bearbeitung schließen" : "Modus bearbeiten")
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

      InfoDisclosure("Datenfluss") {
        if forcedOffline {
          Text("Sicherer lokaler Modus erzwingt lokale Verarbeitung.")
        } else if effectiveBackend == .local {
          Text("Lokal auf diesem Mac über Ollama, ohne Cloud. Ollama muss laufen.")
        } else {
          Text("Text wird zur Formulierung an die OpenAI-API gesendet.")
        }
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
        .buttonStyle(PopoverActionButtonStyle(.quiet))
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
