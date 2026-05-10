import Carbon
import Foundation

protocol HotkeyService: AnyObject {
    func register(_ binding: HotkeyBinding, handler: @escaping @Sendable () -> Void) throws
    func unregister()
}

final class CarbonHotkeyService: HotkeyService {
    private let signature = FourCharCode("ECHV")
    private let hotkeyID = UInt32(1)

    private var handler: (@Sendable () -> Void)?
    private var eventHandler: EventHandlerRef?
    private var hotkeyRef: EventHotKeyRef?

    func register(_ binding: HotkeyBinding, handler: @escaping @Sendable () -> Void) throws {
        unregister()
        self.handler = handler

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let userData else {
                    return noErr
                }

                var hotkeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotkeyID
                )

                guard status == noErr else {
                    return status
                }

                let service = Unmanaged<CarbonHotkeyService>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                service.handleHotkey(id: hotkeyID)
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        guard installStatus == noErr else {
            throw AppError.hotkeyUnavailable(details: "Could not install hotkey event handler (\(installStatus)).")
        }

        let carbonHotkeyID = EventHotKeyID(signature: signature, id: hotkeyID)
        let registerStatus = RegisterEventHotKey(
            binding.keyCode,
            binding.carbonModifiers,
            carbonHotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        guard registerStatus == noErr else {
            unregister()
            throw AppError.hotkeyUnavailable(details: "Could not register \(binding.displayName) (\(registerStatus)).")
        }
    }

    func unregister() {
        if let hotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
            self.hotkeyRef = nil
        }

        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }

        handler = nil
    }

    private func handleHotkey(id: EventHotKeyID) {
        guard id.signature == signature, id.id == hotkeyID else {
            return
        }

        handler?()
    }
}

private extension HotkeyBinding {
    var carbonModifiers: UInt32 {
        var carbon: UInt32 = 0

        if modifiers.contains(.command) {
            carbon |= UInt32(cmdKey)
        }

        if modifiers.contains(.option) {
            carbon |= UInt32(optionKey)
        }

        if modifiers.contains(.control) {
            carbon |= UInt32(controlKey)
        }

        if modifiers.contains(.shift) {
            carbon |= UInt32(shiftKey)
        }

        return carbon
    }
}

private extension FourCharCode {
    init(_ string: String) {
        precondition(string.utf8.count == 4)
        self = string.utf8.reduce(0) { result, byte in
            (result << 8) + FourCharCode(byte)
        }
    }
}
