import AppKit
import DeluluCore
import SwiftUI

@MainActor final class Navigation: ObservableObject {
    enum Page { case compose, profile }
    @Published var page: Page = .compose
    var dismiss: () -> Void = {}
    var resize: (CGSize) -> Void = { _ in }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: MenuPanelController?
    private let notifications = NotificationService()
    private let navigation = Navigation()
    private var model: AppModel!

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Retain and install the notification delegate before launch finishes.
        _ = notifications
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let firstLaunch = !FileManager.default.fileExists(atPath: FileStateStore.defaultURL.path)
        model = AppModel(store: FileStateStore(url: FileStateStore.defaultURL), notifications: notifications)
        panel = MenuPanelController(rootView: DeluluView(model: model, navigation: navigation))
        navigation.dismiss = { [weak self] in self?.panel?.hide() }
        navigation.resize = { [weak self] size in self?.panel?.resize(to: size) }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "envelope.badge", accessibilityDescription: "Delulu — dream job messages")
            button.image?.isTemplate = true
            button.toolTip = "Delulu"
            button.target = self
            button.action = #selector(togglePanel)
        }
        notifications.onOpen = { [weak self] in
            guard let self else { return }
            navigation.page = .compose
            showPanel()
        }
        Task { await model.restoreSchedule() }
        if firstLaunch || ProcessInfo.processInfo.arguments.contains("--show") { showPanel() }
    }

    @objc private func togglePanel() {
        if panel?.isVisible == true { panel?.hide() } else { showPanel() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPanel()
        return true
    }

    private func showPanel() {
        guard let button = statusItem?.button else { return }
        panel?.show(below: button)
        Task { await model.refresh() }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
