//
//  MachOCachedTestSupport.swift
//  MachOKitTests
//

import Foundation
import XCTest
@testable import MachOKit

enum MachOCachedTestSupport {
    /// A system binary used as the `MachOFile` fixture (same one the existing
    /// print tests load).
    static let machOFilePath = "/System/Applications/Freeform.app/Contents/MacOS/Freeform"

    /// Loads the fixture as a `MachOFile` (first slice when it is a fat binary).
    static func loadMachOFile() throws -> MachOFile {
        let url = URL(fileURLWithPath: machOFilePath)
        let file = try MachOKit.loadFromFile(url: url)
        switch file {
        case let .fat(fatFile):
            let machOs = try fatFile.machOFiles()
            guard let first = machOs.first else {
                throw XCTSkip("Fat file '\(machOFilePath)' has no Mach-O slices")
            }
            return first
        case let .machO(machO):
            return machO
        }
    }
}
