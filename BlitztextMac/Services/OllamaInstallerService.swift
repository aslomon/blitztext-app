import Foundation

enum OllamaInstallerService {
  enum InstallTarget: Equatable {
    case systemApplications
    case userApplications
  }

  struct InstallProgress: Sendable {
    let statusText: String
  }

  enum InstallError: LocalizedError, Equatable {
    case unsupportedMacOS
    case downloadFailed
    case unzipFailed
    case archiveMissingApp
    case installFailed
    case startFailed
    case startupTimedOut

    var errorDescription: String? {
      switch self {
      case .unsupportedMacOS:
        return "Ollama benötigt macOS 14 Sonoma oder neuer."
      case .downloadFailed:
        return "Ollama konnte nicht geladen werden. Prüfe deine Internetverbindung."
      case .unzipFailed:
        return "Der Ollama-Download konnte nicht entpackt werden."
      case .archiveMissingApp:
        return "Der Ollama-Download enthielt keine App."
      case .installFailed:
        return "Ollama konnte nicht installiert werden."
      case .startFailed:
        return "Ollama konnte nicht gestartet werden."
      case .startupTimedOut:
        return "Ollama wurde gestartet, antwortet aber noch nicht."
      }
    }
  }

  static let downloadURL = URL(string: "https://ollama.com/download/Ollama-darwin.zip")!

  static func knownAppURLs(
    homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser
  ) -> [URL] {
    [
      URL(fileURLWithPath: "/Applications/Ollama.app"),
      homeDirectoryURL.appendingPathComponent("Applications/Ollama.app", isDirectory: true),
    ]
  }

  static func installedAppURL(
    candidates: [URL] = knownAppURLs(),
    fileExists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }
  ) -> URL? {
    candidates.first(where: fileExists)
  }

  static func preferredInstallTarget(systemApplicationsWritable: Bool) -> InstallTarget {
    systemApplicationsWritable ? .systemApplications : .userApplications
  }

  static func appURL(for target: InstallTarget) -> URL {
    switch target {
    case .systemApplications:
      return URL(fileURLWithPath: "/Applications/Ollama.app")
    case .userApplications:
      return FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Applications/Ollama.app", isDirectory: true)
    }
  }

  static func installAndStart(
    onProgress: @escaping @Sendable (InstallProgress) -> Void
  ) async throws -> URL {
    guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 14 else {
      throw InstallError.unsupportedMacOS
    }

    onProgress(.init(statusText: "Ollama wird geladen …"))
    let archiveURL = try await downloadArchive()
    defer { try? FileManager.default.removeItem(at: archiveURL) }

    onProgress(.init(statusText: "Ollama wird vorbereitet …"))
    let extractedAppURL = try await extractAppDetached(from: archiveURL)

    onProgress(.init(statusText: "Ollama wird installiert …"))
    let destinationURL = try await installAppDetached(from: extractedAppURL)

    onProgress(.init(statusText: "Ollama wird gestartet …"))
    try await startDetached(at: destinationURL)
    try await waitForServer()
    return destinationURL
  }

  static func startInstalledApp() async throws -> URL {
    guard let appURL = installedAppURL() else {
      throw InstallError.archiveMissingApp
    }
    try await startDetached(at: appURL)
    try await waitForServer()
    return appURL
  }

  private static func downloadArchive() async throws -> URL {
    do {
      let (temporaryURL, response) = try await URLSession.shared.download(from: downloadURL)
      guard (response as? HTTPURLResponse)?.statusCode == 200 else {
        throw InstallError.downloadFailed
      }
      let archiveURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("Ollama-darwin-\(UUID().uuidString).zip")
      try FileManager.default.moveItem(at: temporaryURL, to: archiveURL)
      return archiveURL
    } catch let error as InstallError {
      throw error
    } catch {
      throw InstallError.downloadFailed
    }
  }

  private static func extractAppDetached(from archiveURL: URL) async throws -> URL {
    try await Task.detached {
      try extractApp(from: archiveURL)
    }.value
  }

  private static func extractApp(from archiveURL: URL) throws -> URL {
    let extractionURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("Ollama-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: extractionURL, withIntermediateDirectories: true)

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
    process.arguments = ["-q", archiveURL.path, "-d", extractionURL.path]
    try run(process: process, failure: .unzipFailed)

    let appURL = extractionURL.appendingPathComponent("Ollama.app", isDirectory: true)
    guard FileManager.default.fileExists(atPath: appURL.path) else {
      throw InstallError.archiveMissingApp
    }
    return appURL
  }

  private static func installApp(from sourceURL: URL) throws -> URL {
    let target = preferredInstallTarget(
      systemApplicationsWritable: FileManager.default.isWritableFile(atPath: "/Applications")
    )
    let destinationURL = appURL(for: target)
    do {
      try FileManager.default.createDirectory(
        at: destinationURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      if FileManager.default.fileExists(atPath: destinationURL.path) {
        try FileManager.default.removeItem(at: destinationURL)
      }
      try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
      try? FileManager.default.removeItem(at: sourceURL.deletingLastPathComponent())
      return destinationURL
    } catch {
      throw InstallError.installFailed
    }
  }

  private static func installAppDetached(from sourceURL: URL) async throws -> URL {
    try await Task.detached {
      try installApp(from: sourceURL)
    }.value
  }

  private static func start(at appURL: URL) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = [appURL.path, "--args", "hidden"]
    try run(process: process, failure: .startFailed)
  }

  private static func startDetached(at appURL: URL) async throws {
    try await Task.detached {
      try start(at: appURL)
    }.value
  }

  private static func waitForServer() async throws {
    for _ in 0..<30 {
      if await OllamaService.statusCheck() {
        return
      }
      try await Task.sleep(nanoseconds: 700_000_000)
    }
    throw InstallError.startupTimedOut
  }

  private static func run(process: Process, failure: InstallError) throws {
    do {
      try process.run()
      process.waitUntilExit()
      guard process.terminationStatus == 0 else { throw failure }
    } catch let error as InstallError {
      throw error
    } catch {
      throw failure
    }
  }
}
