import SwiftUI

/// One catalog model row: name, purpose, planning metadata (download size, est. RAM, fit badge),
/// and a state-aware trailing control (Laden / Fortschritt+Abbrechen / Installiert+Entfernen).
struct LocalModelRowView: View {
  let model: OllamaModelCatalog.Model
  let manager: LocalModelManager

  @Environment(\.colorScheme) private var colorScheme

  private var fit: SystemCapabilities.Fit {
    manager.system.fit(forRuntimeRAMGB: model.estimatedRuntimeRAMGB)
  }

  private var diskFits: Bool {
    manager.system.diskFits(downloadGB: model.downloadGB)
  }

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      VStack(alignment: .leading, spacing: 4) {
        Text(model.displayName)
          .font(.system(size: 12.5, weight: .semibold))

        Text(model.blurb)
          .font(.system(size: 10.5))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        metaRow
      }

      Spacer(minLength: 8)

      trailingControl
        .frame(width: 116, alignment: .trailing)
    }
    .padding(10)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(MenuBarTokens.cardFill(colorScheme: colorScheme))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .strokeBorder(MenuBarTokens.cardStroke(colorScheme: colorScheme), lineWidth: 0.5)
    )
  }

  // MARK: - Meta (size · RAM · fit)

  private var metaRow: some View {
    HStack(spacing: 8) {
      metaLabel("internaldrive", "ca. \(SystemCapabilities.formatGB(model.downloadGB))")
      metaLabel("memorychip", "~\(SystemCapabilities.formatGB(model.estimatedRuntimeRAMGB)) RAM")
      fitBadge
    }
  }

  private func metaLabel(_ symbol: String, _ text: String) -> some View {
    HStack(spacing: 3) {
      Image(systemName: symbol).font(.system(size: 9))
      Text(text).font(.system(size: 10, weight: .medium))
    }
    .foregroundStyle(.secondary)
  }

  private var fitBadge: some View {
    let (text, color): (String, Color) = {
      switch fit {
      case .comfortable: return ("Passt locker", .green)
      case .tight: return ("Knapp", .orange)
      case .tooLarge: return ("Zu groß", .red)
      }
    }()
    return Text(text)
      .font(.system(size: 9.5, weight: .semibold))
      .foregroundStyle(color)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(Capsule().fill(color.opacity(0.12)))
  }

  // MARK: - Trailing control

  @ViewBuilder private var trailingControl: some View {
    if let pull = manager.pulls[model.tag] {
      pullingControl(pull)
    } else if manager.isInstalled(model.tag) {
      installedControl
    } else {
      loadControl
    }
  }

  private func pullingControl(_ pull: LocalModelManager.PullUIState) -> some View {
    VStack(alignment: .trailing, spacing: 4) {
      if let fraction = pull.fraction {
        ProgressView(value: fraction).frame(width: 110)
      } else {
        ProgressView().controlSize(.small)
      }
      Text(pull.statusText)
        .font(.system(size: 9.5))
        .foregroundStyle(.secondary)
        .lineLimit(1)
      Button("Abbrechen") { manager.cancelPull(model.tag) }
        .buttonStyle(.plain)
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.secondary)
        .help(
          "Abbrechen — der Teil-Download bleibt erhalten und wird beim erneuten Laden fortgesetzt.")
    }
  }

  private var installedControl: some View {
    VStack(alignment: .trailing, spacing: 4) {
      Label("Installiert", systemImage: "checkmark.circle.fill")
        .font(.system(size: 10.5, weight: .semibold))
        .foregroundStyle(.green)
      let record = manager.installedRecord(for: model.tag)
      if let record {
        Text(SystemCapabilities.formatGB(record.sizeGB) + " auf Disk")
          .font(.system(size: 9.5))
          .foregroundStyle(.secondary)
      }
      DeleteModelButton(
        displayName: model.displayName,
        deleteTag: record?.name ?? model.tag,
        freedSizeGB: record?.sizeGB,
        manager: manager
      )
    }
  }

  @ViewBuilder private var loadControl: some View {
    VStack(alignment: .trailing, spacing: 4) {
      Button {
        manager.pull(model.tag)
      } label: {
        Label("Laden", systemImage: "arrow.down.circle")
          .font(.system(size: 11.5, weight: .semibold))
      }
      .buttonStyle(.borderless)
      .disabled(!diskFits || !manager.serverReachable)

      if !diskFits {
        Text("Zu wenig Speicher")
          .font(.system(size: 9.5))
          .foregroundStyle(.red.opacity(0.85))
      }
    }
  }
}
