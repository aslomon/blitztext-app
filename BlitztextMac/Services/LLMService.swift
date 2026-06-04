import Foundation

enum LLMError: LocalizedError {
  case notConfigured
  case networkError(String)
  case apiError(String)
  case noContent
  case modelUnavailable(String)
  case localModelUnavailable(String)

  var errorDescription: String? {
    switch self {
    case .notConfigured:
      return "OpenAI API Key fehlt. Bitte in den Einstellungen hinterlegen."
    case .networkError(let msg):
      return "Verbindungsproblem: \(msg)"
    case .apiError(let msg):
      return "Fehler von OpenAI: \(msg)"
    case .noContent:
      return "Keine Antwort erhalten. Bitte nochmal versuchen."
    case .modelUnavailable(let model):
      return "Modell \(model) ist auf deinem OpenAI-Account nicht verfügbar."
    case .localModelUnavailable(let reason):
      return reason
    }
  }
}

/// Builds the system prompts for the rewrite step. Transport lives in the
/// `RewriteProvider` implementations; this stays the durable, provider-agnostic asset.
enum LLMService {
  /// Default rewrite temperature (providers omit it for models that don't support it).
  static let defaultRewriteTemperature = 0.3

  // MARK: - Rewrite prompt (E-Mail / Prompt / generischer Verbesserer)

  static func rewriteSystemPrompt(
    _ rewrite: RewriteConfig,
    customTerms: [String],
    selection: SelectionContext?
  ) -> String {
    var prompt: String

    if !rewrite.systemPrompt.isEmpty {
      prompt = rewrite.systemPrompt
    } else {
      prompt = defaultImproverPrompt(tone: rewrite.tone)
      if !rewrite.context.isEmpty {
        prompt += "\n\nKontext: \(rewrite.context)"
      }
    }

    if !customTerms.isEmpty {
      prompt +=
        "\n\nWichtig: Diese Eigennamen und Fachbegriffe müssen exakt so geschrieben werden: \(customTerms.joined(separator: ", "))"
    }

    if let block = selectionContextBlock(for: rewrite.replyContextMode, selection: selection) {
      prompt += block
    }

    return prompt
  }

  // MARK: - Emoji prompt

  static func emojiSystemPrompt(_ rewrite: RewriteConfig) -> String {
    let densityInstruction: String
    switch rewrite.emojiDensity {
    case .wenig:
      densityInstruction = "Setze nur vereinzelt Emojis ein, maximal 1-2 pro Absatz."
    case .mittel:
      densityInstruction = "Setze regelmaessig passende Emojis ein, etwa alle 1-2 Saetze."
    case .viel:
      densityInstruction = "Setze grosszuegig Emojis ein, gerne mehrere pro Satz."
    }

    return
      "Du erhaeltst ein gesprochenes Transkript. Gib den Text moeglichst originalgetreu zurueck, aber fuege passende Emojis ein. \(densityInstruction) Korrigiere offensichtliche Sprach- und Grammatikfehler. Behalte den Stil und die Bedeutung bei. Gib NUR den Text mit Emojis zurueck, keine Erklaerungen."
  }

  // MARK: - Helpers

  private static func defaultImproverPrompt(tone: TextImprovementSettings.TextTone) -> String {
    var prompt = """
      Du bist ein Lektor und Schreibassistent. Verbessere den folgenden Text:
      - Korrigiere Rechtschreibung und Grammatik
      - Verbessere die Formulierung und den Lesefluss
      - Behalte die urspruengliche Bedeutung bei
      - Gib NUR den verbesserten Text zurueck, keine Erklaerungen
      """
    switch tone {
    case .formal:
      prompt += "\n- Verwende einen formellen, professionellen Ton"
    case .neutral:
      prompt += "\n- Verwende einen neutralen, klaren Ton"
    case .casual:
      prompt += "\n- Verwende einen lockeren, natuerlichen Ton"
    }
    return prompt
  }

  private static func selectionContextBlock(
    for mode: ReplyContextMode,
    selection: SelectionContext?
  ) -> String? {
    guard mode != .off, let selection, !selection.isEmpty else { return nil }

    switch mode {
    case .off:
      return nil
    case .replyUsingContext:
      // Reply may use the selection or, failing that, the surrounding text as context.
      let source =
        selection.selectedText.isEmpty ? selection.surroundingText : selection.selectedText
      let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { return nil }
      return replyBlock(trimmed)
    case .editSelection:
      // Editing requires a real selection — never silently rewrite the whole field.
      let trimmed = selection.selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { return nil }
      return editBlock(trimmed)
    }
  }

  private static func replyBlock(_ trimmed: String) -> String {
    """


    --- Markierter Text aus der aktuellen App (Kontext) ---
    \(trimmed)
    --- Ende ---
    Der obige Text ist der Kontext, auf den ich mich beziehe. Formuliere meine diktierte \
    Nachricht als passende, in sich geschlossene Antwort darauf. Wiederhole den Originaltext nicht wörtlich.
    """
  }

  private static func editBlock(_ trimmed: String) -> String {
    """


    --- Zu bearbeitender Text ---
    \(trimmed)
    --- Ende ---
    Wende meine diktierten Änderungen auf den obigen Text an und gib NUR die überarbeitete \
    Fassung dieses Textes zurück.
    """
  }

}
