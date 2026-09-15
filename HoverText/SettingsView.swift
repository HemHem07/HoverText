import Foundation
import SwiftUI
import Carbon.HIToolbox

struct SettingsView: View {
    @ObservedObject private var prefs = HotKeyPreferences.shared
    @State private var recording = false
    @State private var selectedOption: HotkeyOption = .custom
    @State private var launchAtLogin = LaunchAtLoginManager.isEnabled
    @State private var showLaunchAtLoginError = false
    @State private var pendingRetention: CaptureRetention?

    private var retentionSelection: Binding<CaptureRetention> {
        Binding(
            get: { prefs.captureRetention },
            set: { retention in
                if retention.isShorter(than: prefs.captureRetention) {
                    pendingRetention = retention
                } else {
                    prefs.captureRetention = retention
                }
            }
        )
    }

    var body: some View {
        GlassEffectContainer(spacing: 16) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Settings")
                    .font(.title2.weight(.semibold))
                    .padding(.bottom, 8)

                GlobalShortcutSection(
                    prefs: prefs,
                    selectedOption: $selectedOption,
                    recording: $recording
                )

                // Position
                VStack(alignment: .leading, spacing: 8) {
                    Text("Capture Window Position")
                        .font(.headline)
                    Picker("Position", selection: $prefs.capturePosition) {
                        ForEach(CapturePosition.allCases) { pos in
                            Text(pos.label).tag(pos)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Size
                VStack(alignment: .leading, spacing: 8) {
                    Text("Capture Window Size")
                        .font(.headline)
                    Picker("Size", selection: $prefs.captureSize) {
                        ForEach(CaptureSize.allCases) { size in
                            Text(size.rawValue.capitalized).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Behavior
                VStack(alignment: .leading, spacing: 8) {
                    Text("Behavior")
                        .font(.headline)
                    Toggle("Auto-dismiss with Escape", isOn: $prefs.autoDismissOnEscape)
                    Toggle("Launch at login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, enabled in
                            if !LaunchAtLoginManager.setEnabled(enabled) {
                                launchAtLogin = LaunchAtLoginManager.isEnabled
                                showLaunchAtLoginError = true
                            }
                        }
                    Text("Delete captures after")
                    Picker("Delete captures after", selection: retentionSelection) {
                        ForEach(CaptureRetention.allCases) { retention in
                            Text(retention.label).tag(retention)
                        }
                    }
                    .pickerStyle(.segmented)
                    .alert(item: $pendingRetention) { retention in
                        Alert(
                            title: Text("Delete older captures?"),
                            message: Text("Captures older than \(retention.label.lowercased()) will be deleted immediately. This can’t be undone."),
                            primaryButton: .destructive(Text("Delete Now")) {
                                prefs.captureRetention = retention
                            },
                            secondaryButton: .cancel()
                        )
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(20)
            .frame(width: 480)
        }
        .onAppear {
            launchAtLogin = LaunchAtLoginManager.isEnabled
        }
        .onDisappear {
            recording = false
        }
        .alert("Couldn’t update Launch at Login", isPresented: $showLaunchAtLoginError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Check HoverText’s permission in System Settings.")
        }
    }
}

private struct ShortcutDisplay: View {
    let keyCode: UInt32?
    let flags: NSEvent.ModifierFlags

    private var keyLabel: String {
        guard let keyCode = keyCode else { return "—" }
        switch keyCode {
        case UInt32(kVK_ANSI_A): return "A"
        case UInt32(kVK_ANSI_B): return "B"
        case UInt32(kVK_ANSI_C): return "C"
        case UInt32(kVK_ANSI_D): return "D"
        case UInt32(kVK_ANSI_E): return "E"
        case UInt32(kVK_ANSI_F): return "F"
        case UInt32(kVK_ANSI_G): return "G"
        case UInt32(kVK_ANSI_H): return "H"
        case UInt32(kVK_ANSI_I): return "I"
        case UInt32(kVK_ANSI_J): return "J"
        case UInt32(kVK_ANSI_K): return "K"
        case UInt32(kVK_ANSI_L): return "L"
        case UInt32(kVK_ANSI_M): return "M"
        case UInt32(kVK_ANSI_N): return "N"
        case UInt32(kVK_ANSI_O): return "O"
        case UInt32(kVK_ANSI_P): return "P"
        case UInt32(kVK_ANSI_Q): return "Q"
        case UInt32(kVK_ANSI_R): return "R"
        case UInt32(kVK_ANSI_S): return "S"
        case UInt32(kVK_ANSI_T): return "T"
        case UInt32(kVK_ANSI_U): return "U"
        case UInt32(kVK_ANSI_V): return "V"
        case UInt32(kVK_ANSI_W): return "W"
        case UInt32(kVK_ANSI_X): return "X"
        case UInt32(kVK_ANSI_Y): return "Y"
        case UInt32(kVK_ANSI_Z): return "Z"
        case UInt32(kVK_ANSI_0): return "0"
        case UInt32(kVK_ANSI_1): return "1"
        case UInt32(kVK_ANSI_2): return "2"
        case UInt32(kVK_ANSI_3): return "3"
        case UInt32(kVK_ANSI_4): return "4"
        case UInt32(kVK_ANSI_5): return "5"
        case UInt32(kVK_ANSI_6): return "6"
        case UInt32(kVK_ANSI_7): return "7"
        case UInt32(kVK_ANSI_8): return "8"
        case UInt32(kVK_ANSI_9): return "9"
        case UInt32(kVK_ANSI_Minus): return "-"
        case UInt32(kVK_ANSI_Equal): return "="
        case UInt32(kVK_ANSI_LeftBracket): return "["
        case UInt32(kVK_ANSI_RightBracket): return "]"
        case UInt32(kVK_ANSI_Backslash): return "\\"
        case UInt32(kVK_ANSI_Semicolon): return ";"
        case UInt32(kVK_ANSI_Quote): return "'"
        case UInt32(kVK_ANSI_Comma): return ","
        case UInt32(kVK_ANSI_Period): return "."
        case UInt32(kVK_ANSI_Slash): return "/"
        case UInt32(kVK_ANSI_Grave): return "`"
        case UInt32(kVK_Space): return "Space"
        case UInt32(kVK_Return): return "Return"
        case UInt32(kVK_Tab): return "Tab"
        case UInt32(kVK_Escape): return "Esc"
        case UInt32(kVK_Delete): return "Delete"
        case UInt32(kVK_ForwardDelete): return "Forward Delete"
        case UInt32(kVK_LeftArrow): return "Left"
        case UInt32(kVK_RightArrow): return "Right"
        case UInt32(kVK_UpArrow): return "Up"
        case UInt32(kVK_DownArrow): return "Down"
        default: return "Key \(keyCode)"
        }
    }

    private var modifierLabels: [String] {
        var labels: [String] = []
        if flags.contains(.command) { labels.append("⌘") }
        if flags.contains(.option) { labels.append("⌥") }
        if flags.contains(.control) { labels.append("⌃") }
        if flags.contains(.shift) { labels.append("⇧") }
        return labels
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(modifierLabels, id: \.self) { mod in
                Text(mod)
                    .font(.body.weight(.medium))
                    .foregroundColor(.primary.opacity(0.8))
            }
            Text(keyLabel)
                .font(.body.weight(.bold))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.15)))
    }
}

private struct ShortcutCaptureOverlay: NSViewRepresentable {
    @Binding var recording: Bool
    var onCapture: (UInt32, NSEvent.ModifierFlags) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSEventCaptureView()
        view.onCapture = { keyCode, flags in
            onCapture(keyCode, flags)
            recording = false
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let captureView = nsView as? NSEventCaptureView {
            captureView.isCapturing = recording
        }
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: ()) {
        (nsView as? NSEventCaptureView)?.isCapturing = false
    }

    class NSEventCaptureView: NSView {
        var onCapture: ((UInt32, NSEvent.ModifierFlags) -> Void)?
        private var keyMonitor: Any?

        var isCapturing = false {
            didSet {
                guard oldValue != isCapturing else { return }
                if isCapturing {
                    Foundation.NotificationCenter.default.post(name: .hotkeyRecordingBegan, object: nil)
                    window?.makeFirstResponder(self)
                    installKeyMonitor()
                } else {
                    removeKeyMonitor()
                    Foundation.NotificationCenter.default.post(name: .hotkeyRecordingEnded, object: nil)
                }
            }
        }

        deinit {
            if isCapturing {
                Foundation.NotificationCenter.default.post(name: .hotkeyRecordingEnded, object: nil)
            }
            removeKeyMonitor()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if isCapturing {
                window?.makeFirstResponder(self)
            }
        }

        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            guard isCapturing else { return }
            capture(event)
        }

        override func flagsChanged(with event: NSEvent) {
            // Do nothing special here, handled by keyDown
        }

        private func installKeyMonitor() {
            removeKeyMonitor()
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, self.isCapturing else { return event }
                if self.capture(event) {
                    return nil
                }
                return event
            }
        }

        @discardableResult
        private func capture(_ event: NSEvent) -> Bool {
            let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard !flags.isEmpty else { return false }
            onCapture?(UInt32(event.keyCode), flags)
            return true
        }

        private func removeKeyMonitor() {
            if let keyMonitor {
                NSEvent.removeMonitor(keyMonitor)
                self.keyMonitor = nil
            }
        }
    }
}

#Preview {
    SettingsView()
}

private struct GlobalShortcutSection: View {
    @ObservedObject var prefs: HotKeyPreferences
    @Binding var selectedOption: HotkeyOption
    @Binding var recording: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Global Shortcut")
                .font(.headline)

            Picker("Shortcut", selection: $selectedOption) {
                ForEach(HotkeyOption.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedOption) { _, newValue in
                if newValue != .custom {
                    recording = false
                }
                apply(option: newValue)
            }
            .onAppear {
                selectedOption = currentOption()
            }

            Text("Choose a preset that avoids conflicts with system shortcuts.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if selectedOption == .custom {
                CustomRecorderView(prefs: prefs, recording: $recording, selectedOption: $selectedOption)
                    .transition(.opacity)
            }
        }
    }

    private func currentOption() -> HotkeyOption {
        let flags = prefs.modifierFlags
        let key = Int(prefs.keyCode)
        if key == kVK_ANSI_Slash && flags == [.command, .shift] { return .cmdShiftSlash }
        if key == kVK_ANSI_Slash && flags == [.control, .shift] { return .ctrlShiftSlash }
        if key == kVK_Space && flags == [.control, .shift] { return .ctrlShiftSpace }
        if key == kVK_Space && flags == [.option, .shift] { return .optionShiftSpace }
        return .custom
    }

    private func apply(option: HotkeyOption) {
        switch option {
        case .cmdShiftSlash:
            prefs.keyCode = UInt32(kVK_ANSI_Slash)
            prefs.modifierFlags = [.command, .shift]
        case .ctrlShiftSlash:
            prefs.keyCode = UInt32(kVK_ANSI_Slash)
            prefs.modifierFlags = [.control, .shift]
        case .ctrlShiftSpace:
            prefs.keyCode = UInt32(kVK_Space)
            prefs.modifierFlags = [.control, .shift]
        case .optionShiftSpace:
            prefs.keyCode = UInt32(kVK_Space)
            prefs.modifierFlags = [.option, .shift]
        case .custom:
            break
        }
    }
}

private struct CustomRecorderView: View {
    @ObservedObject var prefs: HotKeyPreferences
    @Binding var recording: Bool
    @Binding var selectedOption: HotkeyOption

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ShortcutField(
                keyCode: recording ? nil : prefs.keyCode,
                flags: recording ? [] : prefs.modifierFlags,
                recording: $recording
            ) { key, mods in
                prefs.keyCode = key
                prefs.modifierFlags = mods
            }

            Button(recording ? "Cancel" : "Record Shortcut") {
                if recording {
                    recording = false
                } else {
                    selectedOption = .custom
                    recording = true
                }
            }
            .buttonStyle(.glass)
            .frame(width: 148)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ShortcutField: View {
    let keyCode: UInt32?
    let flags: NSEvent.ModifierFlags
    @Binding var recording: Bool
    let onCapture: (UInt32, NSEvent.ModifierFlags) -> Void

    var body: some View {
        ZStack {
            ShortcutDisplay(keyCode: keyCode, flags: flags)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.ultraThinMaterial))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.tertiary, lineWidth: 1))
                .overlay(
                    Group {
                        if recording {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.accentColor, lineWidth: 2)
                        }
                    }
                )

            if recording {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Press new keys…")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .overlay(
            recording ? AnyView(ShortcutCaptureOverlay(recording: $recording, onCapture: onCapture)) : AnyView(EmptyView())
        )
        .frame(minWidth: 210, minHeight: 44)
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private enum HotkeyOption: String, CaseIterable, Identifiable {
    case cmdShiftSlash
    case ctrlShiftSlash
    case ctrlShiftSpace
    case optionShiftSpace
    case custom

    var id: String { rawValue }
    var label: String {
        switch self {
        case .cmdShiftSlash: return "⌘ ⇧ /"
        case .ctrlShiftSlash: return "⌃ ⇧ /"
        case .ctrlShiftSpace: return "⌃ ⇧ Space"
        case .optionShiftSpace: return "⌥ ⇧ Space"
        case .custom: return "Custom"
        }
    }

    static var allCases: [HotkeyOption] { [.cmdShiftSlash, .ctrlShiftSlash, .ctrlShiftSpace, .optionShiftSpace, .custom] }
}
