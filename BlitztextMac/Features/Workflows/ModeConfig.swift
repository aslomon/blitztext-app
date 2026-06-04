import Foundation

// MARK: - Mode building blocks

/// What a slot actually DOES, independent of its user-facing name.
/// Stored but not user-editable in this phase (the active-view downcasts in
/// MenuBarView depend on a slot keeping its workflow class).
enum ModeKind: String, Codable {
  case transcribeOnly
  case transcribeThenRewrite
  case transcribeThenEmoji
}

/// Where the rewrite step runs.
enum RewriteBackend: String, Codable, CaseIterable, Identifiable {
  case openai
  case local

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .openai: return "Online (OpenAI)"
    case .local: return "Lokal"
    }
  }

  /// Tolerant decoder mapping that keeps legacy on-disk settings parseable.
  /// Old files persisted the raw value "appleIntelligence" for the local backend.
  static func from(rawValue raw: String) -> RewriteBackend {
    if let backend = RewriteBackend(rawValue: raw) { return backend }
    switch raw {
    case "appleIntelligence": return .local
    default: return .openai
    }
  }
}

/// How a mode incorporates the text the user has selected in the frontmost app.
enum ReplyContextMode: String, Codable, CaseIterable, Identifiable {
  case off
  case replyUsingContext
  case editSelection

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .off: return "Aus"
    case .replyUsingContext: return "Als Kontext (Antwort)"
    case .editSelection: return "Auswahl bearbeiten"
    }
  }
}

/// Everything that controls the optional rewrite step of a mode.
struct RewriteConfig: Codable {
  var systemPrompt: String = ""
  var rewriteBackend: RewriteBackend = .openai
  var modelID: String = RewriteModelRegistry.defaultModelID
  var tone: TextImprovementSettings.TextTone = .neutral
  var context: String = ""
  var emojiDensity: EmojiTextSettings.EmojiDensity = .mittel
  var replyContextMode: ReplyContextMode = .off

  init(
    systemPrompt: String = "",
    rewriteBackend: RewriteBackend = .openai,
    modelID: String = RewriteModelRegistry.defaultModelID,
    tone: TextImprovementSettings.TextTone = .neutral,
    context: String = "",
    emojiDensity: EmojiTextSettings.EmojiDensity = .mittel,
    replyContextMode: ReplyContextMode = .off
  ) {
    self.systemPrompt = systemPrompt
    self.rewriteBackend = rewriteBackend
    self.modelID = modelID
    self.tone = tone
    self.context = context
    self.emojiDensity = emojiDensity
    self.replyContextMode = replyContextMode
  }

  enum CodingKeys: String, CodingKey {
    case systemPrompt, rewriteBackend, modelID, tone, context, emojiDensity, replyContextMode
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    systemPrompt = try c.decodeIfPresent(String.self, forKey: .systemPrompt) ?? ""
    // Decode the raw string and map tolerantly so legacy "appleIntelligence" files
    // (the former on-device case) still parse onto the renamed `.local` backend.
    if let rawBackend = try c.decodeIfPresent(String.self, forKey: .rewriteBackend) {
      rewriteBackend = RewriteBackend.from(rawValue: rawBackend)
    } else {
      rewriteBackend = .openai
    }
    modelID =
      try c.decodeIfPresent(String.self, forKey: .modelID) ?? RewriteModelRegistry.defaultModelID
    tone = try c.decodeIfPresent(TextImprovementSettings.TextTone.self, forKey: .tone) ?? .neutral
    context = try c.decodeIfPresent(String.self, forKey: .context) ?? ""
    emojiDensity =
      try c.decodeIfPresent(EmojiTextSettings.EmojiDensity.self, forKey: .emojiDensity) ?? .mittel
    replyContextMode =
      try c.decodeIfPresent(ReplyContextMode.self, forKey: .replyContextMode) ?? .off
  }
}

// MARK: - Per-slot configuration

/// A configurable, renamable mode layered over the fixed `WorkflowType` slot.
struct ModeConfig: Codable, Identifiable {
  var slot: WorkflowType
  var id: String { slot.rawValue }
  var userName: String = ""
  var isEnabled: Bool = true
  var kind: ModeKind
  var rewrite: RewriteConfig = RewriteConfig()

  init(
    slot: WorkflowType, userName: String = "", isEnabled: Bool = true, kind: ModeKind,
    rewrite: RewriteConfig = RewriteConfig()
  ) {
    self.slot = slot
    self.userName = userName
    self.isEnabled = isEnabled
    self.kind = kind
    self.rewrite = rewrite
  }

  enum CodingKeys: String, CodingKey {
    case slot, userName, isEnabled, kind, rewrite
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let decodedSlot = try c.decodeIfPresent(WorkflowType.self, forKey: .slot) ?? .transcription
    slot = decodedSlot
    userName = try c.decodeIfPresent(String.self, forKey: .userName) ?? ""
    isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    kind =
      try c.decodeIfPresent(ModeKind.self, forKey: .kind)
      ?? ModeConfig.defaultKind(for: decodedSlot)
    rewrite =
      try c.decodeIfPresent(RewriteConfig.self, forKey: .rewrite)
      ?? ModeConfig.defaultRewrite(for: decodedSlot)
  }

  // MARK: - Defaults

  static func defaultKind(for slot: WorkflowType) -> ModeKind {
    switch slot {
    case .transcription, .localTranscription: return .transcribeOnly
    case .textImprover, .dampfAblassen: return .transcribeThenRewrite
    case .emojiText: return .transcribeThenEmoji
    }
  }

  /// User-facing default names for the repurposed slots.
  static func defaultUserName(for slot: WorkflowType) -> String {
    switch slot {
    case .transcription: return "Diktat"
    case .localTranscription: return "Diktat (lokal)"
    case .textImprover: return "E-Mail"
    case .dampfAblassen: return "Prompt"
    case .emojiText: return "Social"
    }
  }

  static func defaultRewrite(for slot: WorkflowType) -> RewriteConfig {
    switch slot {
    case .textImprover:
      return RewriteConfig(
        systemPrompt: ModeDefaults.emailSystemPrompt, modelID: RewriteModelRegistry.strongModelID)
    case .dampfAblassen:
      return RewriteConfig(
        systemPrompt: ModeDefaults.promptCraftSystemPrompt,
        modelID: RewriteModelRegistry.strongModelID)
    case .emojiText:
      return RewriteConfig(modelID: RewriteModelRegistry.fastModelID)
    case .transcription, .localTranscription:
      return RewriteConfig()
    }
  }

  static func `default`(for slot: WorkflowType) -> ModeConfig {
    ModeConfig(
      slot: slot,
      userName: defaultUserName(for: slot),
      isEnabled: true,
      kind: defaultKind(for: slot),
      rewrite: defaultRewrite(for: slot)
    )
  }
}

// MARK: - Curated default prompts

enum ModeDefaults {
  static let emailSystemPrompt = """
    Du bist ein Schreibassistent für E-Mails. Du erhältst ein gesprochenes, ungeordnetes Transkript, in \
    dem ich grob sage, was ich jemandem schreiben will. Formuliere daraus eine fertige, klar \
    strukturierte E-Mail auf Deutsch: passende Anrede, logisch gegliederter Fließtext in kurzen \
    Absätzen, höflicher Abschluss. Behalte alle genannten Fakten, Namen, Zahlen, Termine und das \
    eigentliche Anliegen exakt bei und erfinde nichts dazu. Schreibe natürlich, professionell und \
    freundlich, ohne Floskeln zu übertreiben. Fehlt eine Anrede oder Grußformel, wähle eine passende \
    neutrale. Gib NUR die fertige E-Mail zurück, ohne Erklärungen und ohne Betreffzeile, außer ich \
    diktiere ausdrücklich einen Betreff.
    """

  static let promptCraftSystemPrompt = """
    Du erhältst ein gesprochenes, ungeordnetes Transkript, in dem ich eine Programmier- oder \
    Arbeitsaufgabe für einen KI-Coding-Agenten (Claude Code oder Codex) beschreibe. Formuliere daraus \
    einen klaren, gut strukturierten Prompt auf Deutsch. Behalte ausnahmslos alle inhaltlichen Details, \
    Anforderungen, Datei- und Funktionsnamen, Randbedingungen und meine Absicht bei – kürze nichts \
    Inhaltliches weg und räume nicht übereifrig auf. Strukturiere den Prompt logisch: kurze \
    Aufgabenbeschreibung, dann konkrete Anforderungen als Aufzählung, dann ggf. Kontext oder \
    Einschränkungen. Nutze präzise, korrekte Fachbegriffe statt umgangssprachlicher Umschreibungen, \
    aber erfinde keine Anforderungen dazu, die ich nicht gesagt habe. Wandle gesprochene Code- oder \
    Technik-Begriffe in ihre korrekte Schreibweise um. Gib NUR den fertigen Prompt zurück, ohne \
    Vorbemerkung oder Erklärung.
    """
}
