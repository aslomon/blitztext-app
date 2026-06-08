import SwiftUI

/// Shared visual helpers for the wizard steps so each step file stays small and consistent with
/// DESIGN.md (cards at `Color.primary.opacity(0.03–0.06)`, 8–10pt radii, 0.5pt hairline borders).
enum OnboardingChrome {
  static let cardCornerRadius: CGFloat = 10
  static let contentSpacing: CGFloat = 16
}

/// A neutral surface card: 10pt padding, faint fill, hairline border. Used by most step bodies.
/// macOS 26+: Liquid Glass card via `.liquidGlassCard(accent:cornerRadius:)`.
/// macOS 14–25: MenuBarTokens fill + hairline strokeBorder (change 6).
struct OnboardingCard<Content: View>: View {
  var accent: Color?
  @ViewBuilder var content: Content

  init(accent: Color? = nil, @ViewBuilder content: () -> Content) {
    self.accent = accent
    self.content = content()
  }

  var body: some View {
    content
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      // Replaces the manual RoundedRectangle.fill + overlay(strokeBorder) construction.
      // All availability gating lives inside liquidGlassCard (change 6).
      .liquidGlassCard(accent: accent, cornerRadius: OnboardingChrome.cardCornerRadius)
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
      // macOS 26+: liquidGlassCapsule for the icon circle (change 7).
      // macOS 14–25: keeps the flat accent.opacity(0.12) circle.
      iconCircle

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

  /// Icon circle: glass capsule on macOS 26+, flat tinted circle on macOS 14–25 (change 7).
  /// All availability gating lives inside `.liquidGlassCapsule` — no raw if #available here.
  @ViewBuilder
  private var iconCircle: some View {
    ZStack {
      // macOS 14–25 fallback background (the liquidGlassCapsule replaces this on 26+
      // but we still need the circle to size the ZStack correctly on the fallback path)
      Circle()
        .fill(accent.opacity(0.12))
        .frame(width: 42, height: 42)
      Image(systemName: systemImage)
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(accent)
    }
    // liquidGlassCapsule gate is inside the modifier — no raw if #available at call site (change 7)
    .liquidGlassCapsule(accent: accent)
    .frame(width: 42, height: 42)
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
    // VoiceOver reads icon + title + detail in one pass (change 8)
    .accessibilityElement(children: .combine)
  }
}
