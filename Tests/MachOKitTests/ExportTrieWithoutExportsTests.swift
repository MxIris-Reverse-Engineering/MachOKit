import XCTest
@testable import MachOKit

/// An image that exports nothing describes its export trie as offset 0,
/// size 0. The iOS 15.5 simulator's UIKit is one: an umbrella that only
/// re-exports UIKitCore, linked with `LC_DYLD_INFO_ONLY`.
///
/// 0.53.0 started rejecting a link-edit read that begins before
/// `__LINKEDIT`, which offset 0 always does, and `ExportTrie` force-unwrapped
/// the read, so asking such an image for its exports trapped. `swift-section`
/// asks every image of a dependency closure while it looks for an
/// Objective-C superclass, and crashed on SwiftUI and WidgetKit of that
/// runtime.
///
/// The file below mirrors that image's shape: `__TEXT` from offset 0,
/// `__LINKEDIT` after it, and an `LC_DYLD_INFO_ONLY` whose offsets and sizes
/// are all 0.
final class ExportTrieWithoutExportsTests: XCTestCase {
    private static let linkEditFileOffset: UInt64 = 0x4000
    private static let linkEditFileSize: UInt64 = 0x10

    private static func makeImage() -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: Int(linkEditFileOffset + linkEditFileSize))
        func write<Value: FixedWidthInteger>(_ value: Value, at offset: Int) {
            withUnsafeBytes(of: value.littleEndian) { source in
                for (index, byte) in source.enumerated() {
                    bytes[offset + index] = byte
                }
            }
        }
        func writeSegment(
            named name: String,
            at offset: Int,
            address: UInt64,
            fileOffset: UInt64,
            fileSize: UInt64,
            protection: Int32
        ) {
            write(UInt32(0x19), at: offset) // LC_SEGMENT_64
            write(UInt32(72), at: offset + 4) // cmdsize
            for (index, byte) in name.utf8.enumerated() {
                bytes[offset + 8 + index] = byte // segname
            }
            write(address, at: offset + 24) // vmaddr
            write(UInt64(0x4000), at: offset + 32) // vmsize
            write(fileOffset, at: offset + 40) // fileoff
            write(fileSize, at: offset + 48) // filesize
            write(protection, at: offset + 56) // maxprot
            write(protection, at: offset + 60) // initprot
        }

        // mach_header_64
        write(UInt32(0xFEED_FACF), at: 0) // MH_MAGIC_64
        write(UInt32(0x0100_000C), at: 4) // CPU_TYPE_ARM64
        write(UInt32(6), at: 12) // MH_DYLIB
        write(UInt32(3), at: 16) // ncmds
        write(UInt32(72 + 72 + 48), at: 20) // sizeofcmds

        writeSegment(
            named: "__TEXT",
            at: 32,
            address: 0,
            fileOffset: 0,
            fileSize: linkEditFileOffset,
            protection: 5
        )
        writeSegment(
            named: "__LINKEDIT",
            at: 104,
            address: linkEditFileOffset,
            fileOffset: linkEditFileOffset,
            fileSize: linkEditFileSize,
            protection: 1
        )

        // dyld_info_command: every offset and size stays 0
        write(UInt32(0x8000_0022), at: 176) // LC_DYLD_INFO_ONLY
        write(UInt32(48), at: 180) // cmdsize

        return bytes
    }

    func testAnImageWithoutAnExportTrieExportsNothing() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExportTrieWithoutExports-\(UUID().uuidString).dylib")
        try Data(Self.makeImage()).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let machO = try MachOFile(url: url)
        let dyldInfo = try XCTUnwrap(
            machO.loadCommands.info(of: LoadCommand.dyldInfoOnly),
            "the image must be read through LC_DYLD_INFO_ONLY"
        )
        XCTAssertEqual(dyldInfo.layout.export_off, 0)
        XCTAssertEqual(dyldInfo.layout.export_size, 0)

        XCTAssertNil(machO.exportTrie?.search(by: "_UIApplicationMain"))
        XCTAssertTrue(machO.exportedSymbols.isEmpty)
    }
}
