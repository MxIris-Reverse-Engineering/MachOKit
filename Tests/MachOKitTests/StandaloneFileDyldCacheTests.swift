import XCTest
@testable import MachOKit

/// A Mach-O file that was not read out of a dyld shared cache has no cache,
/// and asking for one must not touch the file system.
///
/// `cache` used to fall back to opening the file's URL as a dyld cache
/// whenever no cache had been handed over. For a standalone file that failed
/// every time and was never remembered, so each access mapped the whole file
/// and unmapped it again. A reader that asks for the cache on every read, to
/// find the sub-cache an offset lies in, spent most of its time there:
/// MachOSwiftSection spent two thirds of its time on the iOS 18.5 simulator's
/// SwiftUI reopening the file.
///
/// The tests open a standalone file, then put a dyld cache header at the same
/// path. The file's own mapping keeps the original bytes, so only a lookup
/// that goes back to the path can see the header.
final class StandaloneFileDyldCacheTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("StandaloneFileDyldCacheTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    /// The smallest file `MachOFile` accepts: a 64-bit arm64 dylib header
    /// with no load commands.
    private static func makeStandaloneImage() -> Data {
        var bytes = [UInt8](repeating: 0, count: 0x1000)
        func write(_ value: UInt32, at offset: Int) {
            withUnsafeBytes(of: value.littleEndian) { source in
                for (index, byte) in source.enumerated() {
                    bytes[offset + index] = byte
                }
            }
        }
        write(0xFEED_FACF, at: 0) // MH_MAGIC_64
        write(0x0100_000C, at: 4) // CPU_TYPE_ARM64
        write(6, at: 12) // MH_DYLIB
        return Data(bytes)
    }

    /// The first bytes of the host's dyld cache with its sub-cache count set
    /// to zero: enough for `DyldCache(url:)` and `FullDyldCache(url:)` to
    /// accept a file as a cache that has no sub-cache files beside it.
    private static func hostCacheHeaderBytesWithoutSubCaches() throws -> Data {
        let hostCache = try XCTUnwrap(DyldCache.host)
        let fileHandle = try FileHandle(forReadingFrom: hostCache.url)
        defer { try? fileHandle.close() }
        var headerBytes = try XCTUnwrap(fileHandle.read(upToCount: 0x10000))
        var headerLayout = hostCache.header.layout
        headerLayout.subCacheArrayCount = 0
        withUnsafeBytes(of: &headerLayout) { layoutBytes in
            headerBytes.replaceSubrange(0 ..< layoutBytes.count, with: layoutBytes)
        }
        return headerBytes
    }

    /// Opens a standalone file, then replaces what is at its path with a
    /// dyld cache header. Replacing — not overwriting — leaves the mapping
    /// the returned file reads with the original bytes. The name carries no
    /// extension, so the path `fullCache` derives from it is the path itself.
    private func makeStandaloneFileWhosePathNowNamesACache() throws -> MachOFile {
        let imageURL = temporaryDirectory.appendingPathComponent("Standalone")
        try Self.makeStandaloneImage().write(to: imageURL)
        let machO = try MachOFile(url: imageURL)
        try Self.hostCacheHeaderBytesWithoutSubCaches().write(to: imageURL, options: .atomic)
        return machO
    }

    func testStandaloneFileHasNoCache() throws {
        let machO = try makeStandaloneFileWhosePathNowNamesACache()

        XCTAssertFalse(machO.isLoadedFromDyldCache)
        XCTAssertNil(machO.cache)
    }

    func testStandaloneFileHasNoFullCache() throws {
        let machO = try makeStandaloneFileWhosePathNowNamesACache()

        XCTAssertNil(machO.fullCache)
    }

    /// The fallback still serves the files it exists for: an image of a
    /// cache opened without the cache handed over finds it through its URL.
    /// The image comes from the full cache because a recent main cache file
    /// holds no image of its own.
    @available(*, deprecated)
    func testCacheImageOpenedWithoutItsCacheStillFindsIt() throws {
        let hostCache = try XCTUnwrap(FullDyldCache.host)
        var images = hostCache.machOFiles().makeIterator()
        let image = try XCTUnwrap(images.next())
        let reopened = try MachOFile(
            url: image.url,
            imagePath: image.imagePath,
            headerStartOffsetInCache: image.headerStartOffsetInCache
        )

        XCTAssertTrue(reopened.isLoadedFromDyldCache)
        XCTAssertNotNil(reopened.cache)
    }
}
