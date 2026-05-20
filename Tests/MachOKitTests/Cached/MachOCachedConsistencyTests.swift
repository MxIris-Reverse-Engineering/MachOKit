//
//  MachOCachedConsistencyTests.swift
//  MachOKitTests
//
//  A `machO.cached.X` value must equal the corresponding `machO.X` value.
//

import XCTest
@testable import MachOKit

final class MachOCachedConsistencyTests: XCTestCase {

    func testMachOFileMirrorsBase() throws {
        let machO = try MachOCachedTestSupport.loadMachOFile()
        let cached = machO.cached

        XCTAssertEqual(Array(cached.loadCommands).count, Array(machO.loadCommands).count)
        XCTAssertEqual(cached.segments.count, machO.segments.count)
        XCTAssertEqual(cached.sections.count, machO.sections.count)
        XCTAssertEqual(cached.sections64.count, machO.sections64.count)
        XCTAssertEqual(cached.rpaths, machO.rpaths)
        XCTAssertEqual(cached.dependencies.count, machO.dependencies.count)
        XCTAssertEqual(Array(cached.symbols).count, Array(machO.symbols).count)
        XCTAssertEqual(cached.exportedSymbols.count, machO.exportedSymbols.count)
        XCTAssertEqual(cached.rebases.count, machO.rebases.count)
        XCTAssertEqual(cached.bindingSymbols.count, machO.bindingSymbols.count)
        XCTAssertEqual(cached.weakBindingSymbols.count, machO.weakBindingSymbols.count)
        XCTAssertEqual(cached.lazyBindingSymbols.count, machO.lazyBindingSymbols.count)
        XCTAssertEqual(cached.allCStrings.count, machO.allCStrings.count)
        XCTAssertEqual(cached.allCStringTables.count, machO.allCStringTables.count)
        XCTAssertEqual(cached.dyldChainedFixups != nil, machO.dyldChainedFixups != nil)
        XCTAssertEqual(cached.codeSign != nil, machO.codeSign != nil)
        XCTAssertEqual(cached.symbolStrings != nil, machO.symbolStrings != nil)
        XCTAssertEqual(cached.functionStarts != nil, machO.functionStarts != nil)
        XCTAssertEqual(cached.exportTrie != nil, machO.exportTrie != nil)
        XCTAssertEqual(cached.embeddedInfoPlist != nil, machO.embeddedInfoPlist != nil)
    }

    func testMachOFileCacheHitIsStable() throws {
        let machO = try MachOCachedTestSupport.loadMachOFile()
        let cached = machO.cached
        // Second access is a cache hit and must equal the first.
        XCTAssertEqual(cached.rebases.count, cached.rebases.count)
        XCTAssertEqual(cached.allCStrings, cached.allCStrings)
    }

    func testMachOFileClosestSymbol() throws {
        let machO = try MachOCachedTestSupport.loadMachOFile()
        let cached = machO.cached
        guard let probe = Array(machO.symbols).first(where: { $0.offset > 0 }) else {
            throw XCTSkip("No usable symbols")
        }
        XCTAssertEqual(
            cached.closestSymbol(at: probe.offset)?.offset,
            machO.closestSymbol(at: probe.offset)?.offset
        )
    }

    func testMachOFileSymbolsNamed() throws {
        let machO = try MachOCachedTestSupport.loadMachOFile()
        let cached = machO.cached
        guard let named = Array(machO.symbols).first(where: { !$0.name.isEmpty }) else {
            throw XCTSkip("No named symbols")
        }
        XCTAssertEqual(
            cached.symbols(named: named.name).count,
            machO.symbols(named: named.name).count
        )
    }

    func testMachOFileResolveMatchesLegacyEntryPoint() throws {
        let machO = try MachOCachedTestSupport.loadMachOFile()
        let cached = machO.cached
        let offsets = Array(cached.fixupPointers.keys.prefix(200))
        guard !offsets.isEmpty else { throw XCTSkip("No chained fixups") }
        for offset in offsets {
            XCTAssertEqual(
                machO.resolveRebase(at: UInt64(offset)),
                cached.resolveRebase(at: UInt64(offset))
            )
        }
    }
}

#if canImport(Darwin)
extension MachOCachedConsistencyTests {
    func testMachOImageMirrorsBase() {
        let machO = MachOImage.current()
        let cached = machO.cached

        XCTAssertEqual(Array(cached.loadCommands).count, Array(machO.loadCommands).count)
        XCTAssertEqual(cached.segments.count, machO.segments.count)
        XCTAssertEqual(cached.sections.count, machO.sections.count)
        XCTAssertEqual(cached.rpaths, machO.rpaths)
        XCTAssertEqual(cached.dependencies.count, machO.dependencies.count)
        XCTAssertEqual(Array(cached.symbols).count, Array(machO.symbols).count)
        XCTAssertEqual(cached.exportedSymbols.count, machO.exportedSymbols.count)
        XCTAssertEqual(cached.rebases.count, machO.rebases.count)
        XCTAssertEqual(cached.bindingSymbols.count, machO.bindingSymbols.count)
        XCTAssertEqual(cached.dyldChainedFixups != nil, machO.dyldChainedFixups != nil)
    }

    func testMachOImageClosestSymbol() throws {
        let machO = MachOImage.current()
        let cached = machO.cached
        guard let probe = Array(machO.symbols).first(where: { $0.offset > 0 }) else {
            throw XCTSkip("No usable symbols")
        }
        XCTAssertEqual(
            cached.closestSymbol(at: probe.offset)?.offset,
            machO.closestSymbol(at: probe.offset)?.offset
        )
    }
}
#endif
