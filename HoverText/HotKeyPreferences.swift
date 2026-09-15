import Foundation
import AppKit
import Carbon.HIToolbox
import Combine

enum CapturePosition: String, CaseIterable, Identifiable {
    case bottomLeft, bottomCenter, bottomRight
    var id: String { rawValue }
    var label: String {
        switch self {
        case .bottomLeft: return "Bottom Left"
        case .bottomCenter: return "Bottom Center"
        case .bottomRight: return "Bottom Right"
        }
    }
}

enum CaptureSize: String, CaseIterable, Identifiable {
    case small, medium, large
    var id: String { rawValue }
}

enum CaptureRetention: String, CaseIterable, Identifiable {
    case oneDay, sevenDays, thirtyDays, never

    var id: String { rawValue }
    var label: String {
        switch self {
        case .oneDay: return "1 Day"
        case .sevenDays: return "7 Days"
        case .thirtyDays: return "30 Days"
        case .never: return "Never"
        }
    }
    var days: Int? {
        switch self {
        case .oneDay: return 1
        case .sevenDays: return 7
        case .thirtyDays: return 30
        case .never: return nil
        }
    }

    func isShorter(than current: CaptureRetention) -> Bool {
        (days ?? .max) < (current.days ?? .max)
    }
}

final class HotKeyPreferences: ObservableObject {
    static let shared = HotKeyPreferences()

    @Published var keyCode: UInt32 {
        didSet { save() }
    }

    @Published var modifierFlags: NSEvent.ModifierFlags {
        didSet { save() }
    }

    @Published var capturePosition: CapturePosition {
        didSet { save() }
    }

    @Published var captureSize: CaptureSize {
        didSet { save() }
    }
    
    @Published var autoDismissOnEscape: Bool {
        didSet { save() }
    }

    @Published var captureRetention: CaptureRetention {
        didSet { save() }
    }

    private let keyCodeKey = "HotKey.keyCode"
    private let flagsKey = "HotKey.flags"
    private let positionKey = "Capture.position"
    private let sizeKey = "Capture.size"
    private let dismissKey = "Capture.autoDismissOnEscape"
    private let retentionKey = "Capture.retention"

    private init() {
        let defaults = UserDefaults.standard

        // Load saved values
        let savedKeyCodeNumber = defaults.object(forKey: keyCodeKey) as? NSNumber
        let savedFlagsNumber = defaults.object(forKey: flagsKey) as? NSNumber
        let savedPosition = defaults.string(forKey: positionKey)
        let savedSize = defaults.string(forKey: sizeKey)
        let hasDismiss = defaults.object(forKey: dismissKey) != nil
        let savedRetention = defaults.string(forKey: retentionKey)

        // Compute hotkey defaults safely without touching self
        var keyCodeVal: UInt32 = savedKeyCodeNumber?.uint32Value ?? UInt32(kVK_ANSI_C)
        let flagsRaw: UInt = savedFlagsNumber.map { UInt(truncating: $0) } ?? (NSEvent.ModifierFlags.control.union(.option)).rawValue
        var flagsVal = NSEvent.ModifierFlags(rawValue: flagsRaw)

        // Enforce at least one modifier; prevent bare letter default
        if flagsVal.isEmpty {
            flagsVal = [.control, .option]
            keyCodeVal = UInt32(kVK_ANSI_C)
        }

        // Position and size
        let positionVal = savedPosition.flatMap { CapturePosition(rawValue: $0) } ?? .bottomCenter
        let sizeVal = savedSize.flatMap { CaptureSize(rawValue: $0) } ?? .medium

        // Auto-dismiss
        let autoDismissVal: Bool = hasDismiss ? defaults.bool(forKey: dismissKey) : false
        let retentionVal = savedRetention.flatMap(CaptureRetention.init(rawValue:)) ?? .never

        // Now assign to published properties
        self.keyCode = keyCodeVal
        self.modifierFlags = flagsVal
        self.capturePosition = positionVal
        self.captureSize = sizeVal
        self.autoDismissOnEscape = autoDismissVal
        self.captureRetention = retentionVal
    }

    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(NSNumber(value: keyCode), forKey: keyCodeKey)
        defaults.set(NSNumber(value: modifierFlags.rawValue), forKey: flagsKey)
        defaults.set(capturePosition.rawValue, forKey: positionKey)
        defaults.set(captureSize.rawValue, forKey: sizeKey)
        defaults.set(autoDismissOnEscape, forKey: dismissKey)
        defaults.set(captureRetention.rawValue, forKey: retentionKey)
    }

    // Convert NSEvent.ModifierFlags to Carbon modifier mask used by RegisterEventHotKey
    var carbonModifierMask: UInt32 {
        var mask: UInt32 = 0
        if modifierFlags.contains(.command) { mask |= UInt32(cmdKey) }
        if modifierFlags.contains(.option) { mask |= UInt32(optionKey) }
        if modifierFlags.contains(.control) { mask |= UInt32(controlKey) }
        if modifierFlags.contains(.shift) { mask |= UInt32(shiftKey) }
        return mask
    }
}
