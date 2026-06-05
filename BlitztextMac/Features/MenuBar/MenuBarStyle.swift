import SwiftUI

// MARK: - Mode accent color (single source of truth)

extension WorkflowType {
  /// The mode accent as a SwiftUI Color (DESIGN.md per-mode palette).
  var accentColorValue: Color {
    switch self {
    case .transcription: return .blue
    case .localTranscription: return .green
    case .textImprover: return .purple
    case .dampfAblassen: return .orange
    case .emojiText: return .cyan
    }
  }
}

// MARK: - Color-scheme-aware surface tokens

/// Static helpers that produce fills / strokes that read correctly in both
/// light and dark mode. All opacities are chosen so the tinted fills have
/// at least 3:1 contrast against a `.controlBackgroundColor` surface.
enum MenuBarTokens {
  // MARK: Card fills

  /// Neutral card fill that adapts to colorScheme.
  /// Uses `windowBackgroundColor` at a fixed alpha so the card is always
  /// legible over the popover surface, instead of `primary.opacity` which
  /// collapses to near-invisible in dark-over-bright contexts.
  static func cardFill(colorScheme: ColorScheme) -> Color {
    colorScheme == .dark
      ? Color(nsColor: .windowBackgroundColor).opacity(0.55)
      : Color(nsColor: .controlBackgroundColor).opacity(0.80)
  }

  static func cardStroke(colorScheme: ColorScheme) -> Color {
    colorScheme == .dark
      ? Color(nsColor: .separatorColor).opacity(0.55)
      : Color(nsColor: .separatorColor).opacity(0.45)
  }

  // MARK: Accent tint fills (for banners and icon tiles)

  /// Tinted fill for accent-colored cards / icon tiles.
  static func tintFill(_ accent: Color, colorScheme: ColorScheme) -> Color {
    colorScheme == .dark
      ? accent.opacity(0.18)
      : accent.opacity(0.10)
  }

  /// Tinted stroke for accent-colored cards / icon tiles.
  static func tintStroke(_ accent: Color, colorScheme: ColorScheme) -> Color {
    colorScheme == .dark
      ? accent.opacity(0.30)
      : accent.opacity(0.18)
  }

  // MARK: Header band

  /// The thin header band behind the top-bar (app name + gear).
  /// Forces an opaque backstop so text is never transparent-washed.
  static func headerBand(colorScheme: ColorScheme) -> Color {
    colorScheme == .dark
      ? Color(nsColor: .windowBackgroundColor).opacity(0.85)
      : Color(nsColor: .controlBackgroundColor).opacity(0.95)
  }
}

// MARK: - Blitztext Surface modifier

/// Opaque backstop for the popover content area.
/// macOS 26+: `.glassEffect` on a rectangle (mirrors PillGlassModifier's approach).
/// macOS 14–25: `.regularMaterial` + a `windowBackgroundColor` underlay so the
/// translucent material has a solid colour to blend against — eliminates the
/// "washed-out in dark mode over a bright window" symptom.
struct BlitztextSurface: ViewModifier {
  func body(content: Content) -> some View {
    if #available(macOS 26.0, *) {
      content
        .glassEffect(.regular, in: .rect)
    } else {
      // Material in FRONT, opaque window color BEHIND it to blend against (each successive
      // `.background` sits further back). Reversed order would hide the material entirely.
      content
        .background(.regularMaterial)
        .background(Color(nsColor: .windowBackgroundColor))
    }
  }
}

extension View {
  /// Applies the popover's opaque surface backstop.
  func blitztextSurface() -> some View {
    modifier(BlitztextSurface())
  }
}
