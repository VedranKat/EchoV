import Carbon
import Foundation

protocol HotkeyService: AnyObject {
    func register(_ registrations: [HotkeyRegistration]) throws
    func unregister()
}

struct HotkeyRegistration: Sendable {
    let id: UInt32
    let binding: HotkeyBinding
    let onPressed: @Sendable () -> Void
    let onReleased: (@Sendable () -> Void)?
}

final class CarbonHotkeyService: HotkeyService {
    private let signature = FourCharCode("ECHV")

    private var registrationsByID: [UInt32: HotkeyRegistration] = [:]
    private var eventHandler: EventHandlerRef?
    private var hotkeyRefs: [EventHotKeyRef] = []

    func register(_ registrations: [HotkeyRegistration]) throws {
        unregister()
        registrationsByID = Dictionary(uniqueKeysWithValues: registrations.map { ($0.id, $0) })

        guard !registrations.isEmpty else {
            return
        }

        var eventTypes = [
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: OSType(kEventHotKeyPressed)
            ),
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: OSType(kEventHotKeyReleased)
            )
        ]

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
                service.handleHotkey(id: hotkeyID, eventKind: GetEventKind(event))
                return noErr
            },
            eventTypes.count,
            &eventTypes,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        guard installStatus == noErr else {
            throw AppError.hotkeyUnavailable(details: "Could not install hotkey event handler (\(installStatus)).")
        }

        for registration in registrations {
            var hotkeyRef: EventHotKeyRef?
            let carbonHotkeyID = EventHotKeyID(signature: signature, id: registration.id)
            let registerStatus = RegisterEventHotKey(
                registration.binding.keyCode,
                registration.binding.carbonModifiers,
                carbonHotkeyID,
                GetApplicationEventTarget(),
                0,
                &hotkeyRef
            )

            guard registerStatus == noErr, let hotkeyRef else {
                unregister()
                throw AppError.hotkeyUnavailable(details: "Could not register \(registration.binding.displayName) (\(registerStatus)).")
            }

            hotkeyRefs.append(hotkeyRef)
        }
    }

    func unregister() {
        for hotkeyRef in hotkeyRefs {
            UnregisterEventHotKey(hotkeyRef)
        }
        hotkeyRefs.removeAll()

        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }

        registrationsByID.removeAll()
    }

    private func handleHotkey(id: EventHotKeyID, eventKind: UInt32) {
        guard id.signature == signature, let registration = registrationsByID[id.id] else {
            return
        }

        switch eventKind {
        case UInt32(kEventHotKeyPressed):
            registration.onPressed()
        case UInt32(kEventHotKeyReleased):
            registration.onReleased?()
        default:
            break
        }
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
