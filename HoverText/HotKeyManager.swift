import AppKit
import Carbon.HIToolbox

final class HotKeyManager {
    struct Modifiers: OptionSet { 
        let rawValue: UInt32
        static let command = Modifiers(rawValue: UInt32(cmdKey))
        static let option  = Modifiers(rawValue: UInt32(optionKey))
        static let control = Modifiers(rawValue: UInt32(controlKey))
        static let shift   = Modifiers(rawValue: UInt32(shiftKey))
    }

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let handler: () -> Void
    private var keyCode: UInt32
    private var modifiers: Modifiers
    var isRegistered: Bool { hotKeyRef != nil }

    init(keyCode: UInt32, modifiers: Modifiers, handler: @escaping () -> Void) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.handler = handler
    }

    @discardableResult
    func register() -> OSStatus {
        unregister()

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { (_, _, userData) -> OSStatus in
            let myself = Unmanaged<HotKeyManager>.fromOpaque(userData!).takeUnretainedValue()
            NSLog("[HoverText] Hotkey pressed")
            myself.handler()
            return noErr
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let target = GetApplicationEventTarget()
        NSLog("[HoverText] Installing hotkey handler; keyCode=\(keyCode), modifiers=\(modifiers.rawValue)")
        let handlerStatus = InstallEventHandler(target, callback, 1, &eventType, selfPtr, &eventHandler)
        guard handlerStatus == noErr else { return handlerStatus }

        let hotKeyID = EventHotKeyID(signature: OSType(0x484B4D47), id: 1) // 'HKMG'
        let status = RegisterEventHotKey(keyCode, modifiers.rawValue, hotKeyID, target, 0, &hotKeyRef)
        NSLog("[HoverText] RegisterEventHotKey status=\(status)")
        if status != noErr {
            NSLog("[HoverText] Failed to register hotkey: \(status)")
            unregister()
        }
        return status
    }

    func unregister() {
        if let hotKeyRef {
            NSLog("[HoverText] Unregistering existing hotkey")
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }
    
    @discardableResult
    func reregister(keyCode: UInt32, modifiers: Modifiers) -> OSStatus {
        let previousKeyCode = self.keyCode
        let previousModifiers = self.modifiers
        self.keyCode = keyCode
        self.modifiers = modifiers
        let status = register()
        if status != noErr {
            self.keyCode = previousKeyCode
            self.modifiers = previousModifiers
            register()
        }
        return status
    }

    deinit {
        unregister()
    }
}
