import AppKit
import ApplicationServices

/// Reads the user's current text selection (and a little surrounding text) from the
/// frontmost app via the Accessibility API. Reuses the existing Accessibility grant.
/// Best-effort: many WebKit/Electron apps don't expose AXSelectedText — returns nil then.
@MainActor
enum SelectionContextService {
  private static let maxSelectedChars = 4000
  // DR-4: cursor-relatives Fenster statt ganzes Feld — kleineres Budget aus Datenschutzgründen.
  static let maxSurroundingChars = 600
  static let maxAutomaticFieldContextChars = 2_000

  /// Captures the current selection synchronously. Call while the target app is still frontmost.
  static func capture() -> SelectionContext? {
    guard AXIsProcessTrusted() else { return nil }

    let systemWide = AXUIElementCreateSystemWide()
    guard let focused = copyElement(systemWide, kAXFocusedUIElementAttribute) else { return nil }

    let selected = copyString(focused, kAXSelectedTextAttribute)
    let fullText = copyString(focused, kAXValueAttribute)
    let selectedRange = copySelectedRange(focused)

    let selectedText = clamp(selected, to: maxSelectedChars)
    // DR-4: nur ein Fenster um den Cursor/die Auswahl senden, nicht das ganze Feld.
    let surroundingText = surroundingWindow(
      fullText: fullText, selectedRange: selectedRange, maxChars: maxSurroundingChars)

    let context = SelectionContext(
      selectedText: selectedText,
      surroundingText: selectedText.isEmpty ? surroundingText : "",
      appBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    )
    return context.isEmpty ? nil : context
  }

  /// Captures the focused input field as transient working context without requiring a selection.
  /// Secure fields are skipped by the caller-provided target snapshot. Best-effort: apps that do
  /// not expose text through AX simply return nil.
  static func captureAutomaticFieldContext(
    appBundleID: String?,
    appName: String?,
    windowTitle: String?,
    isSecureField: Bool
  ) -> AutomaticRewriteContext? {
    guard !isSecureField, AXIsProcessTrusted() else { return nil }

    let systemWide = AXUIElementCreateSystemWide()
    guard let focused = copyElement(systemWide, kAXFocusedUIElementAttribute) else { return nil }

    let fullText = copyString(focused, kAXValueAttribute)
    let selectedRange = copySelectedRange(focused)
    let text = automaticFieldContextWindow(
      fullText: fullText,
      selectedRange: selectedRange,
      maxChars: maxAutomaticFieldContextChars
    )

    let context = AutomaticRewriteContext(
      text: text,
      appBundleID: appBundleID,
      appName: appName,
      windowTitle: windowTitle
    )
    return context.isEmpty ? nil : context
  }

  // MARK: - Windowing (testbar, rein)

  /// DR-4: liefert ein cursor-relatives Fenster um `selectedRange` (max. `maxChars` Zeichen,
  /// grob zentriert auf die Auswahl). Ist die Range nil/ungültig, wird wie bisher auf die
  /// ersten `maxChars` Zeichen zurückgefallen. Arbeitet auf der UTF-16-View, um die
  /// `NSRange`-Semantik der Accessibility-API zu treffen, und ist gegen Out-of-Bounds gesichert.
  static func surroundingWindow(
    fullText: String, selectedRange: NSRange?, maxChars: Int = 600
  ) -> String {
    let units = Array(fullText.utf16)
    let total = units.count
    guard total > 0, maxChars > 0 else { return "" }

    // Ungültige / fehlende Range → erste maxChars Zeichen (heutiges Verhalten, kleineres Budget).
    guard let range = selectedRange,
      range.location != NSNotFound,
      range.location >= 0,
      range.length >= 0,
      range.location <= total
    else {
      return clamp(String(decoding: units.prefix(maxChars), as: UTF16.self), to: maxChars)
    }

    if total <= maxChars { return clamp(fullText, to: maxChars) }

    let rangeEnd = min(range.location + range.length, total)
    // Restbudget gleichmäßig vor/hinter die Auswahl legen, dann an die Stringgrenzen klemmen.
    let budget = max(0, maxChars - (rangeEnd - range.location))
    var start = range.location - budget / 2
    var end = rangeEnd + (budget - budget / 2)
    if start < 0 {
      end += -start
      start = 0
    }
    if end > total {
      start -= end - total
      end = total
    }
    start = max(0, start)
    let window = String(decoding: units[start..<end], as: UTF16.self)
    return clamp(window, to: maxChars)
  }

  /// Larger cursor-relative window for automatic field context. Kept separate from
  /// `surroundingWindow` so reply/edit selection stays on its tighter privacy budget.
  static func automaticFieldContextWindow(
    fullText: String, selectedRange: NSRange?, maxChars: Int = 2_000
  ) -> String {
    surroundingWindow(fullText: fullText, selectedRange: selectedRange, maxChars: maxChars)
  }

  // MARK: - AX helpers

  /// Liest `kAXSelectedTextRangeAttribute` als `NSRange`. Gibt nil zurück, wenn das Attribut
  /// fehlt, kein `AXValue` vom Typ `.cfRange` ist oder die Extraktion scheitert. Kein Force-Unwrap.
  private static func copySelectedRange(_ element: AXUIElement) -> NSRange? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(
      element, kAXSelectedTextRangeAttribute as CFString, &value)
    guard result == .success, let value,
      CFGetTypeID(value) == AXValueGetTypeID()
    else { return nil }
    // value ist als CFTypeRef bereits ein AXValue; getrennt prüfen wir den Wert-Typ unten.
    let axValue = value as! AXValue
    guard AXValueGetType(axValue) == .cfRange else { return nil }
    var cfRange = CFRange()
    guard AXValueGetValue(axValue, .cfRange, &cfRange) else { return nil }
    guard cfRange.location >= 0, cfRange.length >= 0 else { return nil }
    return NSRange(location: cfRange.location, length: cfRange.length)
  }

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
