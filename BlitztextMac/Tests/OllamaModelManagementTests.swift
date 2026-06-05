import XCTest

@testable import Blitztext

/// Covers the local-LLM management logic that drives the "Lokale Modelle" page:
/// the curated catalog, the hardware-based recommendation, GB formatting, fit/disk classification,
/// and pull-progress parsing. All pure logic — no live Ollama server required.
final class OllamaModelManagementTests: XCTestCase {

  // MARK: - Catalog integrity

  func testCatalogTagsAreUnique() {
    let tags = OllamaModelCatalog.models.map(\.tag)
    XCTAssertEqual(tags.count, Set(tags).count, "Catalog tags must be unique")
  }

  func testCatalogEntriesAreWellFormed() {
    for model in OllamaModelCatalog.models {
      XCTAssertFalse(model.tag.isEmpty)
      XCTAssertTrue(
        model.tag.contains(":"), "Every catalog tag should be explicit, got \(model.tag)")
      XCTAssertGreaterThan(model.downloadGB, 0, "\(model.tag) needs a positive download size")
      XCTAssertFalse(model.displayName.isEmpty)
      XCTAssertFalse(model.blurb.isEmpty)
      // Runtime RAM estimate must exceed the on-disk size (weights + overhead).
      XCTAssertGreaterThan(model.estimatedRuntimeRAMGB, model.downloadGB)
    }
  }

  func testCatalogLookupByTag() {
    XCTAssertEqual(OllamaModelCatalog.model(forTag: "gemma3:12b")?.displayName, "Gemma 3 · 12B")
    XCTAssertNil(OllamaModelCatalog.model(forTag: "does-not-exist:99b"))
  }

  // MARK: - Fit classification

  private func mac(ram: Double, disk: Double = 200, appleSilicon: Bool = true) -> SystemCapabilities
  {
    SystemCapabilities(
      totalRAMGB: ram, freeDiskGB: disk, chipName: "Test Chip", isAppleSilicon: appleSilicon)
  }

  func testFitThresholdsAppleSilicon() {
    let m = mac(ram: 48)  // comfortable ≤ 26.4, usable ≤ 33.6
    XCTAssertEqual(m.fit(forRuntimeRAMGB: 10), .comfortable)
    XCTAssertEqual(m.fit(forRuntimeRAMGB: 30), .tight)
    XCTAssertEqual(m.fit(forRuntimeRAMGB: 40), .tooLarge)
  }

  func testTotalRAMIsReportedInGiB() {
    // A Mac marketed as "48 GB" reports 51,539,607,552 bytes of physical memory.
    // 51,539,607,552 / 1024³ == 48.0 exactly; base-10 would wrongly give 51.5 → "52 GB".
    let bytes = 51_539_607_552.0
    let gib = bytes / (1024.0 * 1024.0 * 1024.0)
    XCTAssertEqual(gib, 48.0, accuracy: 0.01)
    XCTAssertEqual(SystemCapabilities.formatGB(gib), "48 GB")
  }

  func testDiskFitsLeavesMargin() {
    let m = mac(ram: 16, disk: 20)
    XCTAssertTrue(m.diskFits(downloadGB: 17))  // 17 + 2 = 19 ≤ 20
    XCTAssertFalse(m.diskFits(downloadGB: 19))  // 19 + 2 = 21 > 20
  }

  // MARK: - Recommendation

  func testRecommendationFor48GBPicksHighestQualityComfortableModel() {
    // 48 GB Apple Silicon → qwen3:30b (MoE) is the top-quality model that still fits comfortably.
    let recommended = mac(ram: 48).recommendedModel()
    XCTAssertEqual(recommended?.tag, "qwen3:30b")
  }

  func testRecommendationForSmallMacStaysWithinBudget() {
    let m = mac(ram: 8)
    guard let recommended = m.recommendedModel() else {
      return XCTFail("Expected a recommendation even on a small Mac")
    }
    XCTAssertNotEqual(
      m.fit(forRuntimeRAMGB: recommended.estimatedRuntimeRAMGB), .tooLarge,
      "Recommendation must never exceed the machine's usable RAM")
    // It should be the highest-quality model among those that fit comfortably.
    let comfortable = OllamaModelCatalog.models.filter {
      m.diskFits(downloadGB: $0.downloadGB)
        && m.fit(forRuntimeRAMGB: $0.estimatedRuntimeRAMGB) == .comfortable
    }
    if let bestComfortable = comfortable.max(by: { $0.qualityRank < $1.qualityRank }) {
      XCTAssertEqual(recommended.tag, bestComfortable.tag)
    }
  }

  func testRecommendationFallsBackWhenDiskTiny() {
    // Almost no disk → only the smallest model can be recommended.
    let recommended = mac(ram: 64, disk: 2).recommendedModel()
    XCTAssertEqual(
      recommended?.tag, OllamaModelCatalog.models.min { $0.downloadGB < $1.downloadGB }?.tag)
  }

  // MARK: - GB formatting

  func testFormatGB() {
    XCTAssertEqual(SystemCapabilities.formatGB(48), "48 GB")
    XCTAssertEqual(SystemCapabilities.formatGB(17), "17 GB")
    XCTAssertEqual(SystemCapabilities.formatGB(8.1), "8,1 GB")
    XCTAssertEqual(SystemCapabilities.formatGB(0.8), "0,8 GB")
  }

  // MARK: - Pull progress

  func testPullProgressFraction() {
    XCTAssertEqual(
      OllamaService.PullProgress(status: "downloading", completed: 50, total: 100).fraction, 0.5)
    XCTAssertNil(
      OllamaService.PullProgress(status: "downloading", completed: 50, total: 0).fraction)
    XCTAssertNil(
      OllamaService.PullProgress(status: "pulling manifest", completed: nil, total: nil).fraction)
    XCTAssertEqual(
      OllamaService.PullProgress(status: "downloading", completed: 200, total: 100).fraction, 1.0,
      "fraction clamps to 1.0")
  }

  func testInstalledModelSizeGB() {
    let model = OllamaService.InstalledModel(
      name: "gemma3:latest", sizeBytes: 3_338_801_804, parameterSize: "4.3B", quantization: "Q4_K_M"
    )
    XCTAssertEqual(model.sizeGB, 3.338801804, accuracy: 0.001)
  }

  @MainActor
  func testHumanStatusMapping() {
    func status(_ s: String, completed: Int64? = nil, total: Int64? = nil) -> String {
      LocalModelManager.humanStatus(
        OllamaService.PullProgress(status: s, completed: completed, total: total))
    }
    XCTAssertEqual(status("pulling manifest"), "Manifest wird geladen …")
    XCTAssertEqual(status("verifying sha256 digest"), "Wird geprüft …")
    XCTAssertEqual(status("downloading", completed: 42, total: 100), "Lädt … 42 %")
    XCTAssertEqual(status("downloading"), "Lädt …")
  }
}
