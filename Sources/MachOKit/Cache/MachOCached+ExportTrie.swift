//
//  MachOCached+ExportTrie.swift
//  MachOKit
//
//  Created for the `.cached` view feature.
//

import Foundation

// Cached export-symbol lookup. `exportedSymbols` is already memoized; this
// builds a `name -> ExportedSymbol` index over it once, so a repeated by-name
// lookup is O(1) instead of walking the export trie from its root on every
// `exportTrie?.search(by:)` call. For a `MachOFile` that also avoids the
// repeated trie traversal the search would otherwise perform.
extension MachOCached {
    /// `name -> ExportedSymbol` index over ``exportedSymbols``, built once.
    var cachedExportedSymbolsByName: [String: ExportedSymbol] {
        storage.memoized(\.exportedSymbolsByName) {
            let exportedSymbols = self.exportedSymbols
            var index: [String: ExportedSymbol] = [:]
            index.reserveCapacity(exportedSymbols.count)
            for symbol in exportedSymbols {
                index[symbol.name] = symbol
            }
            return index
        }
    }

    /// Cached equivalent of `machO.exportTrie?.search(by: name)`.
    ///
    /// Builds a `name -> ExportedSymbol` index once from the (already cached)
    /// ``exportedSymbols``; afterwards each lookup is O(1) instead of walking
    /// the export trie from its root on every call.
    ///
    /// - Parameter name: The full exported symbol name to look up.
    /// - Returns: The matching exported symbol, or `nil` if no symbol is
    ///   exported under that name.
    public func exportedSymbol(named name: String) -> ExportedSymbol? {
        cachedExportedSymbolsByName[name]
    }
}
