import AppKit
import SwiftUI

/// Self-contained "OpenAI API Key" surface: masked display + edit/paste, validation, and the
/// "Speichern" button (which belongs to the key). Owns its own state so it can be dropped into any
/// settings tab. Lives in the Modelle tab next to the local engines.
struct OpenAIKeySection: View {
  private static let openAIAPIKeyPattern = #"^sk-[A-Za-z0-9_-]{20,}$"#

  @Bindable var appState: AppState

  private enum FieldFocus {
    case openAIAPIKey
  }

  @State private var apiKey = ""
  @State private var editing = false
  @State private var saved = false
  @State private var errorText: String?
  @FocusState private var focused: FieldFocus?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        SectionLabel(text: "OpenAI API Key")
        Spacer()
        if appState.hasValue(for: .openAIAPIKey) && !editing {
          Button("Ändern") { editing = true }
            .font(.system(size: 10, weight: .medium))
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
        }
      }

      if appState.hasValue(for: .openAIAPIKey) && !editing {
        maskedKey
      } else {
        keyEntryRow
      }

      Text(
        "Dein Key bleibt lokal in dieser App. Audio und Text werden direkt an die OpenAI API gesendet."
      )
      .font(.system(size: 10.5))
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)

      if let errorText {
        Text(errorText)
          .font(.system(size: 10.5))
          .foregroundStyle(.red)
          .fixedSize(horizontal: false, vertical: true)
      }

      saveButton
    }
    .onAppear {
      if !appState.hasValue(for: .openAIAPIKey) {
        editing = true
        focused = .openAIAPIKey
      }
    }
  }

  private var maskedKey: some View {
    HStack(spacing: 6) {
      Image(systemName: "lock.fill")
        .font(.system(size: 9))
        .foregroundStyle(.green.opacity(0.8))
      Text(appState.apiKeyDisplayValue(for: .openAIAPIKey))
        .font(.system(size: 11, design: .monospaced))
        .foregroundStyle(.secondary)
    }
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 6)
        .fill(Color(nsColor: .controlBackgroundColor))
    )
  }

  private var keyEntryRow: some View {
    HStack(spacing: 8) {
      SecureField("sk-...", text: $apiKey)
        .textFieldStyle(.roundedBorder)
        .font(.system(size: 11.5))
        .focused($focused, equals: .openAIAPIKey)

      Button("Einfügen") {
        pasteAPIKeyFromClipboard()
      }
      .buttonStyle(SubtleButtonStyle())
    }
  }

  private var saveButton: some View {
    HStack {
      Spacer()
      Button {
        save()
      } label: {
        if saved {
          HStack(spacing: 4) {
            Image(systemName: "checkmark")
              .font(.system(size: 10, weight: .bold))
            Text("Gespeichert")
          }
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(.green)
        } else {
          Text("Speichern")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.blue)
        }
      }
      .buttonStyle(SubtleButtonStyle())
      .animation(.easeInOut(duration: 0.2), value: saved)
    }
  }

  private func save() {
    errorText = nil
    KeychainService.invalidateCache()
    let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

    if editing || !appState.hasValue(for: .openAIAPIKey) {
      guard !trimmedAPIKey.isEmpty else {
        errorText = "Bitte trage deinen OpenAI API Key ein."
        return
      }
      do {
        try KeychainService.save(key: .openAIAPIKey, value: trimmedAPIKey)
        apiKey = ""
        editing = false
      } catch {
        errorText = "OpenAI API Key konnte nicht gespeichert werden."
        return
      }
    }

    KeychainService.invalidateCache()
    if !appState.hasValue(for: .openAIAPIKey) {
      errorText =
        "OpenAI API Key wurde nicht persistent gespeichert. Bitte App neu starten und erneut versuchen."
      return
    }

    withAnimation(.easeInOut(duration: 0.2)) { saved = true }
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
      withAnimation(.easeInOut(duration: 0.2)) { saved = false }
    }
  }

  private func pasteAPIKeyFromClipboard() {
    guard let rawText = NSPasteboard.general.string(forType: .string) else {
      errorText = "Zwischenablage enthält keinen Text."
      return
    }

    let firstLine = rawText.components(separatedBy: .newlines).first ?? rawText
    let trimmedKey = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmedKey.range(of: Self.openAIAPIKeyPattern, options: .regularExpression) != nil else {
      errorText = "Zwischenablage enthält keinen plausiblen OpenAI API Key."
      return
    }

    apiKey = trimmedKey
    NSPasteboard.general.clearContents()
    errorText = nil
  }
}
