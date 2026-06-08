import XCTest

@testable import Blitztext

final class OllamaInstallerTests: XCTestCase {
  func testKnownInstallLocationsPreferSystemApplications() {
    let urls = OllamaInstallerService.knownAppURLs(
      homeDirectoryURL: URL(fileURLWithPath: "/Users/tester", isDirectory: true))

    XCTAssertEqual(urls.map(\.path), [
      "/Applications/Ollama.app",
      "/Users/tester/Applications/Ollama.app",
    ])
  }

  func testInstalledAppURLUsesFirstExistingLocation() {
    let urls = [
      URL(fileURLWithPath: "/Applications/Ollama.app"),
      URL(fileURLWithPath: "/Users/tester/Applications/Ollama.app"),
    ]

    let installed = OllamaInstallerService.installedAppURL(
      candidates: urls,
      fileExists: { $0.path.hasPrefix("/Users/tester") }
    )

    XCTAssertEqual(installed?.path, "/Users/tester/Applications/Ollama.app")
  }

  func testPreferredInstallTargetFallsBackToUserApplications() {
    XCTAssertEqual(
      OllamaInstallerService.preferredInstallTarget(systemApplicationsWritable: true),
      .systemApplications
    )
    XCTAssertEqual(
      OllamaInstallerService.preferredInstallTarget(systemApplicationsWritable: false),
      .userApplications
    )
  }

  func testInstallerErrorsHaveActionableGermanDescriptions() {
    XCTAssertEqual(
      OllamaInstallerService.InstallError.unsupportedMacOS.errorDescription,
      "Ollama benötigt macOS 14 Sonoma oder neuer."
    )
    XCTAssertEqual(
      OllamaInstallerService.InstallError.archiveMissingApp.errorDescription,
      "Der Ollama-Download enthielt keine App."
    )
  }
}
