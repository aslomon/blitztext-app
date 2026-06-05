import SwiftUI

/// Step 3: choose where transcription and rewriting happen. Online (OpenAI) reveals the key entry;
/// "Sicherer lokaler Modus" flips the offline master and shows a green offline assurance.
struct ProcessingStepView: View {
  @Bindable var appState: AppState

  private var isLocal: Bool { appState.appSettings.secureLocalModeEnabled }

  var body: some View {
    VStack(alignment: .leading, spacing: OnboardingChrome.contentSpacing) {
      OnboardingStepHeader(
        systemImage: "cpu",
        accent: .blue,
        title: "Verarbeitung",
        subtitle: "Wo sollen Aufnahme und Umformung laufen? Du kannst das jederzeit umstellen."
      )

      VStack(spacing: 10) {
        choiceCard(
          selected: !isLocal,
          icon: "cloud",
          accent: .blue,
          title: "Online (OpenAI)",
          detail:
            "Schnell und stark. Audio und Text gehen an die OpenAI API. Eigener API Key nötig."
        ) {
          appState.appSettings.secureLocalModeEnabled = false
        }

        choiceCard(
          selected: isLocal,
          icon: "lock.shield.fill",
          accent: .green,
          title: "Sicherer lokaler Modus",
          detail: "Alles bleibt auf diesem Mac. Kein Server, keine Cloud. Lokale Modelle nötig."
        ) {
          appState.enableSecureLocalMode()
        }
      }

      if isLocal {
        offlineAssurance
      } else {
        OnboardingCard {
          OpenAIKeySection(appState: appState)
        }
      }
    }
  }

  private func choiceCard(
    selected: Bool,
    icon: String,
    accent: Color,
    title: String,
    detail: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: selected ? "largecircle.fill.circle" : "circle")
          .font(.system(size: 14))
          .foregroundStyle(selected ? accent : .secondary)
          .frame(width: 18, height: 18)

        VStack(alignment: .leading, spacing: 3) {
          HStack(spacing: 6) {
            Image(systemName: icon)
              .font(.system(size: 12, weight: .semibold))
              .foregroundStyle(accent)
            Text(title)
              .font(.system(size: 12.5, weight: .semibold))
              .foregroundStyle(.primary)
          }
          Text(detail)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 0)
      }
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: OnboardingChrome.cardCornerRadius)
          .fill(accent.opacity(selected ? 0.08 : 0.02))
      )
      .overlay(
        RoundedRectangle(cornerRadius: OnboardingChrome.cardCornerRadius)
          .strokeBorder(accent.opacity(selected ? 0.35 : 0.1), lineWidth: selected ? 1 : 0.5)
      )
    }
    .buttonStyle(SubtleButtonStyle())
  }

  private var offlineAssurance: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "checkmark.shield.fill")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.green)
        .frame(width: 16, height: 16)
      Text(
        "Offline aktiv: Deine Aufnahmen verlassen diesen Mac nicht. Im nächsten Schritt lädst du das lokale Whisper-Modell."
      )
      .font(.system(size: 10.5))
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 0)
    }
  }
}
