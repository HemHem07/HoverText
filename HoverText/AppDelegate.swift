import AppKit
import SwiftUI
import Carbon.HIToolbox
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var windowController: QuickCaptureWindowController?
    private var historyWindowController: NSWindowController?
    private var settingsWindowController: NSWindowController?
    private var captureViewModel = CaptureViewModel()
    private var persistence = PersistenceService()
    private var hotKeyManager: HotKeyManager?
    private var cancellables = Set<AnyCancellable>()
    private var escapeMonitor: Any?
    private var previousApp: NSRunningApplication?
    private var returnToSettingsAfterCapture = false
    private var isRecordingHotKey = false
    private var lastWorkingHotKey: (keyCode: UInt32, flags: NSEvent.ModifierFlags)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Make the app an agent (no Dock icon) and enable status bar only UI
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        setupHotKey()
        purgeExpiredCaptures()
        
        NotificationCenter.default.addObserver(self, selector: #selector(beginHotkeyRecording), name: .hotkeyRecordingBegan, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(endHotkeyRecording), name: .hotkeyRecordingEnded, object: nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyManager?.unregister()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard windowController?.isVisible == true else { return .terminateNow }
        guard saveCurrentCaptureIfNeeded() else { return .terminateCancel }
        captureViewModel.finishSaving()
        return .terminateNow
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: "Quick Capture")
            button.action = #selector(statusItemTapped)
            button.target = self
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Toggle Quick Capture", action: #selector(toggleQuickCapture), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "History…", action: #selector(openHistory), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func setupHotKey() {
        let prefs = HotKeyPreferences.shared

        hotKeyManager = HotKeyManager(keyCode: prefs.keyCode, modifiers: HotKeyManager.Modifiers(rawValue: prefs.carbonModifierMask)) { [weak self] in
            self?.toggleQuickCapture()
        }

        prefs.$keyCode
            .combineLatest(prefs.$modifierFlags)
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
            .sink { [weak self] keyCode, flags in
                guard let self, !self.isRecordingHotKey else { return }
                self.updateHotKey(keyCode: keyCode, flags: flags)
            }
            .store(in: &cancellables)

        prefs.$captureRetention
            .dropFirst()
            .sink { [weak self] _ in
                self?.purgeExpiredCaptures()
            }
            .store(in: &cancellables)
    }

    @objc private func statusItemTapped() {
        toggleQuickCapture()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // Central toggle function per requirements
    @objc func toggleQuickCapture() {
        NSLog("[HoverText] toggleQuickCapture invoked")
        if windowController?.isVisible == true {
            persistAndCloseIfNeeded()
        } else {
            openFreshCapture()
        }
    }

    @objc private func openSettings() {
        if settingsWindowController == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 500),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Settings"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView())
            window.center()
            settingsWindowController = NSWindowController(window: window)
        }

        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        if windowController?.isVisible == true {
            returnToSettingsAfterCapture = true
        }
    }

    @objc private func openHistory() {
        purgeExpiredCaptures(refreshHistory: false)

        let entries: [CaptureEntry]
        do {
            entries = try persistence.loadEntries()
        } catch {
            NSAlert(error: error).runModal()
            return
        }

        let contentView = NSHostingView(rootView: HistoryView(
            entries: entries,
            onOpenAsDraft: { [weak self] entry in self?.openAsDraft(entry) },
            onDelete: { [weak self] entry in self?.deleteHistoryEntry(entry) }
        ))
        if let window = historyWindowController?.window {
            window.contentView = contentView
        } else {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 640, height: 560),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "History"
            window.contentView = contentView
            window.center()
            historyWindowController = NSWindowController(window: window)
        }
        historyWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func viewModelRequestFocus() {
        DispatchQueue.main.async { [weak self] in
            self?.captureViewModel.requestFocus()
        }
    }

    func persistAndCloseIfNeeded() {
        if windowController?.isVisible == true {
            NSLog("[HoverText] Persisting & closing capture")
            guard saveCurrentCaptureIfNeeded() else { return }
            captureViewModel.finishSaving()
            windowController?.hide()
            if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor); self.escapeMonitor = nil; NSLog("[HoverText] Escape monitor removed") }
            restorePreviousAppFocus()
        }
    }

    func openFreshCapture() {
        // Remember the app that was frontmost so we can restore focus on close
        returnToSettingsAfterCapture = settingsWindowController?.window?.isKeyWindow == true
        if previousApp == nil {
            previousApp = NSWorkspace.shared.frontmostApplication
        }
        captureViewModel.discard()
        if windowController == nil { windowController = QuickCaptureWindowController(viewModel: captureViewModel) }
        showCapture()
    }

    private func showCapture() {
        windowController?.showAndFocus()
        viewModelRequestFocus()
        if HotKeyPreferences.shared.autoDismissOnEscape {
            if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor); self.escapeMonitor = nil }
            NSLog("[HoverText] Installing Escape monitor")
            escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if event.keyCode == UInt16(kVK_Escape) {
                    NSLog("[HoverText] Escape detected -> persist & close")
                    self?.persistAndCloseIfNeeded()
                    return nil
                }
                return event
            }
        }
    }

    private func openAsDraft(_ entry: CaptureEntry) {
        if windowController?.isVisible == true {
            guard saveCurrentCaptureIfNeeded() else { return }
            captureViewModel.finishSaving()
        }

        windowController?.hide()
        captureViewModel.loadDraft(body: entry.body, imageURLs: entry.imageURLs)
        windowController = QuickCaptureWindowController(viewModel: captureViewModel)
        historyWindowController?.close()
        showCapture()
    }

    private func deleteHistoryEntry(_ entry: CaptureEntry) {
        let alert = NSAlert()
        alert.messageText = "Delete this capture?"
        alert.informativeText = "This can’t be undone."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.buttons.first?.hasDestructiveAction = true
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            try persistence.deleteEntry(entry)
            openHistory()
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    private func purgeExpiredCaptures(refreshHistory: Bool = true) {
        guard let days = HotKeyPreferences.shared.captureRetention.days,
              let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else { return }
        do {
            try persistence.deleteEntries(olderThan: cutoff)
            if refreshHistory, historyWindowController?.window?.isVisible == true {
                openHistory()
            }
        } catch {
            NSLog("[HoverText] Failed to remove expired captures: \(error.localizedDescription)")
        }
    }
    
    @objc private func beginHotkeyRecording() {
        NSLog("[HoverText] Pausing global hotkey for recording")
        isRecordingHotKey = true
        hotKeyManager?.unregister()
    }

    @objc private func endHotkeyRecording() {
        NSLog("[HoverText] Resuming global hotkey after recording")
        guard isRecordingHotKey else { return }
        isRecordingHotKey = false
        let prefs = HotKeyPreferences.shared
        updateHotKey(keyCode: prefs.keyCode, flags: prefs.modifierFlags)
    }

    private func restorePreviousAppFocus() {
        if returnToSettingsAfterCapture,
           let settingsWindow = settingsWindowController?.window,
           settingsWindow.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            settingsWindow.makeKeyAndOrderFront(nil)
            returnToSettingsAfterCapture = false
            previousApp = nil
            return
        }

        returnToSettingsAfterCapture = false
        if let app = previousApp, app != NSRunningApplication.current {
            if #available(macOS 14.0, *) {
                app.activate()
            } else {
                app.activate(options: [.activateIgnoringOtherApps])
            }
        }
        previousApp = nil
    }

    func hideWithoutSaveAndRestoreFocus() {
        if windowController?.isVisible == true {
            captureViewModel.discard()
            windowController?.hide()
            if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor); self.escapeMonitor = nil }
            restorePreviousAppFocus()
        }
    }

    func saveCurrentCaptureAndStartNew() {
        guard saveCurrentCaptureIfNeeded() else { return }
        captureViewModel.finishSaving()
        viewModelRequestFocus()
    }

    private func saveCurrentCaptureIfNeeded() -> Bool {
        let text = captureViewModel.draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        let imageURLs = captureViewModel.attachments.map(\.url)
        guard !text.isEmpty || !imageURLs.isEmpty else { return true }

        do {
            try persistence.appendEntry(body: text, imageURLs: imageURLs)
            return true
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = "HoverText couldn’t save this capture."
            alert.informativeText = error.localizedDescription
            alert.runModal()
            return false
        }
    }

    private func updateHotKey(keyCode: UInt32, flags: NSEvent.ModifierFlags) {
        guard let hotKeyManager else { return }
        if let lastWorkingHotKey,
           lastWorkingHotKey.keyCode == keyCode,
           lastWorkingHotKey.flags == flags,
           hotKeyManager.isRegistered {
            return
        }

        let status = hotKeyManager.reregister(
            keyCode: keyCode,
            modifiers: HotKeyManager.Modifiers(rawValue: carbonMask(for: flags))
        )
        if status == noErr {
            lastWorkingHotKey = (keyCode, flags)
            return
        }

        let keptPrevious = lastWorkingHotKey != nil
        if let lastWorkingHotKey {
            let prefs = HotKeyPreferences.shared
            prefs.keyCode = lastWorkingHotKey.keyCode
            prefs.modifierFlags = lastWorkingHotKey.flags
        }
        let alert = NSAlert()
        alert.messageText = "That shortcut isn’t available."
        alert.informativeText = keptPrevious
            ? "HoverText kept the previous shortcut."
            : "Choose another shortcut in Settings."
        alert.runModal()
    }

    private func carbonMask(for flags: NSEvent.ModifierFlags) -> UInt32 {
        var mask: UInt32 = 0
        if flags.contains(.command) { mask |= UInt32(cmdKey) }
        if flags.contains(.option) { mask |= UInt32(optionKey) }
        if flags.contains(.control) { mask |= UInt32(controlKey) }
        if flags.contains(.shift) { mask |= UInt32(shiftKey) }
        return mask
    }
}

extension Notification.Name {
    static let hotkeyRecordingBegan = Notification.Name("HotkeyRecordingBegan")
    static let hotkeyRecordingEnded = Notification.Name("HotkeyRecordingEnded")
}
