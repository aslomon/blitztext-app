import AppKit
import SwiftUI

/// The "Lokale Modelle" management page: shows this Mac's capabilities, a hardware-based
/// recommendation, the models already pulled into Ollama (with real on-disk sizes), and the
/// downloadable catalog with live progress. Hosted in its own window by `LocalModelsWindowController`.
struct LocalModelsView: View {
  @Bindable var appState: AppState
  @Bindable var manager: LocalModelManager
  @Environment(\.colorScheme) private var colorScheme
  @State private var customTag = ""
  @State private var pendingSelectionTag: String?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        header
        systemCard
        if !manager.serverReachable { serverDownBanner }
        if let recommended = manager.recommended { recommendationCard(recommended) }
        if !manager.installed.isEmpty { installedSection }
        catalogSection
        customSection
        if let error = manager.lastError { errorBanner(error) }
        footerHint
      }
      .padding(16)
    }
    .frame(minWidth: 540, minHeight: 580)
    .task { await manager.refresh() }
    .onChange(of: manager.installed) { _, _ in
      selectPendingModelIfInstalled()
    }
  }

  // MARK: - Header

  private var header: some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 2) {
        Text("Lokale Modelle")
          .font(.system(size: 16, weight: .semibold))
        Text("Laden, entfernen und aktives Umschreibmodell wählen.")
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
      }
      Spacer()
      activeModelPill
      Button {
        Task { await manager.refresh() }
      } label: {
        Label("Aktualisieren", systemImage: "arrow.clockwise")
          .font(.system(size: 11, weight: .medium))
      }
      .buttonStyle(PopoverActionButtonStyle(.secondary))
      .disabled(manager.isRefreshing)
    }
  }

  @ViewBuilder
  private var activeModelPill: some View {
    if let activeModel {
      BlitzStatusPill(state: .ready, label: activeModel.name)
    } else {
      BlitzStatusPill(state: .warning, label: "Kein Modell")
    }
  }

  // MARK: - System card

  private var systemCard: some View {
    HStack(spacing: 18) {
      systemStat("cpu", "Chip", manager.system.chipName)
      systemStat("memorychip", "Arbeitsspeicher", manager.system.formattedRAM)
      systemStat("internaldrive", "Frei auf Disk", manager.system.formattedFreeDisk)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 10).fill(MenuBarTokens.cardFill(colorScheme: colorScheme))
    )
  }

  private func systemStat(_ symbol: String, _ caption: String, _ value: String) -> some View {
    HStack(spacing: 8) {
      Image(systemName: symbol)
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(.secondary)
      VStack(alignment: .leading, spacing: 1) {
        Text(caption).font(.system(size: 9.5)).foregroundStyle(.secondary)
        Text(value).font(.system(size: 12, weight: .semibold))
      }
    }
  }

  // MARK: - Recommendation

  private func recommendationCard(_ model: OllamaModelCatalog.Model) -> some View {
    let installed = manager.isInstalled(model.tag)
    let pulling = manager.isPulling(model.tag)
    return VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 6) {
        Image(systemName: "sparkles").font(.system(size: 11, weight: .semibold))
        Text("Empfohlen für deinen Mac").font(.system(size: 11, weight: .semibold))
      }
      .foregroundStyle(.blue)

      Text(model.displayName).font(.system(size: 14, weight: .semibold))
      Text(manager.system.recommendationReason(for: model))
        .font(.system(size: 11)).foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      HStack(spacing: 8) {
        Text("ca. \(SystemCapabilities.formatGB(model.downloadGB)) Download")
          .font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
        if installed {
          if isActive(tag: model.tag) {
            BlitzStatusPill(state: .ready, label: "Aktiv")
          } else {
            Button {
              selectInstalledModel(for: model.tag)
            } label: {
              Label("Nutzen", systemImage: "checkmark.circle")
            }
            .buttonStyle(PopoverActionButtonStyle(.primary))
          }
        } else if pulling {
          Label("Wird geladen …", systemImage: "arrow.down.circle")
            .font(.system(size: 10.5, weight: .medium)).foregroundStyle(.blue)
        } else {
          Button {
            pullAndUse(model.tag)
          } label: {
            Label(loadButtonTitle, systemImage: "arrow.down.circle.fill")
              .font(.system(size: 11.5, weight: .semibold))
          }
          .buttonStyle(PopoverActionButtonStyle(.primary))
          .disabled(
            manager.isPreparingOllama || !manager.system.diskFits(downloadGB: model.downloadGB))
        }
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 10)
        .fill(MenuBarTokens.tintFill(.blue, colorScheme: colorScheme))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .strokeBorder(MenuBarTokens.tintStroke(.blue, colorScheme: colorScheme), lineWidth: 0.5)
    )
  }

  // MARK: - Installed

  private var installedSection: some View {
    let totalGB = manager.installed.reduce(0.0) { $0 + $1.sizeGB }
    return VStack(alignment: .leading, spacing: 8) {
      SectionLabel(
        text:
          "Installiert (\(manager.installed.count) · \(SystemCapabilities.formatGB(totalGB)))")
      ForEach(manager.installed) { record in
        installedRow(record)
      }
    }
  }

  private func installedRow(_ record: OllamaService.InstalledModel) -> some View {
    HStack(spacing: 10) {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 13)).foregroundStyle(.green)
      VStack(alignment: .leading, spacing: 1) {
        Text(record.name).font(.system(size: 12, weight: .semibold))
        if let params = record.parameterSize {
          Text([params, record.quantization].compactMap { $0 }.joined(separator: " · "))
            .font(.system(size: 10)).foregroundStyle(.secondary)
        }
      }
      Spacer()
      if isActive(record: record) {
        BlitzStatusPill(state: .ready, label: "Aktiv")
      } else {
        Button {
          select(record)
        } label: {
          Label("Nutzen", systemImage: "checkmark.circle")
        }
        .buttonStyle(PopoverActionButtonStyle(.primary))
      }
      Text(SystemCapabilities.formatGB(record.sizeGB))
        .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
      DeleteModelButton(
        displayName: record.name,
        deleteTag: record.name,
        freedSizeGB: record.sizeGB,
        manager: manager
      )
    }
    .padding(10)
    .background(
      RoundedRectangle(cornerRadius: 8).fill(MenuBarTokens.cardFill(colorScheme: colorScheme))
    )
  }

  // MARK: - Catalog

  private var catalogSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      SectionLabel(text: "Verfügbare Modelle")
      ForEach(OllamaModelCatalog.models) { model in
        LocalModelRowView(
          model: model,
          manager: manager,
          isActive: isActive(tag: model.tag),
          onUseInstalled: { selectInstalledModel(for: model.tag) },
          onPullAndUse: { pullAndUse(model.tag) }
        )
      }
    }
  }

  // MARK: - Custom tag

  private var customSection: some View {
    VStack(alignment: .leading, spacing: 6) {
      SectionLabel(text: "Anderes Modell laden")
      HStack(spacing: 8) {
        TextField("z. B. llama3.1:70b", text: $customTag)
          .textFieldStyle(.roundedBorder)
          .font(.system(size: 11.5))
          .onSubmit(loadCustom)
        Button(loadButtonTitle, action: loadCustom)
          .buttonStyle(PopoverActionButtonStyle(.primary))
          .font(.system(size: 11.5, weight: .semibold))
          .disabled(
            customTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              || manager.isPreparingOllama)
      }
      Text("Beliebiger Ollama-Tag von ollama.com/library.")
        .font(.system(size: 10)).foregroundStyle(.secondary)
    }
  }

  private func loadCustom() {
    let tag = customTag.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !tag.isEmpty else { return }
    pullAndUse(tag)
    customTag = ""
  }

  // MARK: - Active selection

  private var activeModel: OllamaService.InstalledModel? {
    let selected = appState.appSettings.selectedLocalLLMModelName.trimmingCharacters(
      in: .whitespacesAndNewlines)
    guard !selected.isEmpty else { return nil }
    return manager.installed.first { OllamaService.isInstalled(selected, in: [$0.name]) }
  }

  private func isActive(record: OllamaService.InstalledModel) -> Bool {
    activeModel?.id == record.id
  }

  private func isActive(tag: String) -> Bool {
    guard let activeModel else { return false }
    return OllamaService.isInstalled(tag, in: [activeModel.name])
  }

  private func select(_ record: OllamaService.InstalledModel) {
    appState.appSettings.selectedLocalLLMModelName = record.name
  }

  private func selectInstalledModel(for tag: String) {
    guard let record = manager.installed.first(where: { OllamaService.isInstalled(tag, in: [$0.name]) })
    else { return }
    select(record)
  }

  private func pullAndUse(_ tag: String) {
    pendingSelectionTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
    manager.prepareOllamaAndPull(tag)
    selectPendingModelIfInstalled()
  }

  private func selectPendingModelIfInstalled() {
    guard let pendingSelectionTag else { return }
    guard
      let record = manager.installed.first(where: {
        OllamaService.isInstalled(pendingSelectionTag, in: [$0.name])
      })
    else { return }
    select(record)
    self.pendingSelectionTag = nil
  }

  // MARK: - Banners

  private var serverDownBanner: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Ollama läuft gerade nicht", systemImage: "exclamationmark.triangle.fill")
        .font(.system(size: 12, weight: .semibold)).foregroundStyle(.orange)
      Text(
        manager.ollamaAppInstalled
          ? "Starte die Ollama-App, dann kannst du Modelle direkt hier laden."
          : "Blitztext kann Ollama laden, installieren und danach das Modell installieren."
      )
      .font(.system(size: 11)).foregroundStyle(.secondary)
      if let installState = manager.ollamaInstallState {
        HStack(spacing: 8) {
          ProgressView().controlSize(.small)
          Text(installState.statusText)
            .font(.system(size: 10.5))
            .foregroundStyle(.secondary)
        }
      }
      HStack(spacing: 8) {
        if manager.ollamaAppInstalled {
          Button("Ollama starten") { manager.prepareOllama() }
            .buttonStyle(PopoverActionButtonStyle(.warning)).font(.system(size: 11.5, weight: .semibold))
            .disabled(manager.isPreparingOllama)
        } else {
          Button("Ollama installieren") {
            manager.prepareOllama()
          }
          .buttonStyle(PopoverActionButtonStyle(.warning)).font(.system(size: 11.5, weight: .semibold))
          .disabled(manager.isPreparingOllama)
        }
        Button("Download-Seite") { openOllamaDownloadPage() }
          .buttonStyle(PopoverActionButtonStyle(.secondary)).font(.system(size: 11))
        Button("Erneut prüfen") { Task { await manager.refresh() } }
          .buttonStyle(PopoverActionButtonStyle(.secondary)).font(.system(size: 11))
          .disabled(manager.isRefreshing || manager.isPreparingOllama)
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.10)))
  }

  private func errorBanner(_ message: String) -> some View {
    Text(message)
      .font(.system(size: 11)).foregroundStyle(.red)
      .padding(10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.08)))
  }

  private var footerHint: some View {
    Text(
      "Modelle werden über deine lokale Ollama-Installation geladen und geteilt. "
        + "Nichts verlässt deinen Mac. Abgebrochene Downloads bleiben erhalten und werden "
        + "beim erneuten Laden fortgesetzt."
    )
    .font(.system(size: 10.5)).foregroundStyle(.secondary)
  }

  private func openOllamaDownloadPage() {
    guard let url = URL(string: "https://ollama.com/download") else { return }
    NSWorkspace.shared.open(url)
  }

  private var loadButtonTitle: String {
    if manager.serverReachable { return "Laden & nutzen" }
    return manager.ollamaAppInstalled ? "Starten & nutzen" : "Installieren & nutzen"
  }
}
