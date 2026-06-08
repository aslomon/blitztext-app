import XCTest

@testable import Blitztext

@MainActor
final class AutomaticContextTests: XCTestCase {

  func testRewriteConfigDefaultsAutomaticFieldContextOff() {
    XCTAssertFalse(RewriteConfig().useAutomaticFieldContext)
    XCTAssertFalse(ModeConfig.default(for: .textImprover).rewrite.useAutomaticFieldContext)
    XCTAssertFalse(ModeConfig.default(for: .dampfAblassen).rewrite.useAutomaticFieldContext)
  }

  func testEnabledAutomaticFieldContextFlagsAdvancedDisclosure() {
    var email = ModeConfig.default(for: .textImprover)
    email.rewrite.useAutomaticFieldContext = true

    XCTAssertTrue(email.isAdvancedNonDefault)
  }

  func testAutomaticFieldContextBlockIsInjectedWhenEnabled() throws {
    var rewrite = RewriteConfig(systemPrompt: "Write the message.")
    rewrite.useAutomaticFieldContext = true
    let context = AutomaticRewriteContext(
      text: "Previous email says the invoice is missing.",
      appBundleID: "com.apple.mail",
      appName: "Mail",
      windowTitle: "Invoice thread"
    )

    let prompt = LLMService.rewriteSystemPrompt(
      rewrite,
      customTerms: [],
      selection: nil,
      automaticContext: context,
      memory: nil
    )

    XCTAssertTrue(prompt.contains("Aktueller Arbeitskontext"))
    XCTAssertTrue(prompt.contains("Previous email says the invoice is missing."))
    XCTAssertTrue(prompt.contains("Mail"))
    XCTAssertTrue(prompt.contains("Invoice thread"))
  }

  func testAutomaticFieldContextIsIgnoredWhenDisabled() {
    let rewrite = RewriteConfig(systemPrompt: "Write the message.")
    let context = AutomaticRewriteContext(
      text: "Do not include me.",
      appBundleID: nil,
      appName: nil,
      windowTitle: nil
    )

    let prompt = LLMService.rewriteSystemPrompt(
      rewrite,
      customTerms: [],
      selection: nil,
      automaticContext: context,
      memory: nil
    )

    XCTAssertFalse(prompt.contains("Aktueller Arbeitskontext"))
    XCTAssertFalse(prompt.contains("Do not include me."))
  }

  func testAutomaticFieldContextWindowPrefersCursorRelativeText() {
    let text = String(repeating: "A", count: 2500)
      + " CURSOR_CONTEXT "
      + String(repeating: "B", count: 2500)
    let window = SelectionContextService.automaticFieldContextWindow(
      fullText: text,
      selectedRange: NSRange(location: 2500, length: 0),
      maxChars: 1200
    )

    XCTAssertLessThanOrEqual(window.utf16.count, 1200)
    XCTAssertTrue(window.contains("CURSOR_CONTEXT"))
    XCTAssertFalse(window.hasPrefix(String(repeating: "A", count: 1500)))
  }
}
