import XCTest

@testable import Blitztext

/// Locks down the wizard's gating, prompt-draft seeding, and completion side effects. The view
/// model is the headless core of the onboarding flow, so testing it covers the wizard's behaviour
/// without driving SwiftUI. Keychain-dependent branches use injected stubs so the suite never
/// blocks on macOS security prompts.
@MainActor
final class OnboardingViewModelTests: XCTestCase {

  private func makeAppState() -> AppState {
    let state = AppState()
    // Start every case from a known, non-completed, online baseline.
    state.appSettings.hasCompletedOnboarding = false
    state.appSettings.secureLocalModeEnabled = false
    return state
  }

  // MARK: - Step shape

  func testJourneyStepsInExpectedOrder() {
    XCTAssertEqual(OnboardingViewModel.stepCount, 8)
    XCTAssertEqual(
      OnboardingViewModel.OnboardingStep.allCases,
      [.welcome, .identity, .installLocation, .permissions, .processing, .models, .modes, .finish])
    XCTAssertEqual(OnboardingViewModel.OnboardingStep.welcome.displayIndex, 1)
    XCTAssertEqual(OnboardingViewModel.OnboardingStep.finish.displayIndex, 8)
  }

  func testJourneyStepsExposeShortMetadata() {
    XCTAssertEqual(OnboardingViewModel.OnboardingStep.identity.title, "Identität")
    XCTAssertEqual(OnboardingViewModel.OnboardingStep.installLocation.title, "Speicherort")
    XCTAssertEqual(OnboardingViewModel.OnboardingStep.permissions.systemImage, "hand.raised.fill")
    XCTAssertEqual(OnboardingViewModel.OnboardingStep.processing.primaryActionLabel, "Auswahl prüfen")
    XCTAssertEqual(OnboardingViewModel.OnboardingStep.finish.primaryActionLabel, "Fertig")
  }

  // MARK: - canAdvance gating

  func testSoftStepsAlwaysAdvanceable() {
    let appState = makeAppState()
    let vm = OnboardingViewModel(appState: appState)

    for step in [
      OnboardingViewModel.OnboardingStep.welcome, .installLocation, .permissions, .modes, .finish,
    ] {
      vm.step = step
      XCTAssertTrue(vm.canAdvance(appState), "\(step) must always advance (soft gating)")
    }
  }

  func testIdentityNeedsName() {
    let appState = makeAppState()
    let vm = OnboardingViewModel(appState: appState)
    vm.step = .identity

    appState.appSettings.userDisplayName = "   "
    XCTAssertFalse(vm.canAdvance(appState))

    appState.appSettings.userDisplayName = "Jason Rinnert"
    XCTAssertTrue(vm.canAdvance(appState))
  }

  func testProcessingOnlineNeedsKey() {
    let appState = makeAppState()
    appState.appSettings.secureLocalModeEnabled = false
    let vm = OnboardingViewModel(appState: appState, isOpenAIKeyConfigured: { false })
    vm.step = .processing

    XCTAssertFalse(vm.canAdvance(appState))

    let configuredVM = OnboardingViewModel(appState: appState, isOpenAIKeyConfigured: { true })
    configuredVM.step = .processing
    XCTAssertTrue(configuredVM.canAdvance(appState))
  }

  func testProcessingLocalAdvancesWithoutKey() {
    let appState = makeAppState()
    appState.appSettings.secureLocalModeEnabled = true
    let vm = OnboardingViewModel(appState: appState)
    vm.step = .processing

    // Secure local mode never needs an OpenAI key.
    XCTAssertTrue(vm.canAdvance(appState))
  }

  func testModelsOnlineAlwaysAdvances() {
    let appState = makeAppState()
    appState.appSettings.secureLocalModeEnabled = false
    let vm = OnboardingViewModel(appState: appState)
    vm.step = .models

    // Online: a local Whisper model is optional, so the step never blocks.
    XCTAssertTrue(vm.canAdvance(appState))
  }

  func testModelsLocalNeedsInstalledModel() {
    let appState = makeAppState()
    appState.appSettings.secureLocalModeEnabled = true
    let vm = OnboardingViewModel(appState: appState)
    vm.step = .models

    // Local: advance is gated on an actually-installed model.
    XCTAssertEqual(vm.canAdvance(appState), appState.selectedLocalModelIsInstalled)
  }

  // MARK: - Navigation

  func testNextAndBackTraverseSteps() {
    let appState = makeAppState()
    let vm = OnboardingViewModel(appState: appState)

    XCTAssertTrue(vm.isFirstStep)
    vm.next()
    XCTAssertEqual(vm.step, .identity)
    vm.next()
    XCTAssertEqual(vm.step, .installLocation)
    vm.next()
    XCTAssertEqual(vm.step, .permissions)
    vm.back()
    XCTAssertEqual(vm.step, .installLocation)
    vm.back()
    XCTAssertEqual(vm.step, .identity)
    vm.back()
    XCTAssertEqual(vm.step, .welcome)
    // Back at the first step is a no-op.
    vm.back()
    XCTAssertEqual(vm.step, .welcome)

    vm.step = .finish
    XCTAssertTrue(vm.isLastStep)
    // Next at the last step is a no-op.
    vm.next()
    XCTAssertEqual(vm.step, .finish)
  }

  // MARK: - Prompt-draft seeding

  func testPromptDraftsSeededFromModeDefaultsForFreshState() {
    let appState = makeAppState()
    // Clear any persisted prompts so the fresh-user fallback to ModeDefaults is exercised.
    appState.updateMode(.textImprover) { $0.rewrite.systemPrompt = "" }
    appState.updateMode(.dampfAblassen) { $0.rewrite.systemPrompt = "" }

    let vm = OnboardingViewModel(appState: appState)
    XCTAssertEqual(vm.emailPrompt, ModeDefaults.emailSystemPrompt)
    XCTAssertEqual(vm.promptPrompt, ModeDefaults.promptCraftSystemPrompt)
  }

  func testPromptDraftsSeededFromExistingUserPrompt() {
    let appState = makeAppState()
    appState.updateMode(.textImprover) { $0.rewrite.systemPrompt = "Mein eigener Prompt" }

    let vm = OnboardingViewModel(appState: appState)
    XCTAssertEqual(vm.emailPrompt, "Mein eigener Prompt")
  }

  func testRestoreExampleResetsDraftToDefault() {
    let appState = makeAppState()
    let vm = OnboardingViewModel(appState: appState)
    vm.emailPrompt = "geändert"
    vm.restoreExample(for: .textImprover)
    XCTAssertEqual(vm.emailPrompt, ModeDefaults.emailSystemPrompt)
  }

  // MARK: - Persistence

  func testPersistPromptsWritesDraftsIntoModes() {
    let appState = makeAppState()
    let vm = OnboardingViewModel(appState: appState)
    vm.emailPrompt = "  E-Mail Prompt  "
    vm.promptPrompt = "Prompt Prompt"
    vm.persistPrompts(appState)

    XCTAssertEqual(
      appState.modeConfig(for: .textImprover).rewrite.systemPrompt, "E-Mail Prompt")
    XCTAssertEqual(
      appState.modeConfig(for: .dampfAblassen).rewrite.systemPrompt, "Prompt Prompt")
  }

  // MARK: - finish()

  func testFinishFlipsHasCompletedOnboardingAndMarksSeen() {
    let appState = makeAppState()
    XCTAssertFalse(appState.appSettings.hasCompletedOnboarding)

    let vm = OnboardingViewModel(appState: appState)
    vm.emailPrompt = "Final E-Mail"
    vm.finish(appState)

    XCTAssertTrue(appState.appSettings.hasCompletedOnboarding)
    XCTAssertTrue(appState.appSettings.hasSeenOnboarding)
    // finish also persists the current drafts.
    XCTAssertEqual(appState.modeConfig(for: .textImprover).rewrite.systemPrompt, "Final E-Mail")
  }
}
