import SwiftUI

/// Step 1: a warm intro with three value bullets and (when applicable) the "move to /Applications"
/// nudge carried over from the old in-popover onboarding.
struct WelcomeStepView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: OnboardingChrome.contentSpacing) {
      OnboardingStepHeader(
        systemImage: "sparkles",
        accent: .blue,
        title: "Willkommen bei Blitztext",
        subtitle:
          "Einmal einrichten, dann sprichst du überall — und der fertige Text landet direkt im Feld."
      )

      VStack(alignment: .leading, spacing: 10) {
        valueBullet(
          icon: "mic.fill", accent: .blue,
          title: "Sprechen statt tippen",
          detail:
            "Halte das Kürzel, sprich, lass los — der Text wird an der Cursorposition eingefügt.")
        valueBullet(
          icon: "text.badge.checkmark", accent: .purple,
          title: "Fertig formuliert",
          detail: "E-Mail, Prompt oder Social: Blitztext bringt das Diktat in die passende Form.")
        valueBullet(
          icon: "lock.shield.fill", accent: .green,
          title: "Online oder komplett lokal",
          detail: "Wahlweise über OpenAI oder vollständig offline auf diesem Mac.")
      }

      if BlitztextInstallLocationService.shouldOfferMoveToApplications {
        installCard
      }
    }
  }

  private func valueBullet(icon: String, accent: Color, title: String, detail: String)
    -> some View
  {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: icon)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(accent)
        .frame(width: 20, height: 20)

      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.system(size: 12.5, weight: .semibold))
          .foregroundStyle(.primary)
        Text(detail)
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
    }
  }

  private var installCard: some View {
    OnboardingCard(accent: .orange) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "arrow.down.app")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.orange)
          .frame(width: 20, height: 20)

        VStack(alignment: .leading, spacing: 4) {
          Text("Lege Blitztext zuerst nach /Applications.")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.primary)
          Text(
            "Das hält Anmeldestart, spätere Updates und das Entfernen sauber auf einer einzigen App-Kopie."
          )
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 0)
      }
    }
  }
}
