import SwiftUI

/// Shared visual helpers for the wizard steps so each step file stays small and consistent with
/// DESIGN.md (cards at `Color.primary.opacity(0.03–0.06)`, 8–10pt radii, 0.5pt hairline borders).
enum OnboardingChrome {
  static let cardCornerRadius: CGFloat = 10
  static let contentSpacing: CGFloat = 16
}

/// A neutral surface card: 10pt padding, faint fill, hairline border. Used by most step bodies.
struct OnboardingCard<Content: View>: View {
  var accent: Color?
  @ViewBuilder var content: Content

  @Environment(\.colorScheme) private var colorScheme

  init(accent: Color? = nil, @ViewBuilder content: () -> Content) {
    self.accent = accent
    self.content = content()
  }

  private var fill: Color {
    if let accent {
      return MenuBarTokens.tintFill(accent, colorScheme: colorScheme)
    }
    return MenuBarTokens.cardFill(colorScheme: colorScheme)
  }

  private var stroke: Color {
    if let accent {
      return MenuBarTokens.tintStroke(accent, colorScheme: colorScheme)
    }
    return MenuBarTokens.cardStroke(colorScheme: colorScheme)
  }

  var body: some View {
    content
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: OnboardingChrome.cardCornerRadius)
          .fill(fill)
      )
      .overlay(
        RoundedRectangle(cornerRadius: OnboardingChrome.cardCornerRadius)
          .strokeBorder(stroke, lineWidth: 0.5)
      )
  }
}

/// A short title + supporting caption pair, the standard header for each step body.
struct OnboardingStepHeader: View {
  let systemImage: String
  let accent: Color
  let title: String
  let subtitle: String

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      ZStack {
        Circle()
          .fill(accent.opacity(0.12))
          .frame(width: 42, height: 42)
        Image(systemName: systemImage)
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(accent)
      }

      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(.primary)
        Text(subtitle)
          .font(.system(size: 11.5))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
    }
  }
}

/// A single labelled value row used by the recap list, with a green check or grey dash badge.
struct OnboardingRecapRow: View {
  let title: String
  let detail: String
  let isPositive: Bool

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: isPositive ? "checkmark.circle.fill" : "minus.circle")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(isPositive ? Color.green : Color.secondary)
        .frame(width: 18, height: 18)

      VStack(alignment: .leading, spacing: 1) {
        Text(title)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.primary)
        Text(detail)
          .font(.system(size: 10.5))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
    }
  }
}
