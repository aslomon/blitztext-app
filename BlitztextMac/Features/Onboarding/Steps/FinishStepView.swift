import SwiftUI

/// Step 6: a recap of what got configured, plus a secondary jump into the full settings. The
/// primary "Fertig" lives in the shared footer and calls `viewModel.finish`.
struct FinishStepView: View {
  @Bindable var appState: AppState
  /// Invoked by "Zu den Einstellungen": finishes onboarding, closes the wizard, opens the popover
  /// settings. Wired by the wizard root so this step stays free of window/notification plumbing.
  let onOpenSettings: () -> Void

  private var micGranted: Bool { MicrophonePermissionService.currentStatus.isGranted }

  var body: some View {
    VStack(alignment: .leading, spacing: OnboardingChrome.contentSpacing) {
      HStack(spacing: 12) {
        ZStack {
          Circle()
            .fill(Color.green.opacity(0.12))
            .frame(width: 44, height: 44)
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 24))
            .foregroundStyle(.green)
        }
        VStack(alignment: .leading, spacing: 3) {
          Text("Fast geschafft")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.primary)
          Text("Hier ist deine Einrichtung im Überblick. Mit „Fertig“ legst du los.")
            .font(.system(size: 11.5))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 0)
      }

      OnboardingCard {
        VStack(alignment: .leading, spacing: 10) {
          OnboardingRecapRow(
            title: "Mikrofon",
            detail: micGranted ? "Erlaubt" : "Noch nicht erteilt — kannst du später nachholen.",
            isPositive: micGranted)
          OnboardingRecapRow(
            title: "Bedienungshilfen",
            detail: appState.accessibilityPermissionGranted
              ? "Erkannt — direktes Einfügen ist frei." : "Noch nicht erkannt.",
            isPositive: appState.accessibilityPermissionGranted)
          OnboardingRecapRow(
            title: "Verarbeitung",
            detail: processingDetail,
            isPositive: processingReady)
          OnboardingRecapRow(
            title: "Whisper",
            detail: whisperDetail,
            isPositive: whisperReady)
          OnboardingRecapRow(
            title: "Modi",
            detail: "E-Mail, Prompt und Social mit Beispiel-Prompts vorbereitet.",
            isPositive: true)
        }
      }

      discoverCard

      Button("Zu den Einstellungen") { onOpenSettings() }
        .buttonStyle(PopoverActionButtonStyle(.secondary))
        .font(.system(size: 12, weight: .medium))
    }
  }

  /// Surfaces the optional, on-device extras a first-run user wouldn't otherwise discover, so they
  /// know these exist (all opt-in, all local).
  private var discoverCard: some View {
    OnboardingCard {
      VStack(alignment: .leading, spacing: 8) {
        Text("Außerdem dabei")
          .font(.system(size: 12, weight: .semibold))
        discoverRow(
          "archivebox",
          "Lokales Archiv & Diktier-Statistik — opt-in, alles bleibt auf deinem Mac.")
        discoverRow(
          "wand.and.stars",
          "Lernt aus deinen Korrekturen und schlägt feste Wörterbuch-Wörter vor.")
        discoverRow(
          "speaker.wave.2",
          "Optionale Töne bei Start, Fertig und Fehler — fürs Diktieren ohne Hinsehen.")
      }
    }
  }

  private func discoverRow(_ icon: String, _ text: String) -> some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: icon)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.blue)
        .frame(width: 16)
      Text(text)
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  // MARK: - Recap derivations

  private var isLocal: Bool { appState.appSettings.secureLocalModeEnabled }

  private var processingReady: Bool {
    isLocal ? appState.selectedLocalModelIsInstalled : KeychainService.isConfigured
  }

  private var processingDetail: String {
    if isLocal {
      return "Sicherer lokaler Modus — alles bleibt auf diesem Mac."
    }
    return KeychainService.isConfigured
      ? "Online über OpenAI — API Key hinterlegt." : "Online gewählt, aber kein API Key."
  }

  private var whisperReady: Bool {
    isLocal ? appState.selectedLocalModelIsInstalled : true
  }

  private var whisperDetail: String {
    if !isLocal { return "Online über OpenAI Whisper." }
    return appState.selectedLocalModelIsInstalled
      ? "„\(appState.selectedLocalModelDisplayName)“ ist geladen."
      : "Lokales Modell fehlt noch."
  }
}
