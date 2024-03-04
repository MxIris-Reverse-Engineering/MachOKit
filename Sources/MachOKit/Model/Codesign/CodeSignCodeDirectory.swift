//
//  CodeSignCodeDirectory.swift
//
//
//  Created by p-x9 on 2024/03/03.
//  
//

import Foundation
import MachOKitC

public struct CodeSignCodeDirectory: LayoutWrapper {
    public typealias Layout = CS_CodeDirectory

    public var layout: Layout
    public let offset: Int // offset from start of linkedit_data
}

extension CodeSignCodeDirectory {
    public var magic: CodeSignMagic! {
        .init(rawValue: layout.magic)
    }

    public var hashType: CodeSignHashType! {
        .init(rawValue: UInt32(layout.hashType))
    }

    public func identifier(in signature: MachOFile.CodeSign) -> String {
        signature.data.withUnsafeBytes {
            bufferPointer in
            guard let baseAddress = bufferPointer.baseAddress else {
                return ""
            }
            return String(
                cString: baseAddress
                    .advanced(by: offset)
                    .advanced(by: numericCast(layout.identOffset))
                    .assumingMemoryBound(to: CChar.self)
            )
        }
    }
}

extension CS_CodeDirectory {
    var isSwapped: Bool {
        magic < 0xfade0000
    }
    
    var swapped: CS_CodeDirectory {
        .init(
            magic: magic.byteSwapped,
            length: length.byteSwapped,
            version: version.byteSwapped,
            flags: flags.byteSwapped,
            hashOffset: hashOffset.byteSwapped,
            identOffset: identOffset.byteSwapped,
            nSpecialSlots: nSpecialSlots.byteSwapped,
            nCodeSlots: nCodeSlots.byteSwapped,
            codeLimit: codeLimit.byteSwapped,
            hashSize: hashSize.byteSwapped,
            hashType: hashType.byteSwapped,
            platform: platform.byteSwapped,
            pageSize: pageSize.byteSwapped,
            spare2: spare2.byteSwapped
        )
    }
}
