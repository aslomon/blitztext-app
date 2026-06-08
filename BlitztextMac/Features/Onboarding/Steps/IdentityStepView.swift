import SwiftUI

struct IdentityStepView: View {
  @Bindable var appState: AppState

  var body: some View {
    VStack(alignment: .leading, spacing: OnboardingChrome.contentSpacing) {
      OnboardingStepHeader(
        systemImage: "person.text.rectangle",
        accent: .indigo,
        title: "Deine Schreibperspektive",
        subtitle:
          "Blitztext braucht deinen Namen, damit E-Mail-Antworten aus der richtigen Sicht formuliert werden."
      )

      OnboardingCard(accent: .indigo) {
        VStack(alignment: .leading, spacing: 12) {
          TextField("Dein Name", text: $appState.appSettings.userDisplayName)
            .textFieldStyle(.roundedBorder)
            .font(.system(size: 13))

          VStack(alignment: .leading, spacing: 5) {
            Label(
              "wird als „Ich schreibe als …“ in E-Mail- und Rewrite-Prompts genutzt",
              systemImage: "checkmark.circle.fill"
            )
            Label(
              "hilft der Spracherkennung, deinen Namen korrekt zu schreiben",
              systemImage: "checkmark.circle.fill"
            )
            Label("bleibt lokal in deinen Einstellungen", systemImage: "lock.fill")
          }
          .font(.system(size: 11.5))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
  }
}
