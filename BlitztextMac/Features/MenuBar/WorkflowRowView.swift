import SwiftUI

struct WorkflowRowView: View {
  let type: WorkflowType
  let enabled: Bool
  var customName: String? = nil
  var subtitle: String? = nil
  var hotkeyLabel: String? = nil
  let action: () -> Void

  @State private var isHovered = false
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        iconTile
        labelStack
        Spacer()
        HotkeyBadge(label: hotkeyLabel ?? type.hotkeyLabel, enabled: enabled)
          .opacity(enabled ? 1 : 0.4)
          .accessibilityHidden(true)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(rowBackground)
      .padding(.horizontal, 6)
      .contentShape(Rectangle())
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(accessibilityLabel)
      .accessibilityHint(accessibilityHint)
    }
    .buttonStyle(.plain)
    .disabled(!enabled)
    .opacity(enabled ? 1 : 0.5)
    .onHover { hovering in
      withAnimation(.easeOut(duration: 0.12)) {
        isHovered = hovering
      }
    }
  }

  // MARK: - Accessibility

  private var accessibilityLabel: String {
    "\(customName ?? type.displayName), \(subtitle ?? type.subtitle)"
  }

  private var accessibilityHint: String {
    enabled ? "Startet die Aufnahme" : "Nicht verfügbar — in Einstellungen einrichten"
  }

  // MARK: - Icon tile with per-mode accent

  private var iconTile: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 10)
        // Per-mode accent fill instead of uniform monochrome opacity.
        // Dark: ~0.18 opacity; Light: ~0.10 — legible in both modes.
        .fill(
          isHovered && enabled
            ? MenuBarTokens.tintFill(type.accentColorValue, colorScheme: colorScheme)
              .opacity(1.3)  // slightly brighter on hover
            : MenuBarTokens.tintFill(type.accentColorValue, colorScheme: colorScheme)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 10)
            .strokeBorder(
              MenuBarTokens.tintStroke(type.accentColorValue, colorScheme: colorScheme),
              lineWidth: 0.5
            )
        )
        .frame(width: 36, height: 36)

      Image(systemName: type.icon)
        .font(.system(size: 15, weight: .semibold))
        // Icon tinted with the mode accent instead of generic .secondary
        .foregroundStyle(type.accentColorValue)
    }
  }

  // MARK: - Name + subtitle + readiness dot

  private var labelStack: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(spacing: 5) {
        Text(customName ?? type.displayName)
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(enabled ? .primary : .secondary)
          .lineLimit(1)

        // Readiness indicator: accent dot when ready, warning icon when backend missing
        if enabled {
          Circle()
            .fill(type.accentColorValue)
            .frame(width: 5, height: 5)
            .accessibilityHidden(true)
        } else {
          Image(systemName: "exclamationmark.circle")
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.orange)
            .accessibilityHidden(true)
        }
      }

      Text(subtitle ?? type.subtitle)
        .font(.system(size: 11))
        .foregroundStyle(enabled ? Color.secondary : Color.secondary.opacity(0.6))
        .lineLimit(1)
    }
  }

  private var rowBackground: some View {
    RoundedRectangle(cornerRadius: 10)
      .fill(
        isHovered && enabled
          ? MenuBarTokens.tintFill(type.accentColorValue, colorScheme: colorScheme)
          : Color.clear
      )
  }
}

// MARK: - Hotkey Badge

struct HotkeyBadge: View {
  let label: String
  let enabled: Bool
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    HStack(spacing: 3) {
      ForEach(label.components(separatedBy: " + "), id: \.self) { key in
        Text(key)
          .font(.system(size: 10.5, weight: .semibold, design: .rounded))
          .foregroundStyle(keyTextColor)
          .padding(.horizontal, 7)
          .padding(.vertical, 4)
          .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
              .fill(keyBackgroundColor)
          )
          .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
              .strokeBorder(keyStrokeColor, lineWidth: 0.8)
          )
          .shadow(color: keyShadowColor, radius: 1.2, y: 0.6)
      }
    }
  }

  private var keyTextColor: Color {
    guard enabled else {
      return colorScheme == .dark
        ? Color.white.opacity(0.34)
        : Color.black.opacity(0.26)
    }

    return colorScheme == .dark
      ? Color.white.opacity(0.84)
      : Color.black.opacity(0.72)
  }

  private var keyBackgroundColor: Color {
    guard enabled else {
      return colorScheme == .dark
        ? Color.white.opacity(0.05)
        : Color.black.opacity(0.035)
    }

    return colorScheme == .dark
      ? Color.white.opacity(0.12)
      : Color.black.opacity(0.09)
  }

  private var keyStrokeColor: Color {
    guard enabled else {
      return colorScheme == .dark
        ? Color.white.opacity(0.08)
        : Color.black.opacity(0.06)
    }

    return colorScheme == .dark
      ? Color.white.opacity(0.20)
      : Color.black.opacity(0.16)
  }

  private var keyShadowColor: Color {
    guard enabled else { return .clear }

    return colorScheme == .dark
      ? Color.black.opacity(0.10)
      : Color.black.opacity(0.06)
  }
}
