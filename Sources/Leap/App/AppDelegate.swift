import AppKit
import ApplicationServices
import LeapCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let leapMode = LeapMode()
    private let scrollMode = ScrollMode()
    private var statusItem: NSStatusItem?
    private var leapMenuItem: NSMenuItem?
    private var scrollMenuItem: NSMenuItem?
    private var autoActivateMenuItem: NSMenuItem?
    private var hotKeyObserver: AnyObject?

    func applicationDidFinishLaunching(_: Notification) {
        Settings.registerDefaults()
        setUpMainMenu()
        setUpStatusItem()
        registerHotKeys()
        hotKeyObserver = Settings.observe([Settings.Key.leapHotKey, Settings.Key.scrollHotKey]) {
            [weak self] in
            self?.registerHotKeys()
        }
        whenAccessibilityTrusted { [weak self] in
            // The event tap and the Dock observer can only be created with the permission.
            self?.registerHotKeys()
            self?.watchMissionControl()
            Task(priority: .utility) { await ElementFinder.warmUpMenuExtras() }
        }
        // A new user sees which shortcuts start the modes, and where to change them.
        if Settings.isFirstLaunch() { showSettings() }
    }

    // MARK: Mission Control

    private let missionControl = MissionControlWatcher()

    private func watchMissionControl() {
        missionControl.onOpen = { [weak self] started in
            guard let self, Settings.autoActivateInMissionControl,
                !leapMode.isActive, !scrollMode.isActive
            else { return }
            leapMode.start(missionControl: started.map { .shortcut($0) } ?? .unknown)
        }
        missionControl.onClose = { [weak self] in
            guard let self, leapMode.isMissionControl else { return }
            leapMode.end()
        }
        missionControl.start()
    }

    @objc private func toggleAutoActivateInMissionControl() {
        Settings.autoActivateInMissionControl.toggle()
    }

    // MARK: Modes

    @objc private func toggleLeapMode() {
        if scrollMode.isActive { scrollMode.end() }
        leapMode.start()
    }

    @objc private func toggleScrollMode() {
        if leapMode.isActive { leapMode.end() }
        scrollMode.start()
    }

    /// Also runs whenever a shortcut changes in Settings or through `defaults write`.
    private func registerHotKeys() {
        HotKeys.shared.unregisterAll()
        show(Settings.leapHotKey, on: leapMenuItem)
        show(Settings.scrollHotKey, on: scrollMenuItem)
        if let spec = Settings.leapHotKey {
            HotKeys.shared.register(spec) { [weak self] in self?.toggleLeapMode() }
        }
        if let spec = Settings.scrollHotKey {
            HotKeys.shared.register(spec) { [weak self] in self?.toggleScrollMode() }
        }
        if let spec = MissionControlWatcher.shortcut {
            HotKeys.shared.observe(spec) { [weak self] in
                guard let self else { return }
                // Closing: the windows start moving back now, so the labels go now too.
                if missionControl.isOpen, leapMode.isMissionControl { leapMode.end() }
                missionControl.expectChange()
            }
        }
    }

    private func show(_ spec: HotKeySpec?, on item: NSMenuItem?) {
        guard let item else { return }
        let equivalent = spec.flatMap(KeyboardLayout.menuKeyEquivalent(for:))
        item.keyEquivalent = equivalent?.key ?? ""
        item.keyEquivalentModifierMask = equivalent?.modifiers ?? []
    }

    // MARK: Permission

    /// Runs `start` once Leap has Accessibility permission: right away, or after asking for
    /// it and checking every second until it is granted, so a new user need not relaunch.
    private func whenAccessibilityTrusted(_ start: @escaping @MainActor () -> Void) {
        // The value of kAXTrustedCheckOptionPrompt; the imported global is not concurrency-safe.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        Log.app.notice("launched, accessibility trusted: \(trusted)")
        guard !trusted else { return start() }
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            guard AXIsProcessTrusted() else { return }
            timer.invalidate()
            Log.app.notice("accessibility granted")
            MainActor.assumeIsolated { start() }
        }
    }

    // MARK: Menus

    /// Never shown, since Leap is a menu bar agent, but its key equivalents still work in
    /// the Settings window: ⌘W closes it, ⌘Q quits, and the Edit commands work in its text field.
    private func setUpMainMenu() {
        let appMenu = NSMenu(title: "Leap")
        appMenu.addItem(
            withTitle: "Quit Leap", action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q")
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(
            withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(
            withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(
            withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        let mainMenu = NSMenu()
        for menu in [appMenu, editMenu, windowMenu] {
            let item = NSMenuItem()
            item.submenu = menu
            mainMenu.addItem(item)
        }
        NSApp.mainMenu = mainMenu
    }

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = MenuBarIcon.image()
        let menu = NSMenu()
        leapMenuItem = menu.addItem(
            withTitle: "Leap", action: #selector(toggleLeapMode), keyEquivalent: "")
        scrollMenuItem = menu.addItem(
            withTitle: "Scroll", action: #selector(toggleScrollMode), keyEquivalent: "")
        menu.addItem(.separator())
        autoActivateMenuItem = menu.addItem(
            withTitle: "Leap in Mission Control",
            action: #selector(toggleAutoActivateInMissionControl),
            keyEquivalent: ""
        )
        menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit Leap", action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q")
        for menuItem in menu.items where menuItem.action != #selector(NSApplication.terminate(_:)) {
            menuItem.target = self
        }
        menu.delegate = self
        item.menu = menu
        statusItem = item
        ElementFinder.ownStatusItem = item.button
    }

    /// Settings and `defaults write` can change this too, so it is read on every open.
    func menuNeedsUpdate(_: NSMenu) {
        autoActivateMenuItem?.state = Settings.autoActivateInMissionControl ? .on : .off
    }

    private let settingsWindow = SettingsWindow()

    /// Opening Leap again (Spotlight, Finder) while it runs shows Settings.
    /// Quitting from Settings would leave macOS to pick some background process as the
    /// active app; hiding first hands the keyboard back to the app that was in front.
    func applicationWillTerminate(_: Notification) {
        if NSApp.isActive { NSApp.hide(nil) }
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        showSettings()
        return false
    }

    @objc private func showSettings() {
        settingsWindow.show()
    }
}
