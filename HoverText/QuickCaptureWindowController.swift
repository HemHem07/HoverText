import AppKit
import SwiftUI

final class QuickCaptureWindowController: NSWindowController {
    private lazy var hosting: NSHostingView<CaptureView> = {
        NSHostingView(rootView: CaptureView(viewModel: viewModel, onCloseWithoutSave: { [weak self] in
            self?.closeWithoutSave()
        }, onSaveAndNew: { [weak self] in
            self?.saveAndNew()
        }, onImageInserted: { [weak self] height in
            self?.growToFitImage(height: height)
        }))
    }()
    private let viewModel: CaptureViewModel

    init(viewModel: CaptureViewModel) {
        self.viewModel = viewModel
        let contentRect = NSRect(x: 0, y: 0, width: 420, height: 240)
        // Configure as non-activating, always-floating panel that can appear over other apps
        let window = NSPanel(contentRect: contentRect, styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView], backing: .buffered, defer: false)
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces, .stationary]
        window.isMovableByWindowBackground = true
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.hasShadow = false
        window.backgroundColor = .clear
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        super.init(window: window)

        NotificationCenter.default.post(name: .captureWindowFocusChanged, object: nil, userInfo: ["focused": true])
        window.delegate = self
        window.collectionBehavior.insert(.transient)

        window.contentView = hosting

        NotificationCenter.default.addObserver(self, selector: #selector(preferencesChanged), name: UserDefaults.didChangeNotification, object: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    var isVisible: Bool { window?.isVisible == true }

    func showAndFocus() {
        guard let window = window else { return }
        applySizePreset()
        positionWindow()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        // Avoid layout recursion: refocus asynchronously
        DispatchQueue.main.async { [weak self] in
            self?.viewModel.requestFocus()
        }
    }

    func hide() {
        window?.orderOut(nil)
    }

    private func closeWithoutSave() {
        (NSApp.delegate as? AppDelegate)?.hideWithoutSaveAndRestoreFocus()
    }

    private func saveAndNew() {
        NSLog("[HoverText] saveAndNew tapped")
        (NSApp.delegate as? AppDelegate)?.saveCurrentCaptureAndStartNew()
        applySizePreset()
        positionWindow()
    }

    @objc private func preferencesChanged() {
        guard isVisible else { return }
        applySizePreset()
        positionWindow()
    }

    private func applySizePreset() {
        guard let window = window else { return }
        let prefs = HotKeyPreferences.shared
        let size: NSSize
        switch prefs.captureSize {
        case .small: size = NSSize(width: 360, height: 200)
        case .medium: size = NSSize(width: 420, height: 240)
        case .large: size = NSSize(width: 520, height: 300)
        }
        window.setContentSize(size)
    }

    private func growToFitImage(height: CGFloat) {
        guard let window, let screen = window.screen ?? NSScreen.main else { return }
        let maximumHeight = screen.visibleFrame.height - 48
        window.setContentSize(NSSize(
            width: window.contentView?.frame.width ?? window.frame.width,
            height: min(max(window.contentView?.frame.height ?? window.frame.height, height + 100), maximumHeight)
        ))
        positionWindow()
    }

    private func positionWindow() {
        guard let screen = NSScreen.main, let window = window else { return }
        let prefs = HotKeyPreferences.shared
        let visible = screen.visibleFrame
        let size = window.frame.size
        let margin: CGFloat = 24

        var origin = NSPoint(x: visible.midX - size.width / 2, y: visible.minY + margin)

        switch prefs.capturePosition {
        case .bottomLeft:
            origin.x = visible.minX + margin
        case .bottomCenter:
            origin.x = visible.midX - size.width / 2
        case .bottomRight:
            origin.x = visible.maxX - size.width - margin
        }

        window.setFrame(NSRect(origin: origin, size: size), display: true)
    }

}

extension QuickCaptureWindowController: NSWindowDelegate {
    func windowDidBecomeKey(_ notification: Notification) {
        NotificationCenter.default.post(name: .captureWindowFocusChanged, object: nil, userInfo: ["focused": true])
    }
    func windowDidResignKey(_ notification: Notification) {
        NotificationCenter.default.post(name: .captureWindowFocusChanged, object: nil, userInfo: ["focused": false])
    }
}

extension Notification.Name {
    static let captureWindowFocusChanged = Notification.Name("CaptureWindowFocusChanged")
}
