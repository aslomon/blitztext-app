import SwiftUI

/// Root of the first-run wizard hosted in its own window. Provides the shared chrome — title, a
/// "Schritt n von 6" indicator, the scrollable step body, and the footer (Zurück / Später / primary
/// Weiter|Fertig) — and switches over the six step subviews.
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
    .frame(minWidth: 560, minHeight: 520)
    .animation(.easeInOut(duration: 0.18), value: viewModel.step)
  }

  // MARK: - Header

  private var header: some View {
    HStack(alignment: .center) {
      Text("Blitztext einrichten")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.primary)
      Spacer()
      Text("Schritt \(viewModel.step.displayIndex) von \(OnboardingViewModel.stepCount)")
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 12)
  }

  // MARK: - Step body

  @ViewBuilder
  private var stepBody: some View {
    switch viewModel.step {
    case .welcome:
      WelcomeStepView()
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
        Button("Zurück") { back() }
          .buttonStyle(SubtleButtonStyle())
          .foregroundStyle(.secondary)
          .font(.system(size: 12, weight: .medium))
      }

      Spacer()

      Button("Später") { onClose() }
        .buttonStyle(SubtleButtonStyle())
        .foregroundStyle(.secondary)
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
      Text(viewModel.isLastStep ? "Fertig" : "Weiter")
        .font(.system(size: 12.5, weight: .semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 7)
        .background(
          RoundedRectangle(cornerRadius: 8)
            .fill(viewModel.canAdvance(appState) ? Color.accentColor : Color.secondary.opacity(0.4))
        )
    }
    .buttonStyle(SubtleButtonStyle())
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
