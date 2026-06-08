import SwiftUI

extension RecordingPillView {
  var variantChoiceContent: some View {
    VStack(alignment: .leading, spacing: 0) {

      // ── Header ──────────────────────────────────────────────────────────
      // doc.on.doc signals "alternate versions" more clearly than square.split.2x1.
      // A secondary mode-name line below the title provides one-glance context.
      HStack(spacing: 6) {
        Image(systemName: "doc.on.doc")
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(accentColor)
        VStack(alignment: .leading, spacing: 1) {
          Text("Version wählen")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.primary)
          if let modeName = pendingVariants?.mode.displayName {
            Text(modeName)
              .font(.system(size: 10, weight: .regular))
              .foregroundStyle(.secondary)
          }
        }
        Spacer(minLength: 8)
        CopyOnlyDismissButton(action: onDismiss)
      }
      .padding(.horizontal, 12)
      .padding(.top, 11)
      .padding(.bottom, 8)

      Rectangle()
        .fill(Color.primary.opacity(0.06))
        .frame(height: 0.5)

      VStack(spacing: 8) {
        ForEach(pendingVariants?.variants ?? []) { variant in
          variantCard(variant)
        }
      }
      .padding(10)
    }
    // Shared expanded-pill width constant — matches copyOnlyContent.
    .frame(width: LiquidGlass.pillExpandedWidth)
    .modifier(CardGlassModifier())
  }

  func variantCard(_ variant: RewriteVariant) -> some View {
    VStack(alignment: .leading, spacing: 7) {
      Text(variant.title)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.secondary)
      ScrollView(.vertical, showsIndicators: false) {
        Text(variant.text)
          .font(.system(size: 11.5))
          .foregroundStyle(.primary)
          .textSelection(.enabled)
          .lineSpacing(2)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .frame(maxHeight: 94)

      HStack(spacing: 8) {
        Button {
          onChooseVariant(variant.id)
        } label: {
          Text("Einfügen")
            .font(.system(size: 11, weight: .medium))
        }
        // GlassProminentButtonStyle: prominent glass CTA on macOS 26,
        // PopoverActionButtonStyle(.primary) fallback on macOS 14–25.
        .buttonStyle(GlassProminentButtonStyle())
        .accessibilityLabel("Version \(variant.title) einfügen")
        .accessibilityHint("Fügt diesen Text in die aktive App ein")

        Button {
          onCopyVariant(variant.id)
        } label: {
          Text("Kopieren")
            .font(.system(size: 11, weight: .medium))
        }
        // GlassActionButtonStyle: secondary glass on macOS 26,
        // PopoverActionButtonStyle(.primary) fallback on macOS 14–25.
        .buttonStyle(GlassActionButtonStyle())
        .accessibilityLabel("Version \(variant.title) kopieren")

        Spacer(minLength: 0)
      }
    }
    .padding(9)
    // Flat separator-level tint only — the outer CardGlassModifier provides glass depth.
    // No stacked glass layers per DESIGN.md "Glass nicht stapeln" rule.
    .background(
      Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous)
    )
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Variante: \(variant.title)")
  }
}
