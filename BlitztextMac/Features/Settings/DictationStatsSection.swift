import SwiftUI

/// "Deine Diktate" (R2-FT-stats): a compact, engaging summary of the EXISTING archive — runs,
/// dictated words, an estimate of the typing time saved and the total recording time, plus a
/// per-mode mini-breakdown. Read-only over `AppState.dictationStats`; no new capture, no privacy
/// cost. Reuses `SettingsSection`, `MenuBarTokens` and the DESIGN.md type styles.
struct DictationStatsSection: View {
  @Bindable var appState: AppState

  @Environment(\.colorScheme) private var colorScheme

  private var stats: DictationStats { appState.dictationStats }

  var body: some View {
    SettingsSection(
      "Deine Diktate",
      caption: "Aus dem lokalen Archiv berechnet. Keine neue Aufzeichnung, kein Datenfluss."
    ) {
      if stats.isEmpty {
        emptyState
      } else {
        VStack(alignment: .leading, spacing: 12) {
          statTiles
          if !stats.perMode.isEmpty {
            modeBreakdown
          }
        }
      }
    }
  }

  // MARK: - Empty state

  private var emptyState: some View {
    Text("Noch keine Diktate aufgezeichnet — aktiviere das Archiv.")
      .font(.system(size: 11))
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
  }

  // MARK: - Stat tiles

  /// 2×2 grid rather than a single 4-wide `HStack`: at the archive window's narrow min width the
  /// four icon+caption+value tiles would clip. The grid wraps to two rows and stays scannable.
  private var statTiles: some View {
    Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 12) {
      GridRow {
        statTile("waveform", "Läufe gesamt", "\(stats.totalRuns)")
        statTile(
          "text.word.spacing", "Wörter diktiert", DictationStatsFormat.count(stats.totalWords))
      }
      GridRow {
        statTile(
          "hourglass", "Zeit gespart",
          "≈ \(DictationStatsFormat.duration(stats.estimatedTypingSecondsSaved))")
        statTile(
          "mic", "Aufnahmezeit",
          DictationStatsFormat.duration(stats.totalRecordingSeconds))
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 10)
        .fill(MenuBarTokens.cardFill(colorScheme: colorScheme))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .strokeBorder(MenuBarTokens.cardStroke(colorScheme: colorScheme), lineWidth: 0.5)
    )
  }

  /// Icon + value + caption tile, mirroring `LocalModelsView.systemStat`.
  private func statTile(_ symbol: String, _ caption: String, _ value: String) -> some View {
    HStack(spacing: 8) {
      Image(systemName: symbol)
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(.secondary)
      VStack(alignment: .leading, spacing: 1) {
        Text(caption).font(.system(size: 9.5)).foregroundStyle(.secondary)
        Text(value).font(.system(size: 12, weight: .semibold))
      }
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  // MARK: - Per-mode breakdown

  /// "E-Mail 12 · Prompt 5 · Diktat 30" — uses each mode's user-facing display name.
  private var modeBreakdown: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Nach Modus")
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(.secondary)
      Text(breakdownText)
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var breakdownText: String {
    stats.perMode
      .map { "\(appState.displayName(for: $0.mode)) \($0.runs)" }
      .joined(separator: " · ")
  }
}

// MARK: - German formatting

/// Pure, locale-pinned (German) formatting helpers for the stats view. Durations read as
/// "≈ 12 Min" / "≈ 1,5 Std" with a comma decimal; counts get a thousands grouping.
enum DictationStatsFormat {
  /// Compact German duration: seconds → "X Sek" (< 60s), "X Min" (< 60min), else "X,Y Std".
  static func duration(_ seconds: Double) -> String {
    let safe = max(seconds, 0)
    if safe < 60 {
      return "\(Int(safe.rounded())) Sek"
    }
    let minutes = safe / 60
    if minutes < 60 {
      return "\(Int(minutes.rounded())) Min"
    }
    let hours = minutes / 60
    return "\(decimal(hours)) Std"
  }

  /// Thousands-grouped count in German locale (e.g. 1234 → "1.234").
  static func count(_ value: Int) -> String {
    countFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
  }

  /// One-decimal German number with a comma separator, trailing ",0" trimmed (1.5 → "1,5", 2 → "2").
  private static func decimal(_ value: Double) -> String {
    decimalFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
  }

  private static let countFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: "de_DE")
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 0
    return formatter
  }()

  private static let decimalFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: "de_DE")
    formatter.numberStyle = .decimal
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = 1
    return formatter
  }()
}
