import XCTest

@testable import Blitztext

/// Round-trip and forward/backward-compatibility tests for the persisted settings shape.
/// These guard the on-disk contract: `settings.json` is decoded with `decodeIfPresent`
/// migrations, and `modes` MUST serialize as a keyed object (not an array).
final class AppSettingsCodableTests: XCTestCase {

  private func makeEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return encoder
  }

  // MARK: - Round-trip

  func testRoundTripPreservesModesAndNewFlags() throws {
    var settings = AppSettings(
      archiveEnabled: true,
      memoryContextEnabled: true,
      hadAccessibilityGrant: true
    )
    var emailMode = ModeConfig.default(for: .textImprover)
    emailMode.userName = "Mein E-Mail Modus"
    emailMode.rewrite.rewriteBackend = .local
    emailMode.rewrite.useMemoryContext = true
    settings.modes = [
      WorkflowType.transcription.rawValue: .default(for: .transcription),
      WorkflowType.textImprover.rawValue: emailMode,
    ]

    let data = try makeEncoder().encode(settings)
    let decoded = try JSONDecoder().decode(AppSettings.self, from: data)

    XCTAssertTrue(decoded.archiveEnabled)
    XCTAssertTrue(decoded.memoryContextEnabled)
    XCTAssertTrue(decoded.hadAccessibilityGrant)
    XCTAssertEqual(decoded.modes.count, 2)

    let decodedEmail = try XCTUnwrap(decoded.modes[WorkflowType.textImprover.rawValue])
    XCTAssertEqual(decodedEmail.userName, "Mein E-Mail Modus")
    XCTAssertEqual(decodedEmail.rewrite.rewriteBackend, .local)
    XCTAssertTrue(decodedEmail.rewrite.useMemoryContext)
    XCTAssertEqual(decodedEmail.slot, .textImprover)
  }

  /// `modes` must encode as a JSON OBJECT keyed by WorkflowType.rawValue, never an array.
  /// A regression to an array shape would silently drop every persisted mode on the next load.
  func testModesEncodeAsKeyedObjectNotArray() throws {
    var settings = AppSettings()
    settings.modes = [
      WorkflowType.transcription.rawValue: .default(for: .transcription),
      WorkflowType.emojiText.rawValue: .default(for: .emojiText),
    ]

    let data = try makeEncoder().encode(settings)
    let object = try JSONSerialization.jsonObject(with: data)
    let root = try XCTUnwrap(object as? [String: Any])

    let modes = try XCTUnwrap(root["modes"] as? [String: Any], "modes must be a keyed object")
    XCTAssertFalse(root["modes"] is [Any], "modes must NOT be a JSON array")
    XCTAssertNotNil(modes[WorkflowType.transcription.rawValue])
    XCTAssertNotNil(modes[WorkflowType.emojiText.rawValue])
  }

  // MARK: - Backward compatibility (decodeIfPresent migrations)

  /// An OLD settings.json missing every v2 key must still decode, with the new flags
  /// defaulting to OFF (privacy-preserving opt-in defaults) and modes defaulting to empty.
  func testOldSettingsMissingNewKeysDecodesWithDefaults() throws {
    let legacyJSON = """
      {
        "hotkeyMode": "hold",
        "hasSeenOnboarding": true,
        "secureLocalModeEnabled": false
      }
      """
    let data = Data(legacyJSON.utf8)
    let decoded = try JSONDecoder().decode(AppSettings.self, from: data)

    XCTAssertEqual(decoded.hotkeyMode, .hold)
    XCTAssertTrue(decoded.hasSeenOnboarding)
    // New v2 keys absent -> safe defaults.
    XCTAssertFalse(decoded.archiveEnabled)
    XCTAssertFalse(decoded.memoryContextEnabled)
    XCTAssertFalse(decoded.hadAccessibilityGrant)
    XCTAssertTrue(decoded.modes.isEmpty)
    XCTAssertFalse(decoded.didMigrateToModeConfigs)
    XCTAssertEqual(decoded.modesSchemaVersion, 1)
  }

  /// A completely empty object must decode to a fully-defaulted struct (never throws).
  func testEmptyObjectDecodesToDefaults() throws {
    let data = Data("{}".utf8)
    let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
    XCTAssertEqual(decoded.hotkeyMode, .hold)
    XCTAssertFalse(decoded.archiveEnabled)
    XCTAssertFalse(decoded.memoryContextEnabled)
    XCTAssertFalse(decoded.hadAccessibilityGrant)
    // Dictation dictionary absent -> empty replacements, spoken punctuation defaults OFF.
    // OFF avoids silently mapping real words like "Punkt"/"Komma" to symbols (data-corruption).
    XCTAssertTrue(decoded.dictationDictionary.replacements.isEmpty)
    XCTAssertFalse(decoded.dictationDictionary.spokenPunctuationEnabled)
  }

  /// Round-trips the dictation dictionary (replacements + the punctuation toggle) and confirms
  /// an OLD settings.json missing the key decodes to a safe default (no replacements, toggle OFF).
  func testDictationDictionaryRoundTripAndMigration() throws {
    var settings = AppSettings()
    settings.dictationDictionary = DictationDictionary(
      replacements: [
        DictationReplacement(from: "blitztext", to: "Blitztext"),
        DictationReplacement(from: "ue", to: "ü", wholeWord: false),
      ],
      spokenPunctuationEnabled: false
    )

    let data = try makeEncoder().encode(settings)
    let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
    XCTAssertEqual(decoded.dictationDictionary.replacements.count, 2)
    XCTAssertFalse(decoded.dictationDictionary.spokenPunctuationEnabled)
    let first = try XCTUnwrap(decoded.dictationDictionary.replacements.first)
    XCTAssertEqual(first.from, "blitztext")
    XCTAssertEqual(first.to, "Blitztext")
    XCTAssertTrue(first.wholeWord)
    XCTAssertFalse(decoded.dictationDictionary.replacements[1].wholeWord)

    // Legacy settings without the key -> default dictionary (toggle defaults OFF).
    let legacy = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
    XCTAssertTrue(legacy.dictationDictionary.replacements.isEmpty)
    XCTAssertFalse(legacy.dictationDictionary.spokenPunctuationEnabled)
  }

  /// A mode persisted WITHOUT the v2 `rewrite.useMemoryContext` key decodes to false.
  func testModeWithoutUseMemoryContextDefaultsFalse() throws {
    let json = """
      {
        "modes": {
          "textImprover": {
            "slot": "textImprover",
            "userName": "E-Mail",
            "isEnabled": true,
            "kind": "transcribeThenRewrite",
            "rewrite": {
              "systemPrompt": "x",
              "rewriteBackend": "openai",
              "modelID": "gpt-4o"
            }
          }
        }
      }
      """
    let decoded = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
    let mode = try XCTUnwrap(decoded.modes["textImprover"])
    XCTAssertFalse(mode.rewrite.useMemoryContext)
    XCTAssertEqual(mode.rewrite.rewriteBackend, .openai)
    XCTAssertEqual(mode.userName, "E-Mail")
  }
}
