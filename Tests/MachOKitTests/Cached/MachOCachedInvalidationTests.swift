//
//  MachOCachedInvalidationTests.swift
//  MachOKitTests
//
//  After invalidation the cache must rebuild to the same values.
//

import XCTest
@testable import MachOKit

final class MachOCachedInvalidationTests: XCTestCase {

    func testInvalidateAllRecomputes() throws {
        let machO = try MachOCachedTestSupport.loadMachOFile()
        let cached = machO.cached

        let rebasesBefore = cached.rebases.count
        let symbolsBefore = Array(cached.symbols).count
        let stringsBefore = cached.allCStrings.count

        cached.invalidate()

        XCTAssertEqual(cached.rebases.count, rebasesBefore)
        XCTAssertEqual(Array(cached.symbols).count, symbolsBefore)
        XCTAssertEqual(cached.allCStrings.count, stringsBefore)
    }

    func testInvalidateChainedFixupsCacheRecomputes() throws {
        let machO = try MachOCachedTestSupport.loadMachOFile()
        let offsets = Array(machO.cached.fixupPointers.keys.prefix(200))
        guard let offset = offsets.first else { throw XCTSkip("No chained fixups") }

        let resolveBefore = machO.resolveRebase(at: UInt64(offset))
        let countBefore = machO.cached.fixupPointers.count

        // Existing public API — must keep working and forward to the new store.
        machO.invalidateChainedFixupsCache()

        XCTAssertEqual(machO.resolveRebase(at: UInt64(offset)), resolveBefore)
        XCTAssertEqual(machO.cached.fixupPointers.count, countBefore)
    }
}
