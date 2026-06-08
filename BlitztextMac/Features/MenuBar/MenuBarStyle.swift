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

  // MARK: Keycap tokens (for HotkeyBadge)
  //
  // Centralises the 8 inline color literals that were previously scattered across
  // HotkeyBadge's four private computed vars. LiquidGlass.liquidGlassKeycap() uses
  // these on the macOS 14–25 fallback path.

  /// Keycap background fill — replaces `keyBackgroundColor` in HotkeyBadge.
  static func keycapFill(colorScheme: ColorScheme) -> Color {
    colorScheme == .dark
      ? Color.white.opacity(0.12)
      : Color.black.opacity(0.09)
  }

  /// Keycap border stroke — replaces `keyStrokeColor` in HotkeyBadge.
  static func keycapStroke(colorScheme: ColorScheme) -> Color {
    colorScheme == .dark
      ? Color.white.opacity(0.20)
      : Color.black.opacity(0.16)
  }

  /// Keycap label foreground — replaces `keyTextColor` in HotkeyBadge.
  static func keycapText(colorScheme: ColorScheme) -> Color {
    colorScheme == .dark
      ? Color.white.opacity(0.84)
      : Color.black.opacity(0.72)
  }
}
