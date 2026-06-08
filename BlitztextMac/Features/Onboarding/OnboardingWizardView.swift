import SwiftUI

/// Root of the first-run wizard hosted in its own window. The wizard is a setup journey: each step
/// has one decision/status, visible buttons, and compact progress.
struct OnboardingWizardView: View {
  @Bindable var appState: AppState
  @State private var viewModel: OnboardingViewModel
  /// Tracks direction for asymmetric push transitions.
  @State private var navigatingForward = true

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
          // Asymmetric directional push transition (change 5)
          .transition(
            .asymmetric(
              insertion: .push(from: navigatingForward ? .trailing : .leading),
              removal: .push(from: navigatingForward ? .leading : .trailing)
            )
          )
      }

      Divider()
      footer
    }
    .frame(minWidth: 600, minHeight: 540)
    // Replaced .easeInOut(duration: 0.18) with spring (change 5)
    .animation(.spring(response: 0.32, dampingFraction: 0.82), value: viewModel.step)
    // Glass backdrop for the entire wizard window (change 1)
    .blitztextSurface()
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

      // Segmented linear progress track (change 2)
      stepProgressTrack
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 12)
  }

  /// A fixed-height segmented track: filled segments for past/active steps, faint for upcoming.
  /// Height 3pt, corner radius 1.5pt — replaces the 8-capsule chip strip (change 2).
  private var stepProgressTrack: some View {
    HStack(spacing: 3) {
      ForEach(OnboardingViewModel.OnboardingStep.allCases) { step in
        let isActive = step == viewModel.step
        let isPast = step.rawValue < viewModel.step.rawValue
        let filled = isActive || isPast
        let tint = isActive ? viewModel.step.accent : (isPast ? step.accent : Color.secondary)

        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
          .fill(filled ? tint : Color.secondary.opacity(0.15))
          .frame(height: 3)
          .animation(.easeInOut(duration: 0.22), value: viewModel.step)
      }
    }
  }

  // MARK: - Step body

  @ViewBuilder
  private var stepBody: some View {
    switch viewModel.step {
    case .welcome:
      WelcomeStepView()
    case .identity:
      IdentityStepView(appState: appState)
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

      if viewModel.isLastStep {
        // On the Finish step: replace 'Später' with 'Zu den Einstellungen' (change 4)
        Button("Zu den Einstellungen") { openSettings() }
          .buttonStyle(PopoverActionButtonStyle(.secondary))
          .font(.system(size: 11.5))
      } else {
        // On all other steps: keep 'Später' but remove .cancelAction shortcut (change 3)
        Button("Später") { onClose() }
          .buttonStyle(PopoverActionButtonStyle(.quiet))
          .font(.system(size: 11.5))
        // Note: .keyboardShortcut(.cancelAction) intentionally removed so Esc does not
        // close the wizard while a TextField is focused on the Identity step.
      }

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
    navigatingForward = false  // set direction before triggering step change (change 5)
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
      navigatingForward = true  // set direction before triggering step change (change 5)
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
