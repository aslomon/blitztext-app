import XCTest

@testable import Blitztext

/// `ModeConfig.default(for:)` plus its building-block static helpers are the source of truth
/// for the four repurposed slots (Diktat / E-Mail / Prompt / Social) and their curated prompts.
/// The migration in AppState composes these helpers, so locking them down protects the migration.
final class ModeConfigDefaultsTests: XCTestCase {

  // MARK: - User-facing default names

  func testDefaultUserNames() {
    XCTAssertEqual(ModeConfig.defaultUserName(for: .transcription), "Diktat")
    XCTAssertEqual(ModeConfig.defaultUserName(for: .localTranscription), "Diktat (lokal)")
    XCTAssertEqual(ModeConfig.defaultUserName(for: .textImprover), "E-Mail")
    XCTAssertEqual(ModeConfig.defaultUserName(for: .dampfAblassen), "Prompt")
    XCTAssertEqual(ModeConfig.defaultUserName(for: .emojiText), "Social")
  }

  func testDefaultForSlotComposesNameKindAndRewrite() {
    let email = ModeConfig.default(for: .textImprover)
    XCTAssertEqual(email.slot, .textImprover)
    XCTAssertEqual(email.userName, "E-Mail")
    XCTAssertTrue(email.isEnabled)
    XCTAssertEqual(email.kind, .transcribeThenRewrite)
  }

  // MARK: - Default kinds

  func testDefaultKinds() {
    XCTAssertEqual(ModeConfig.defaultKind(for: .transcription), .transcribeOnly)
    XCTAssertEqual(ModeConfig.defaultKind(for: .localTranscription), .transcribeOnly)
    XCTAssertEqual(ModeConfig.defaultKind(for: .textImprover), .transcribeThenRewrite)
    XCTAssertEqual(ModeConfig.defaultKind(for: .dampfAblassen), .transcribeThenRewrite)
    XCTAssertEqual(ModeConfig.defaultKind(for: .emojiText), .transcribeThenEmoji)
  }

  // MARK: - Curated prompts

  func testEmailSlotUsesCuratedEmailPrompt() {
    let email = ModeConfig.default(for: .textImprover)
    XCTAssertEqual(email.rewrite.systemPrompt, ModeDefaults.emailSystemPrompt)
    XCTAssertEqual(email.rewrite.modelID, RewriteModelRegistry.strongModelID)
    XCTAssertTrue(email.rewrite.systemPrompt.contains("E-Mail"))
  }

  func testPromptSlotUsesCuratedPromptCraftPrompt() {
    let prompt = ModeConfig.default(for: .dampfAblassen)
    XCTAssertEqual(prompt.rewrite.systemPrompt, ModeDefaults.promptCraftSystemPrompt)
    XCTAssertEqual(prompt.rewrite.modelID, RewriteModelRegistry.strongModelID)
    XCTAssertTrue(prompt.rewrite.systemPrompt.contains("KI-Coding-Agenten"))
  }

  func testEmojiSlotUsesFastModelAndNoSystemPrompt() {
    let social = ModeConfig.default(for: .emojiText)
    XCTAssertEqual(social.kind, .transcribeThenEmoji)
    XCTAssertEqual(social.rewrite.modelID, RewriteModelRegistry.fastModelID)
    XCTAssertTrue(social.rewrite.systemPrompt.isEmpty)
  }

  func testTranscriptionSlotsHaveEmptyRewrite() {
    let plain = ModeConfig.default(for: .transcription)
    XCTAssertTrue(plain.rewrite.systemPrompt.isEmpty)
    XCTAssertEqual(plain.rewrite.rewriteBackend, .openai)
    XCTAssertEqual(plain.kind, .transcribeOnly)
  }

  // MARK: - Curated prompt content integrity (no truncation across the \-continuations)

  func testCuratedPromptsAreNonEmptyAndSingleLineJoined() {
    // The multiline string literals use trailing backslashes to join physical lines;
    // assert the join produced one continuous paragraph (no stray double spaces / newlines mid-word).
    XCTAssertFalse(ModeDefaults.emailSystemPrompt.contains("  "))
    XCTAssertFalse(ModeDefaults.promptCraftSystemPrompt.contains("  "))
    XCTAssertGreaterThan(ModeDefaults.emailSystemPrompt.count, 100)
    XCTAssertGreaterThan(ModeDefaults.promptCraftSystemPrompt.count, 100)
  }
}
