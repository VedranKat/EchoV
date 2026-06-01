import AudioToolbox
import AVFoundation
import CoreAudio
import Foundation

struct MicrophoneDevice: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
}

enum MicrophoneDeviceCatalog {
    static func inputDevices() -> [MicrophoneDevice] {
        let captureDeviceUIDs = audioCaptureDeviceUIDs()

        return allAudioDeviceIDs()
            .filter(hasInputStreams)
            .compactMap { deviceID -> MicrophoneDevice? in
                guard
                    let uid = stringProperty(
                        kAudioDevicePropertyDeviceUID,
                        for: deviceID,
                        scope: kAudioObjectPropertyScopeGlobal
                    )
                else {
                    return nil
                }

                guard captureDeviceUIDs.contains(uid) else {
                    return nil
                }

                let name = stringProperty(
                    kAudioObjectPropertyName,
                    for: deviceID,
                    scope: kAudioObjectPropertyScopeGlobal
                ) ?? "Microphone"

                guard !isSystemDefaultAggregate(
                    name: name,
                    uid: uid,
                    modelUID: stringProperty(
                        kAudioDevicePropertyModelUID,
                        for: deviceID,
                        scope: kAudioObjectPropertyScopeGlobal
                    ),
                    manufacturer: stringProperty(
                        kAudioObjectPropertyManufacturer,
                        for: deviceID,
                        scope: kAudioObjectPropertyScopeGlobal
                    )
                ) else {
                    return nil
                }

                return MicrophoneDevice(id: uid, name: name)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func isSystemDefaultAggregate(
        name: String,
        uid: String? = nil,
        modelUID: String? = nil,
        manufacturer: String? = nil
    ) -> Bool {
        let compactIdentity = [name, uid, modelUID, manufacturer]
            .compactMap { $0 }
            .map(compactedDeviceText)
            .joined()

        return compactIdentity.contains("defaultdeviceaggregate")
    }

    static func audioDeviceID(for uid: String) -> AudioDeviceID? {
        allAudioDeviceIDs().first { deviceID in
            stringProperty(
                kAudioDevicePropertyDeviceUID,
                for: deviceID,
                scope: kAudioObjectPropertyScopeGlobal
            ) == uid
        }
    }

    private static func allAudioDeviceIDs() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize
        ) == noErr else {
            return []
        }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = Array(repeating: AudioDeviceID(), count: deviceCount)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize,
            &deviceIDs
        ) == noErr else {
            return []
        }

        return deviceIDs
    }

    private static func hasInputStreams(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize) == noErr else {
            return false
        }

        let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(dataSize))
        defer {
            bufferList.deallocate()
        }

        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, bufferList) == noErr else {
            return false
        }

        let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
        return buffers.contains { $0.mNumberChannels > 0 }
    }

    private static func audioCaptureDeviceUIDs() -> Set<String> {
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )
        return Set(session.devices.map(\.uniqueID))
    }

    private static func compactedDeviceText(_ text: String) -> String {
        String(text.lowercased().filter { $0.isLetter || $0.isNumber })
    }

    private static func stringProperty(
        _ selector: AudioObjectPropertySelector,
        for deviceID: AudioDeviceID,
        scope: AudioObjectPropertyScope
    ) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )

        var property: Unmanaged<CFString>?
        var dataSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &property) == noErr else {
            return nil
        }

        return property?.takeUnretainedValue() as String?
    }
}
