//
//  MachOCachedConcurrencyTests.swift
//  MachOKitTests
//
//  Many threads hammer the same `.cached` view, racing first-time
//  computation. Passing means no crash and results that survive the race.
//

import XCTest
import Foundation
@testable import MachOKit

final class MachOCachedConcurrencyTests: XCTestCase {

    func testMachOFileConcurrentPropertyAccess() throws {
        let machO = try MachOCachedTestSupport.loadMachOFile()
        let cached = machO.cached

        DispatchQueue.concurrentPerform(iterations: 256) { _ in
            _ = Array(cached.loadCommands).count
            _ = cached.segments.count
            _ = cached.sections.count
            _ = Array(cached.symbols).count
            _ = cached.rebases.count
            _ = cached.bindingSymbols.count
            _ = cached.exportedSymbols.count
            _ = cached.allCStrings.count
            _ = cached.dyldChainedFixups != nil
        }

        XCTAssertEqual(Array(cached.loadCommands).count, Array(machO.loadCommands).count)
        XCTAssertEqual(Array(cached.symbols).count, Array(machO.symbols).count)
        XCTAssertEqual(cached.rebases.count, machO.rebases.count)
        XCTAssertEqual(cached.exportedSymbols.count, machO.exportedSymbols.count)
    }

    func testMachOFileConcurrentChainedFixups() throws {
        let machO = try MachOCachedTestSupport.loadMachOFile()
        let offsets = Array(machO.cached.fixupPointers.keys.prefix(800))
        guard !offsets.isEmpty else { throw XCTSkip("No chained fixups") }

        // A fresh instance, so the fixup-pointer map is built under contention.
        let fresh = try MachOCachedTestSupport.loadMachOFile()
        let freshCached = fresh.cached
        DispatchQueue.concurrentPerform(iterations: offsets.count) { i in
            let offset = UInt64(offsets[i])
            _ = freshCached.resolveRebase(at: offset)
            _ = freshCached.resolveOptionalRebase(at: offset)
            _ = freshCached.resolveBind(at: offset)
            _ = freshCached.fixupPointer(at: offsets[i])
        }
        XCTAssertEqual(freshCached.fixupPointers.count, machO.cached.fixupPointers.count)
    }

    #if canImport(Darwin)
    func testMachOImageConcurrentPropertyAccess() {
        let machO = MachOImage.current()
        let cached = machO.cached

        DispatchQueue.concurrentPerform(iterations: 256) { _ in
            _ = Array(cached.loadCommands).count
            _ = cached.segments.count
            _ = Array(cached.symbols).count
            _ = cached.rebases.count
            _ = cached.exportedSymbols.count
        }

        XCTAssertEqual(Array(cached.symbols).count, Array(machO.symbols).count)
        XCTAssertEqual(cached.rebases.count, machO.rebases.count)
    }
    #endif
}
