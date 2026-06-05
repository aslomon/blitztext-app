import Observation
import SwiftUI

/// Drives the 6-step first-run wizard. Owns the step cursor, the per-step advance gating, and the
/// editable example-prompt drafts that get persisted into the E-Mail and Prompt modes on advance.
/// All persistence routes through `AppState` so the wizard never touches `settings.json` directly.
@Observable
@MainActor
final class OnboardingViewModel {
  enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome
    case permissions
    case processing
    case models
    case modes
    case finish

    var id: Int { rawValue }

    /// 1-based position for the "Schritt n von 6" indicator.
    var displayIndex: Int { rawValue + 1 }
  }

  static let stepCount = OnboardingStep.allCases.count

  var step: OnboardingStep = .welcome

  /// Editable drafts for the two curated example prompts, seeded from the live mode config so a
  /// returning user sees their own prompt, and a fresh user sees the `ModeDefaults` example.
  var emailPrompt: String
  var promptPrompt: String

  init(appState: AppState) {
    emailPrompt = Self.seededPrompt(for: .textImprover, appState: appState)
    promptPrompt = Self.seededPrompt(for: .dampfAblassen, appState: appState)
  }

  private static func seededPrompt(for type: WorkflowType, appState: AppState) -> String {
    let current = appState.modeConfig(for: type).rewrite.systemPrompt
      .trimmingCharacters(in: .whitespacesAndNewlines)
    if !current.isEmpty { return current }
    return ModeConfig.defaultRewrite(for: type).systemPrompt
  }

  // MARK: - Navigation

  func back() {
    guard let index = OnboardingStep.allCases.firstIndex(of: step), index > 0 else { return }
    step = OnboardingStep.allCases[index - 1]
  }

  func next() {
    guard let index = OnboardingStep.allCases.firstIndex(of: step),
      index < OnboardingStep.allCases.count - 1
    else { return }
    step = OnboardingStep.allCases[index + 1]
  }

  var isFirstStep: Bool { step == .welcome }
  var isLastStep: Bool { step == .finish }

  /// Soft gating: only the steps that would otherwise leave the app unusable block the primary
  /// button. Permissions are intentionally soft-warned (always advanceable).
  func canAdvance(_ appState: AppState) -> Bool {
    switch step {
    case .welcome, .permissions, .modes, .finish:
      return true
    case .processing:
      return appState.appSettings.secureLocalModeEnabled || KeychainService.isConfigured
    case .models:
      return appState.appSettings.secureLocalModeEnabled
        ? appState.selectedLocalModelIsInstalled
        : true
    }
  }

  // MARK: - Persistence

  /// Writes the two example-prompt drafts back into their modes. Called on every advance off the
  /// modes step and on finish so the user's edits are never lost.
  func persistPrompts(_ appState: AppState) {
    let email = emailPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
    let prompt = promptPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
    appState.updateMode(.textImprover) { $0.rewrite.systemPrompt = email }
    appState.updateMode(.dampfAblassen) { $0.rewrite.systemPrompt = prompt }
  }

  /// Resets a draft back to the curated `ModeDefaults` example (the "Beispiel wiederherstellen" link).
  func restoreExample(for type: WorkflowType) {
    let example = ModeConfig.defaultRewrite(for: type).systemPrompt
    switch type {
    case .textImprover: emailPrompt = example
    case .dampfAblassen: promptPrompt = example
    default: break
    }
  }

  /// Wizard completion: persist drafts, flip the launch-gating flag, and mark onboarding seen.
  func finish(_ appState: AppState) {
    persistPrompts(appState)
    appState.appSettings.hasCompletedOnboarding = true
    appState.markOnboardingSeen()
  }
}
