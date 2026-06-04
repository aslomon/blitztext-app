import AppKit
import ApplicationServices

/// Reads the user's current text selection (and a little surrounding text) from the
/// frontmost app via the Accessibility API. Reuses the existing Accessibility grant.
/// Best-effort: many WebKit/Electron apps don't expose AXSelectedText — returns nil then.
@MainActor
enum SelectionContextService {
  private static let maxSelectedChars = 4000
  private static let maxSurroundingChars = 1500

  /// Captures the current selection synchronously. Call while the target app is still frontmost.
  static func capture() -> SelectionContext? {
    guard AXIsProcessTrusted() else { return nil }

    let systemWide = AXUIElementCreateSystemWide()
    guard let focused = copyElement(systemWide, kAXFocusedUIElementAttribute) else { return nil }

    let selected = copyString(focused, kAXSelectedTextAttribute)
    let surrounding = copyString(focused, kAXValueAttribute)

    let selectedText = clamp(selected, to: maxSelectedChars)
    let surroundingText = clamp(surrounding, to: maxSurroundingChars)

    let context = SelectionContext(
      selectedText: selectedText,
      surroundingText: selectedText.isEmpty ? surroundingText : "",
      appBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    )
    return context.isEmpty ? nil : context
  }

  // MARK: - AX helpers

  private static func copyElement(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    guard result == .success, let value else { return nil }
    guard CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
    return (value as! AXUIElement)
  }

  private static func copyString(_ element: AXUIElement, _ attribute: String) -> String {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    guard result == .success, let value, CFGetTypeID(value) == CFStringGetTypeID() else {
      return ""
    }
    return (value as! CFString) as String
  }

  private static func clamp(_ text: String, to limit: Int) -> String {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count > limit else { return trimmed }
    return String(trimmed.prefix(limit))
  }
}
