import SwiftUI

// MARK: - ModeCardView advanced + emoji subviews
//
// The "Erweitert" disclosure of a mode card: tone, custom prompt, context, reply-context,
// memory toggle and the reset footer — plus the always-basic emoji-density picker. Split out of
// `ModeCardView.swift` to keep each file compact (DESIGN.md / code-quality rules).
extension ModeCardView {

  // MARK: - Tone / Prompt / Context / Reply

  var tonePicker: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Schreibstil")
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
      Picker("", selection: bind(\.rewrite.tone)) {
        ForEach(TextImprovementSettings.TextTone.allCases) { tone in
          Text(tone.displayName).tag(tone)
        }
      }
      .pickerStyle(.segmented)
      .disabled(hasCustomPrompt)
    }
  }

  var systemPromptEditor: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Eigene Anweisung")
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
      TextEditor(text: bind(\.rewrite.systemPrompt))
        .font(.system(size: 11))
        .frame(height: 96)
        .scrollContentBackground(.hidden)
        .padding(8)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 6))
        .overlay(
          RoundedRectangle(cornerRadius: 6).strokeBorder(
            Color.primary.opacity(0.06), lineWidth: 0.5))
    }
  }

  var contextField: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Kontext")
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
      TextField("z.B. \"E-Mails im Bereich Unternehmensberatung\"", text: bind(\.rewrite.context))
        .textFieldStyle(.roundedBorder)
        .font(.system(size: 11))
        .disabled(hasCustomPrompt)
    }
  }

  var replyContextPicker: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Markierten Text einbeziehen")
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
      Picker("", selection: bind(\.rewrite.replyContextMode)) {
        ForEach(ReplyContextMode.allCases) { mode in
          Text(mode.displayName).tag(mode)
        }
      }
      .labelsHidden()
      .controlSize(.small)
      .pickerStyle(.menu)
      if config.rewrite.replyContextMode != .off {
        InfoDisclosure("Kontext-Details") {
          Text("Liest die aktuelle Auswahl in der App und bezieht sie als Kontext ein. Bei OpenAI-Verarbeitung wird der markierte Text mitgesendet.")
        }
      }
    }
  }

  var emojiDensityPicker: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Emoji-Dichte")
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
      Picker("", selection: bind(\.rewrite.emojiDensity)) {
        ForEach(EmojiTextSettings.EmojiDensity.allCases) { density in
          Text(density.displayName).tag(density)
        }
      }
      .pickerStyle(.segmented)
    }
  }

  // MARK: - Memory context (rewrite modes only)

  @ViewBuilder
  var automaticFieldContextToggle: some View {
    VStack(alignment: .leading, spacing: 4) {
      Toggle("Arbeitskontext automatisch lesen", isOn: bind(\.rewrite.useAutomaticFieldContext))
        .toggleStyle(.switch)
        .controlSize(.small)
        .font(.system(size: 11))

      if config.rewrite.useAutomaticFieldContext {
        automaticFieldContextHint
      }
    }
  }

  @ViewBuilder
  private var automaticFieldContextHint: some View {
    if effectiveBackend == .openai {
      Text(
        "Liest beim Start das fokussierte Eingabefeld bis zum Cursor als Kontext. Bei Online-Verarbeitung wird dieser Kontext mit an die OpenAI-API gesendet."
      )
      .font(.system(size: 10))
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
    } else {
      Text("Liest beim Start das fokussierte Eingabefeld bis zum Cursor als lokalen Kontext.")
        .font(.system(size: 10))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  @ViewBuilder
  var memoryToggle: some View {
    VStack(alignment: .leading, spacing: 4) {
      Toggle("Memory-Kontext nutzen", isOn: bind(\.rewrite.useMemoryContext))
        .toggleStyle(.switch)
        .controlSize(.small)
        .font(.system(size: 11))
        .disabled(!appState.isMemoryContextEnabled)

      if !appState.isMemoryContextEnabled {
        Text("Zuerst global „Memory als Kontext nutzen“ im Archiv aktivieren.")
          .font(.system(size: 10))
          .foregroundStyle(.secondary)
      } else if config.rewrite.useMemoryContext {
        memoryActiveHint
      }
    }
  }

  @ViewBuilder
  private var memoryActiveHint: some View {
    if effectiveBackend == .openai {
      Text(
        "Dein persönliches Vokabular (Namen, Fachbegriffe, Fremdwörter) wird als "
          + "Schreibhinweis mitgesendet — bei dieser Online-Verarbeitung an die OpenAI-API."
      )
      .font(.system(size: 10))
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
    } else {
      Text("Dein persönliches Vokabular fließt als Schreibhinweis ein — lokal auf dem Gerät.")
        .font(.system(size: 10))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  // MARK: - Footer

  var footer: some View {
    HStack {
      Spacer()
      Button("Auf Standard zurücksetzen") {
        appState.resetMode(type)
      }
      .font(.system(size: 10, weight: .medium))
      .buttonStyle(PopoverActionButtonStyle(.secondary))
    }
  }
}
