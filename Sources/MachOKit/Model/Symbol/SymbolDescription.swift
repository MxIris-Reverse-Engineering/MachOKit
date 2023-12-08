//
//  SymbolDescription.swift
//  
//
//  Created by p-x9 on 2023/12/08.
//  
//

import Foundation

public struct SymbolDescription: OptionSet {
    public typealias RawValue = Int32

    public let rawValue: RawValue

    public var referenceFlag: SymbolReferenceFlag? {
        .init(rawValue: rawValue & REFERENCE_TYPE)
    }

    public var libraryOrdinal: LibraryOrdinal? {
        .init(rawValue: (rawValue >> 8) & 0xff)
    }

    public init(rawValue: RawValue) {
        self.rawValue = rawValue
    }
}

extension SymbolDescription {
    public static let referenced_dynamically = SymbolDescription(
        rawValue: Bit.referenced_dynamically.rawValue
    )
    public static let no_dead_strip = SymbolDescription(
        rawValue: Bit.no_dead_strip.rawValue
    )
    public static let desc_discarded = SymbolDescription(
        rawValue: Bit.desc_discarded.rawValue
    )
    public static let weak_ref = SymbolDescription(
        rawValue: Bit.weak_ref.rawValue
    )
    public static let weak_def = SymbolDescription(
        rawValue: Bit.weak_def.rawValue
    )
    public static let ref_to_weak = SymbolDescription(
        rawValue: Bit.ref_to_weak.rawValue
    )
    public static let arm_thumb_def = SymbolDescription(
        rawValue: Bit.arm_thumb_def.rawValue
    )
    public static let symbol_resolver = SymbolDescription(
        rawValue: Bit.symbol_resolver.rawValue
    )
    public static let alt_entry = SymbolDescription(
        rawValue: Bit.alt_entry.rawValue
    )
    public static let cold_func = SymbolDescription(
        rawValue: Bit.cold_func.rawValue
    )
}

extension SymbolDescription {
    public var bits: [Bit] {
        SymbolDescription.Bit.allCases
            .lazy
            .filter {
                contains(.init(rawValue: $0.rawValue))
            }
    }
}

extension SymbolDescription {
    public enum Bit: CaseIterable {
        case referenced_dynamically
        case no_dead_strip
        case desc_discarded
        case weak_ref
        case weak_def
        case ref_to_weak
        case arm_thumb_def
        case symbol_resolver
        case alt_entry
        case cold_func
    }
}

extension SymbolDescription.Bit: RawRepresentable {
    public typealias RawValue = Int32

    public init?(rawValue: RawValue) {
        switch rawValue {
        case RawValue(REFERENCED_DYNAMICALLY): self = .referenced_dynamically
        case RawValue(N_NO_DEAD_STRIP): self = .no_dead_strip
        case RawValue(N_DESC_DISCARDED): self = .desc_discarded
        case RawValue(N_WEAK_REF): self = .weak_ref
        case RawValue(N_WEAK_DEF): self = .weak_def
        case RawValue(N_REF_TO_WEAK): self = .ref_to_weak
        case RawValue(N_ARM_THUMB_DEF): self = .arm_thumb_def
        case RawValue(N_SYMBOL_RESOLVER): self = .symbol_resolver
        case RawValue(N_ALT_ENTRY): self = .alt_entry
        case RawValue(N_COLD_FUNC): self = .cold_func
        default: return nil
        }
    }
    public var rawValue: RawValue {
        switch self {
        case .referenced_dynamically: RawValue(REFERENCED_DYNAMICALLY)
        case .no_dead_strip: RawValue(N_NO_DEAD_STRIP)
        case .desc_discarded: RawValue(N_DESC_DISCARDED)
        case .weak_ref: RawValue(N_WEAK_REF)
        case .weak_def: RawValue(N_WEAK_DEF)
        case .ref_to_weak: RawValue(N_REF_TO_WEAK)
        case .arm_thumb_def: RawValue(N_ARM_THUMB_DEF)
        case .symbol_resolver: RawValue(N_SYMBOL_RESOLVER)
        case .alt_entry: RawValue(N_ALT_ENTRY)
        case .cold_func: RawValue(N_COLD_FUNC)
        }
    }
}

extension SymbolDescription.Bit: CustomStringConvertible {
    public var description: String {
        switch self {
        case .referenced_dynamically: "REFERENCED_DYNAMICALLY"
        case .no_dead_strip: "N_NO_DEAD_STRIP"
        case .desc_discarded: "N_DESC_DISCARDED"
        case .weak_ref: "N_WEAK_REF"
        case .weak_def: "N_WEAK_DEF"
        case .ref_to_weak: "N_REF_TO_WEAK"
        case .arm_thumb_def: "N_ARM_THUMB_DEF"
        case .symbol_resolver: "N_SYMBOL_RESOLVER"
        case .alt_entry: "N_ALT_ENTRY"
        case .cold_func: "N_COLD_FUNC"
        }
    }
}
