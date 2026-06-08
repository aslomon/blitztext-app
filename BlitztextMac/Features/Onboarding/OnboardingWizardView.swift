import SwiftUI

/// Root of the first-run wizard hosted in its own window. The wizard is a setup journey: each step
/// has one decision/status, visible buttons, and compact progress.
struct OnboardingWizardView: View {
  @Bindable var appState: AppState
  @State private var viewModel: OnboardingViewModel

  /// Closes the wizard window (the "Später" link and the red close button share this path).
  let onClose: () -> Void
  /// Finishes onboarding, closes the window, and opens the popover settings.
  let onOpenSettings: () -> Void

  init(appState: AppState, onClose: @escaping () -> Void, onOpenSettings: @escaping () -> Void) {
    self.appState = appState
    self.onClose = onClose
    self.onOpenSettings = onOpenSettings
    _viewModel = State(initialValue: OnboardingViewModel(appState: appState))
  }

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()

      ScrollView {
        stepBody
          .padding(20)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      Divider()
      footer
    }
    .frame(minWidth: 600, minHeight: 540)
    .animation(.easeInOut(duration: 0.18), value: viewModel.step)
  }

  // MARK: - Header

  private var header: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .center) {
        Text("Blitztext einrichten")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.primary)
        Spacer()
        BlitzStatusPill(
          state: viewModel.canAdvance(appState) ? .ready : .warning,
          label: "Schritt \(viewModel.step.displayIndex)/\(OnboardingViewModel.stepCount)"
        )
      }

      HStack(spacing: 5) {
        ForEach(OnboardingViewModel.OnboardingStep.allCases) { step in
          stepIndicator(step)
        }
      }
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 12)
  }

  private func stepIndicator(_ step: OnboardingViewModel.OnboardingStep) -> some View {
    let isSelected = step == viewModel.step
    let isPast = step.rawValue < viewModel.step.rawValue
    let tint = isSelected || isPast ? step.accent : Color.secondary

    return HStack(spacing: 4) {
      Image(systemName: isPast ? "checkmark" : step.systemImage)
        .font(.system(size: 8.5, weight: .bold))
      if isSelected {
        Text(step.title)
          .font(.system(size: 10, weight: .semibold))
      }
    }
    .foregroundStyle(tint)
    .padding(.horizontal, isSelected ? 8 : 6)
    .padding(.vertical, 4)
    .background(
      Capsule(style: .continuous)
        .fill(tint.opacity(isSelected ? 0.12 : 0.06))
    )
    .overlay(
      Capsule(style: .continuous)
        .strokeBorder(tint.opacity(0.18), lineWidth: 0.5)
    )
  }

  // MARK: - Step body

  @ViewBuilder
  private var stepBody: some View {
    switch viewModel.step {
    case .welcome:
      WelcomeStepView()
    case .installLocation:
      InstallLocationStepView()
    case .permissions:
      PermissionsStepView(appState: appState)
    case .processing:
      ProcessingStepView(appState: appState)
    case .models:
      ModelsStepView(appState: appState)
    case .modes:
      ModesStepView(appState: appState, viewModel: viewModel)
    case .finish:
      FinishStepView(appState: appState, onOpenSettings: openSettings)
    }
  }

  // MARK: - Footer

  private var footer: some View {
    HStack(spacing: 12) {
      if !viewModel.isFirstStep {
        Button {
          back()
        } label: {
          Label("Zurück", systemImage: "chevron.left")
        }
        .buttonStyle(PopoverActionButtonStyle(.secondary))
          .font(.system(size: 12, weight: .medium))
      }

      Spacer()

      Button("Später") { onClose() }
        .buttonStyle(PopoverActionButtonStyle(.quiet))
        .font(.system(size: 11.5))
        .keyboardShortcut(.cancelAction)

      primaryButton
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 12)
  }

  private var primaryButton: some View {
    Button {
      primaryAction()
    } label: {
      Text(viewModel.step.primaryActionLabel)
        .font(.system(size: 12.5, weight: .semibold))
    }
    .buttonStyle(PopoverActionButtonStyle(.primary))
    .disabled(!viewModel.canAdvance(appState))
    .modifier(DefaultActionShortcut(isEnabled: viewModel.canAdvance(appState)))
  }

  // MARK: - Actions

  private func back() {
    viewModel.back()
  }

  private func primaryAction() {
    guard viewModel.canAdvance(appState) else { return }
    if viewModel.step == .modes {
      viewModel.persistPrompts(appState)
    }
    if viewModel.isLastStep {
      viewModel.finish(appState)
      onClose()
    } else {
      viewModel.next()
    }
  }

  private func openSettings() {
    viewModel.finish(appState)
    onOpenSettings()
  }
}

/// Binds the Return key (`.defaultAction`) to the primary footer button only while it can advance,
/// so Esc/Return never fire a disabled step transition.
private struct DefaultActionShortcut: ViewModifier {
  let isEnabled: Bool

  func body(content: Content) -> some View {
    if isEnabled {
      content.keyboardShortcut(.defaultAction)
    } else {
      content
    }
  }
}
