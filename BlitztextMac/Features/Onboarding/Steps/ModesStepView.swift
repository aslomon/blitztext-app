import SwiftUI

/// Step 5: pre-fill the example system prompts for the E-Mail and Prompt modes, and pick the emoji
/// density for the Social mode. Prompt edits live in the view model and are persisted on advance.
struct ModesStepView: View {
  @Bindable var appState: AppState
  @Bindable var viewModel: OnboardingViewModel
  @State private var isEditingEmail = false
  @State private var isEditingPrompt = false

  var body: some View {
    VStack(alignment: .leading, spacing: OnboardingChrome.contentSpacing) {
      OnboardingStepHeader(
        systemImage: "text.badge.checkmark",
        accent: .purple,
        title: "Modi anpassen",
        subtitle: "Die drei Modi sind vorbereitet. Details kannst du später jederzeit ändern."
      )

      promptCard(
        accent: .purple,
        title: "E-Mail",
        helpText: "Was Blitztext aus deinem Diktat machen soll.",
        text: $viewModel.emailPrompt,
        isEditing: $isEditingEmail
      ) {
        viewModel.restoreExample(for: .textImprover)
      }

      promptCard(
        accent: .orange,
        title: "Prompt",
        helpText: "Für KI-Coding-Agenten wie Claude Code oder Codex.",
        text: $viewModel.promptPrompt,
        isEditing: $isEditingPrompt
      ) {
        viewModel.restoreExample(for: .dampfAblassen)
      }

      socialCard
    }
  }

  private func promptCard(
    accent: Color,
    title: String,
    helpText: String,
    text: Binding<String>,
    isEditing: Binding<Bool>,
    onRestore: @escaping () -> Void
  ) -> some View {
    OnboardingCard {
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 6) {
          Image(systemName: "circle.fill")
            .font(.system(size: 7))
            .foregroundStyle(accent)
          SectionLabel(text: title)
          Spacer()
          BlitzStatusPill(state: .ready, label: "Preset")
        }

        Text(helpText)
          .font(.system(size: 10.5))
          .foregroundStyle(.secondary)

        HStack(spacing: 8) {
          Button {
            withAnimation(.easeInOut(duration: 0.16)) { isEditing.wrappedValue.toggle() }
          } label: {
            Label(isEditing.wrappedValue ? "Fertig" : "Anpassen", systemImage: "pencil")
          }
          .buttonStyle(PopoverActionButtonStyle(isEditing.wrappedValue ? .primary : .secondary))

          Button("Beispiel") { onRestore() }
            .font(.system(size: 10, weight: .medium))
            .buttonStyle(PopoverActionButtonStyle(.quiet))
        }

        if isEditing.wrappedValue {
          TextEditor(text: text)
            .font(.system(size: 11))
            .frame(height: 96)
            .padding(6)
            .background(
              RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
              RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
            .scrollContentBackground(.hidden)
        }
      }
    }
  }

  private var socialCard: some View {
    OnboardingCard {
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 6) {
          Image(systemName: "circle.fill")
            .font(.system(size: 7))
            .foregroundStyle(.cyan)
          SectionLabel(text: "Social")
        }

        Text("Wie viele Emojis soll der Social-Modus einstreuen?")
          .font(.system(size: 10.5))
          .foregroundStyle(.secondary)

        Picker(
          "",
          selection: Binding(
            get: { appState.modeConfig(for: .emojiText).rewrite.emojiDensity },
            set: { newValue in
              appState.updateMode(.emojiText) { $0.rewrite.emojiDensity = newValue }
            }
          )
        ) {
          ForEach(EmojiTextSettings.EmojiDensity.allCases) { density in
            Text(density.displayName).tag(density)
          }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .controlSize(.small)
      }
    }
  }
}
