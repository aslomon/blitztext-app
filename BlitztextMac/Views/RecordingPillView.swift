import SwiftUI

/// A compact floating capsule shown at the top-center of the screen while a workflow records.
///
/// Idle: a static accent dot + live center-mirrored waveform.
/// Hover: morphs to expose stop (checkmark) and cancel (X) affordances.
///
/// macOS 26+: native Liquid Glass via `.glassEffect(in: .capsule)` with GlassEffectContainer
///   morphing between pill / copy-card / variant-card states using @Namespace.
/// macOS 14–25: clean Capsule + .regularMaterial + one quiet shadow. No gradients, no blends.
///
/// Hosted in a borderless non-activating NSPanel by `RecordingPillController`.
struct RecordingPillView: View {
  /// Live mic level (0...1), pushed from the controller each tick.
  var audioLevel: Float
  /// Per-mode accent color. Defaults to transcription blue.
  var accentColor: Color
  /// Recording (live waveform) / processing (working animation) / cancelled (brief red flash) /
  /// failed (red + the error message).
  var phase: PillPhase
  /// The run's error text, shown in the `.failed` state.
  var errorMessage: String?
  /// The dictated text, shown in the `.copyOnly` fallback card.
  var copyOnlyText: String?
  var pendingVariants: PendingRewriteVariants?
  /// Invoked when the user confirms (stop/checkmark).
  var onStop: () -> Void
  /// Invoked when the user cancels (X).
  var onCancel: () -> Void
  /// Invoked from the `.copyOnly` card's Copy button with the dictated text.
  var onCopy: (String) -> Void = { _ in }
  var onChooseVariant: (RewriteVariant.ID) -> Void = { _ in }
  var onCopyVariant: (RewriteVariant.ID) -> Void = { _ in }
  /// Invoked from the `.copyOnly` card's dismiss (✕).
  var onDismiss: () -> Void = {}

  @State private var isHovering = false
  /// Used for GlassEffectContainer morphing between pill / card states on macOS 26.
  @Namespace private var pillNamespace

  private let pillHeight: CGFloat = 32

  var body: some View {
    // macOS 26: wrap in GlassEffectContainerView so the glass engine can morph between states.
    // macOS 14–25: GlassEffectContainerView falls back to a plain VStack with no visual change.
    GlassEffectContainerView(spacing: 0) {
      Group {
        if phase == .failed {
          failedContent
        } else if phase == .copyOnly {
          copyOnlyContent
            .glassEffectIDIfAvailable("card", namespace: pillNamespace)
        } else if phase == .variantChoice {
          variantChoiceContent
            .glassEffectIDIfAvailable("card", namespace: pillNamespace)
        } else {
          pillContent
        }
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel(pillAccessibilityLabel)
  }

  /// Red error pill: a warning glyph + the actual message (up to 2 lines), so a failed run —
  /// most importantly an eyes-off background-hotkey run — explains itself instead of flashing
  /// silently. Uses a red-tinted capsule surface to make the error state immediately visible.
  private var failedContent: some View {
    HStack(spacing: 8) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.red)
      Text(errorMessage ?? "Fehler")
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.primary)
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 240, alignment: .leading)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 7)
    // liquidGlassCapsule(accent: .red) gives a semantic red tint on macOS 26;
    // on macOS 14–25 PillGlassModifier adds a Color.red.opacity(0.10) overlay.
    .liquidGlassCapsule(accent: .red)
  }

  /// Fallback card when auto-paste couldn't land: the dictated text in a scrollable, selectable
  /// area with a Copy button (and a ⌘V hint), so the result is never silently stuck on the
  /// clipboard.
  ///
  /// Design: three-zone card (header / body / footer) on a rounded-rect glass surface — NOT a
  /// capsule — so the expanded layout reads cleanly. The Copy action uses GlassProminentButtonStyle
  /// on macOS 26 (prominent glass CTA) and PopoverActionButtonStyle(.primary) on macOS 14–25.
  private var copyOnlyContent: some View {
    VStack(alignment: .leading, spacing: 0) {

      // ── Header ──────────────────────────────────────────────────────────
      HStack(spacing: 6) {
        Image(systemName: "clipboard")
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(accentColor)
        Text("Nicht eingefügt")
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(.primary)
        Spacer(minLength: 8)
        CopyOnlyDismissButton(action: onDismiss)
      }
      .padding(.horizontal, 12)
      .padding(.top, 11)
      .padding(.bottom, 8)

      // ── Divider ─────────────────────────────────────────────────────────
      Rectangle()
        .fill(Color.primary.opacity(0.06))
        .frame(height: 0.5)
        .padding(.horizontal, 0)

      // ── Body ────────────────────────────────────────────────────────────
      ScrollView(.vertical, showsIndicators: false) {
        Text(copyOnlyText ?? "")
          .font(.system(size: 11.5))
          .foregroundStyle(.primary)
          .textSelection(.enabled)
          .lineSpacing(2)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 12)
          .padding(.vertical, 9)
      }
      .frame(maxHeight: 140)

      // ── Divider ─────────────────────────────────────────────────────────
      Rectangle()
        .fill(Color.primary.opacity(0.06))
        .frame(height: 0.5)

      // ── Footer ──────────────────────────────────────────────────────────
      HStack(spacing: 8) {
        Button {
          onCopy(copyOnlyText ?? "")
        } label: {
          Text("Kopieren")
            .font(.system(size: 11, weight: .medium))
        }
        .buttonStyle(GlassProminentButtonStyle())
        .accessibilityLabel("Text kopieren")
        .help("Text in die Zwischenablage kopieren")

        Text("oder ⌘V")
          .font(.system(size: 10.5))
          .foregroundStyle(Color.secondary.opacity(0.75))

        Spacer(minLength: 0)
      }
      .padding(.horizontal, 12)
      .padding(.top, 8)
      .padding(.bottom, 10)
    }
    // Shared expanded-pill width constant — matches variantChoiceContent.
    .frame(width: LiquidGlass.pillExpandedWidth)
    .modifier(CardGlassModifier())
  }

  // MARK: - Layout

  private var tint: Color { phase == .cancelled ? .red : accentColor }

  /// Spoken summary of the pill's current state for VoiceOver.
  private var pillAccessibilityLabel: String {
    switch phase {
    case .failed: return "Fehler: \(errorMessage ?? "")"
    case .copyOnly: return "Konnte nicht einfügen. Text kopiert: \(copyOnlyText ?? "")"
    case .variantChoice: return "Zwei Versionen bereit. Wähle eine Version zum Einfügen."
    case .processing: return "Wird transkribiert"
    default: return "Aufnahme läuft"
    }
  }

  private var pillContent: some View {
    HStack(spacing: 8) {
      recordingDot

      if phase == .cancelled {
        Image(systemName: "xmark")
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(.red)
          .transition(.opacity)
      } else if isHovering {
        affordances
          .transition(
            .asymmetric(
              insertion: .opacity.combined(with: .scale(scale: 0.88)),
              removal: .opacity.combined(with: .scale(scale: 0.88))
            )
          )
      } else {
        PillWaveformView(
          audioLevel: phase == .processing ? 0 : audioLevel,
          accentColor: accentColor,
          isProcessing: phase == .processing
        )
        .accessibilityHidden(true)
        .transition(
          .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.92)),
            removal: .opacity.combined(with: .scale(scale: 0.92))
          )
        )
      }
    }
    .padding(.horizontal, 12)
    .frame(height: pillHeight)
    .modifier(PillGlassModifier())
    .glassEffectIDIfAvailable("pill", namespace: pillNamespace)
    .animation(.easeInOut(duration: 0.2), value: phase)
    // onHover lives here — only pillContent reads isHovering; keeping it here avoids
    // unnecessary re-evaluations of copyOnlyContent and variantChoiceContent.
    .onHover { hovering in
      withAnimation(.easeInOut(duration: 0.18)) {
        isHovering = hovering
      }
    }
    .animation(.easeInOut(duration: 0.18), value: isHovering)
  }

  // MARK: - Subviews

  /// Accent dot — turns red on cancel; gently pulses while processing to signal "working".
  private var recordingDot: some View {
    Circle()
      .fill(tint)
      .frame(width: 6, height: 6)
      .scaleEffect(phase == .processing ? 1.25 : 1.0)
      .opacity(phase == .processing ? 0.65 : 1.0)
      .animation(
        phase == .processing
          ? .easeInOut(duration: 0.7).repeatForever(autoreverses: true)
          : .default,
        value: phase
      )
      .accessibilityHidden(true)
  }

  private var affordances: some View {
    HStack(spacing: 6) {
      affordanceButton(
        systemName: "checkmark",
        tint: accentColor,
        help: "Enter = beenden",
        accessibilityLabel: "Aufnahme beenden",
        action: onStop
      )
      affordanceButton(
        systemName: "xmark",
        tint: Color.primary.opacity(0.55),
        help: "Abbrechen",
        accessibilityLabel: "Aufnahme abbrechen",
        action: onCancel
      )
    }
  }

  // MARK: - Helpers

  private func affordanceButton(
    systemName: String,
    tint: Color,
    help: String,
    accessibilityLabel: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(tint)
        .frame(width: 22, height: 22)
        .contentShape(Circle())
    }
    // GlassActionButtonStyle: .glassEffect(.regular.interactive()) on macOS 26,
    // PopoverActionButtonStyle(.primary) fallback on macOS 14–25 (via LiquidGlass.swift).
    .buttonStyle(GlassActionButtonStyle())
    .help(help)
    .accessibilityLabel(accessibilityLabel)
  }
}

// MARK: - GlassEffectID helper

/// Applies .glassEffectID only on macOS 26+; on older systems it is a no-op.
/// Keeps call sites in Views clean per the single-source-of-truth rule in LiquidGlass.swift.
extension View {
  @ViewBuilder
  fileprivate func glassEffectIDIfAvailable(_ id: String, namespace: Namespace.ID) -> some View {
    if #available(macOS 26.0, *) {
      self.glassEffectID(id, in: namespace)
    } else {
      self
    }
  }
}

// MARK: - Dismiss Button

/// Small circular dismiss (✕) used in the copyOnly card header.
/// Shows a subtle tinted background on hover so the hit target is visible without being heavy.
struct CopyOnlyDismissButton: View {
  let action: () -> Void
  @State private var isHovering = false

  var body: some View {
    Button(action: action) {
      Image(systemName: "xmark")
        .font(.system(size: 9, weight: .bold))
        .foregroundStyle(isHovering ? Color.primary.opacity(0.7) : Color.primary.opacity(0.35))
        .frame(width: 20, height: 20)
        .background(
          Circle()
            .fill(Color.primary.opacity(isHovering ? 0.1 : 0))
        )
        .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      withAnimation(.easeInOut(duration: 0.12)) {
        isHovering = hovering
      }
    }
    .accessibilityLabel("Schließen")
    .help("Schließen")
  }
}
