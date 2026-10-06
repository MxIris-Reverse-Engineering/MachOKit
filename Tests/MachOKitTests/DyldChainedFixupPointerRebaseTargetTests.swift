import XCTest
@testable import MachOKit

/// Slide info decodes whatever bytes sit at the offset it is asked about. At an
/// offset that holds no pointer — the macOS 13.5 dyld cache keeps `0xa9` at
/// file offset 0x59BEA800, where swift-section came looking for a class's data
/// pointer — the decoded target lies below the load address, and subtracting
/// the load address from it trapped the host process. Such a pointer now
/// reports that it has no runtime offset.
final class DyldChainedFixupPointerRebaseTargetTests: XCTestCase {
    private static let sharedRegionStart: UInt64 = 0x1_8000_0000

    /// The cache overloads take a cache they never read; any will do.
    private func anyCache() throws -> DyldCache {
        try XCTUnwrap(DyldCache.host)
    }

    func testArm64eRebaseBelowTheLoadAddressHasNoRuntimeOffset() throws {
        let pointer = DyldChainedFixupPointer(offset: 0, fixupInfo: .arm64e(.init(rawValue: 0xa9)))

        XCTAssertNil(pointer.rebaseTargetRuntimeOffset(for: try anyCache(), preferedLoadAddress: Self.sharedRegionStart))
    }

    func testArm64eRebaseAboveTheLoadAddressKeepsItsRuntimeOffset() throws {
        let pointer = DyldChainedFixupPointer(offset: 0, fixupInfo: .arm64e(.init(rawValue: Self.sharedRegionStart + 0x1000)))

        XCTAssertEqual(pointer.rebaseTargetRuntimeOffset(for: try anyCache(), preferedLoadAddress: Self.sharedRegionStart), 0x1000)
    }

    func testGeneral64RebaseBelowTheLoadAddressHasNoRuntimeOffset() throws {
        let pointer = DyldChainedFixupPointer(offset: 0, fixupInfo: ._64(.init(rawValue: 0xa9)))

        XCTAssertNil(pointer.rebaseTargetRuntimeOffset(for: try anyCache(), preferedLoadAddress: Self.sharedRegionStart))
    }

    func testGeneral32RebaseBelowTheLoadAddressHasNoRuntimeOffset() throws {
        let pointer = DyldChainedFixupPointer(offset: 0, fixupInfo: ._32(.init(rawValue: 0xa9)))

        XCTAssertNil(pointer.rebaseTargetRuntimeOffset(for: try anyCache(), preferedLoadAddress: 0x1000))
    }

    func testGeneral32FirmwareRebaseBelowTheLoadAddressHasNoRuntimeOffset() throws {
        let pointer = DyldChainedFixupPointer(offset: 0, fixupInfo: ._32_firmware(.init(rawValue: 0xa9)))

        XCTAssertNil(pointer.rebaseTargetRuntimeOffset(for: try anyCache(), preferedLoadAddress: 0x1000))
    }

    /// `targetSegIndex` is 4 bits wide, so a slot holding no pointer can name
    /// a segment the image does not have; indexing the segments with it
    /// trapped the same way.
    func testSegmentedRebaseIntoAMissingSegmentHasNoRuntimeOffset() throws {
        // A split cache's main file holds no image; the full cache reaches
        // the ones in its subcaches.
        let machO = try XCTUnwrap(FullDyldCache.host?.machOFiles().first { _ in true })
        let missingSegmentIndex: UInt64 = 0xF
        XCTAssertLessThan(machO.segments.count, Int(missingSegmentIndex) + 1)
        let pointer = DyldChainedFixupPointer(offset: 0, fixupInfo: .arm64e_segmented(.init(rawValue: missingSegmentIndex << 28)))

        XCTAssertNil(pointer.rebaseTargetRuntimeOffset(for: machO, preferedLoadAddress: 0))
    }
}
