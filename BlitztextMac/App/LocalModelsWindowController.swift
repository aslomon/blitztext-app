import AppKit
import SwiftUI

/// Hosts the `LocalModelsView` in a standalone, resizable window. The 340pt menu-bar popover is too
/// narrow for the model catalog (sizes, RAM, progress), so model management gets its own window.
/// Created by `AppDelegate`; opened on the `.openLocalModelsWindow` notification.
@MainActor
final class LocalModelsWindowController {
  private let manager: LocalModelManager
  private var window: NSWindow?

  init(manager: LocalModelManager) {
    self.manager = manager
  }

  /// Show (creating on first use) and focus the window, then refresh its data.
  func show() {
    if window == nil {
      window = makeWindow()
    }
    guard let window else { return }
    window.makeKeyAndOrderFront(nil)
    if !window.isVisible || window.frame.origin == .zero {
      window.center()
    }
    NSApp.activate(ignoringOtherApps: true)
    Task { await manager.refresh() }
  }

  private func makeWindow() -> NSWindow {
    let hosting = NSHostingController(rootView: LocalModelsView(manager: manager))
    let window = NSWindow(contentViewController: hosting)
    window.title = "Lokale Modelle"
    window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
    window.setContentSize(NSSize(width: 560, height: 660))
    window.minSize = NSSize(width: 520, height: 480)
    window.isReleasedWhenClosed = false
    window.center()
    return window
  }
}
