import XCTest
@testable import MachOKit

/// A cache's file handle identity was the value of a weak-to-strong
/// `NSMapTable` keyed by the handle. Such a table keeps the value of a key
/// that went away until it next resizes, so the identity of a dropped cache
/// lived on — and with it whatever a client keyed on it: MachOObjCSection maps
/// the cache's file once per identity, and opening a sub-cache per read left
/// hundreds of mappings of one file behind.
final class FileHandleIdentityLifetimeTests: XCTestCase {
    private func hostCacheURL() throws -> URL {
        try XCTUnwrap(DyldCache.host?.url)
    }

    func testDroppedCacheReleasesItsFileHandleIdentity() throws {
        let url = try hostCacheURL()
        weak var droppedIdentity: FileHandleIdentityBox?
        do {
            let cache = try DyldCache(url: url)
            droppedIdentity = cache._fileHandleIdentity
        }

        XCTAssertNil(droppedIdentity)
    }

    /// Caches assembled from one `FullDyldCache` share its open files, so a
    /// client keyed on the identity must see one key for all of them.
    func testCachesSharingAFileShareItsIdentity() throws {
        let fullCache = try XCTUnwrap(FullDyldCache.host)
        let firstAssembly: [DyldCache] = fullCache.subCaches
        let secondAssembly: [DyldCache] = fullCache.subCaches
        try XCTSkipIf(firstAssembly.isEmpty, "the host cache has no sub-caches")

        XCTAssertTrue(firstAssembly[0]._fileHandleIdentity === secondAssembly[0]._fileHandleIdentity)
    }
}
