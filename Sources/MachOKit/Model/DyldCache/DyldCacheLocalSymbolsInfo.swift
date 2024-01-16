//
//  DyldCacheLocalSymbolsInfo.swift
//
//
//  Created by p-x9 on 2024/01/15.
//  
//

import Foundation

public struct DyldCacheLocalSymbolsInfo: LayoutWrapper {
    public typealias Layout = dyld_cache_local_symbols_info

    public var layout: Layout
}

extension DyldCacheLocalSymbolsInfo {
    public func symbols64(in cache: DyldCache) -> MachOFile.Symbols64? {
        guard cache.cpu.is64Bit else { return nil }

        cache.fileHandle.seek(
            toFileOffset: cache.header.localSymbolsOffset + numericCast(layout.stringsOffset)
        )
        let stringData = cache.fileHandle.readData(
            ofLength: numericCast(layout.stringsSize)
        )

        cache.fileHandle.seek(
            toFileOffset: cache.header.localSymbolsOffset + numericCast(layout.nlistOffset)
        )
        let symbolData = cache.fileHandle.readData(
            ofLength: numericCast(Nlist64.layoutSize) * numericCast(layout.nlistCount)
        )

        return MachOFile.Symbols64(
            stringData: stringData,
            symbolsData: symbolData,
            numberOfSymbols: numericCast(layout.nlistCount)
        )
    }

    public func symbols32(in cache: DyldCache) -> MachOFile.Symbols? {
        guard !cache.cpu.is64Bit else { return nil }

        cache.fileHandle.seek(
            toFileOffset: cache.header.localSymbolsOffset + numericCast(layout.stringsOffset)
        )
        let stringData = cache.fileHandle.readData(
            ofLength: numericCast(layout.stringsSize)
        )

        cache.fileHandle.seek(
            toFileOffset: cache.header.localSymbolsOffset + numericCast(layout.nlistOffset)
        )
        let symbolData = cache.fileHandle.readData(
            ofLength: numericCast(Nlist.layoutSize) * numericCast(layout.nlistCount)
        )

        return MachOFile.Symbols(
            stringData: stringData,
            symbolsData: symbolData,
            numberOfSymbols: numericCast(layout.nlistCount)
        )
    }

    public func symbols(in cache: DyldCache) -> AnySequence<MachOFile.Symbol> {
        if let symbols64 = symbols64(in: cache) {
            return AnySequence(symbols64)
        } else if let symbols32 = symbols32(in: cache) {
            return AnySequence(symbols32)
        } else {
            return AnySequence([])
        }
    }
}
