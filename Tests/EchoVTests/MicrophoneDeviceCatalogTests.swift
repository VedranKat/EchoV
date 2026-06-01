import XCTest
@testable import EchoV

final class MicrophoneDeviceCatalogTests: XCTestCase {
    func testSystemDefaultAggregateNamesAreFilteredAcrossGeneratedIDs() {
        XCTAssertTrue(MicrophoneDeviceCatalog.isSystemDefaultAggregate(
            name: "CA default device aggregate 10165 0",
            uid: "different-generated-id"
        ))

        XCTAssertTrue(MicrophoneDeviceCatalog.isSystemDefaultAggregate(
            name: "..CA-default_device.aggregate",
            uid: "another-generated-id"
        ))
    }

    func testNamedAudioDevicesAreNotSystemDefaultAggregates() {
        XCTAssertFalse(MicrophoneDeviceCatalog.isSystemDefaultAggregate(
            name: "BlackHole 2ch",
            uid: "BlackHole2ch_UID"
        ))
    }
}
