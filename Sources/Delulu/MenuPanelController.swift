import AppKit
import SwiftUI

/// Borderless, rounded utility panel with a solid charcoal surface.
@MainActor final class MenuPanelController: NSObject, NSWindowDelegate {
    private let window: MenuPanel
    private let hosting: PanelHostingView<DeluluView>
    private var clickMonitor: Any?
    private weak var anchor: NSStatusBarButton?
    private var contentSize = NSSize(width: 344, height: 300)

    var isVisible: Bool { window.isVisible }

    init(rootView: DeluluView) {
        hosting = PanelHostingView(rootView: rootView)
        window = MenuPanel(contentRect: NSRect(origin: .zero, size: contentSize),
                           styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        super.init()
        window.isOpaque = false
        window.backgroundColor = .clear
        window.appearance = NSAppearance(named: .darkAqua)
        window.hasShadow = true
        window.level = .popUpMenu
        window.isReleasedWhenClosed = false
        window.isMovable = false
        window.hidesOnDeactivate = false
        window.collectionBehavior = [.transient, .moveToActiveSpace, .fullScreenAuxiliary]
        window.delegate = self
        window.title = "Delulu"

        hosting.frame = NSRect(origin: .zero, size: contentSize)
        hosting.autoresizingMask = [.width, .height]
        hosting.sizingOptions = []
        let surface = NSView(frame: hosting.frame)
        surface.wantsLayer = true
        surface.layer?.backgroundColor = NSColor(srgbRed: 0.141, green: 0.149, blue: 0.153, alpha: 1).cgColor
        surface.layer?.cornerRadius = 20
        surface.layer?.masksToBounds = true
        surface.layer?.borderWidth = 1
        surface.layer?.borderColor = NSColor(srgbRed: 0.22, green: 0.23, blue: 0.24, alpha: 1).cgColor
        surface.addSubview(hosting)
        window.contentView = surface
    }

    func show(below button: NSStatusBarButton) {
        anchor = button
        updateFrame()
        window.makeKeyAndOrderFront(nil)
        // Don't focus the first text field just by opening the panel.
        window.makeFirstResponder(nil)
        if clickMonitor == nil {
            clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                Task { @MainActor in self?.hide() }
            }
        }
    }

    func hide() {
        window.orderOut(nil)
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        clickMonitor = nil
    }

    func resize(to size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let rounded = NSSize(width: ceil(size.width), height: ceil(size.height))
        guard rounded != contentSize else { return }
        contentSize = rounded
        updateFrame()
    }

    private func updateFrame() {
        guard let anchor, let anchorWindow = anchor.window else { return }
        let buttonRect = anchorWindow.convertToScreen(anchor.convert(anchor.bounds, to: nil))
        let screen = anchorWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? buttonRect
        let x = min(max(buttonRect.midX - contentSize.width / 2, screen.minX + 10), screen.maxX - contentSize.width - 10)
        let y = max(screen.minY + 10, buttonRect.minY - contentSize.height - 9)
        window.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: contentSize), display: true)
    }

    func windowDidResignKey(_ notification: Notification) {
        // Let a click on our menu-bar icon reach its toggle action before hiding.
        if let anchor, let anchorWindow = anchor.window,
           anchorWindow.convertToScreen(anchor.convert(anchor.bounds, to: nil)).contains(NSEvent.mouseLocation) {
            return
        }
        hide()
    }
}

@MainActor private final class MenuPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { orderOut(nil) }
}

@MainActor private final class PanelHostingView<Content: View>: NSHostingView<Content> {
    override var isOpaque: Bool { false }
    override var allowsVibrancy: Bool { false }
}
