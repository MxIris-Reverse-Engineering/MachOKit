//
//  MachOCached.swift
//  MachOKit
//
//  Created for the `.cached` view feature.
//

import Foundation

/// A concurrency-safe, caching view over a `MachOFile` or `MachOImage`.
///
/// Obtained via `machO.cached`. Every heavy property is parsed once and then
/// memoized — `machO.cached.symbols` mirrors `machO.symbols` (same name, same
/// return type) and can replace it directly.
///
/// `MachOCached` is a lightweight value type: it holds the `base` and a
/// reference to a shared ``MachOCacheStorage``. It deliberately does **not**
/// conform to `MachORepresentable`; it simply mirrors that protocol's members.
public struct MachOCached<Base: MachORepresentable> {
    /// The underlying Mach-O this view caches.
    public let base: Base

    let storage: MachOCacheStorage<Base>

    init(base: Base, storage: MachOCacheStorage<Base>) {
        self.base = base
        self.storage = storage
    }

    /// Invalidates every cached value behind this view.
    ///
    /// Call after the underlying data has changed. For `MachOFile` the cache is
    /// tied to the file instance; for `MachOImage` it is shared by every copy
    /// of the same image value.
    public func invalidate() {
        storage.invalidateAll()
    }
}

// MARK: - Pass-through members (cheap — forwarded directly to `base`)

extension MachOCached {
    public var is64Bit: Bool { base.is64Bit }
    public var headerSize: Int { base.headerSize }
    public var header: MachHeader { base.header }
    public var endian: Endian { base.endian }

    public func contains(unslidAddress address: UInt64) -> Bool {
        base.contains(unslidAddress: address)
    }

    public func stripPointerTags(of rawVMAddr: UInt64) -> UInt64 {
        base.stripPointerTags(of: rawVMAddr)
    }
}

// MARK: - Cached members

extension MachOCached {
    public var loadCommands: Base.LoadCommands {
        storage.memoized(\.loadCommands) { base.loadCommands }
    }

    public var rpaths: [String] {
        storage.memoized(\.rpaths) { base.rpaths }
    }

    public var dependencies: [DependedDylib] {
        storage.memoized(\.dependencies) { base.dependencies }
    }

    public var segments: [any SegmentCommandProtocol] {
        storage.memoized(\.segments) { base.segments }
    }

    /// Lazy sequence — forwarded directly (no materialized result to cache).
    public var segments64: AnySequence<SegmentCommand64> { base.segments64 }
    /// Lazy sequence — forwarded directly (no materialized result to cache).
    public var segments32: AnySequence<SegmentCommand> { base.segments32 }

    public var sections: [any SectionProtocol] {
        storage.memoized(\.sections) { base.sections }
    }

    public var sections64: [Section64] {
        storage.memoized(\.sections64) { base.sections64 }
    }

    public var sections32: [Section] {
        storage.memoized(\.sections32) { base.sections32 }
    }

    public var symbols: AnyRandomAccessCollection<Base.Symbol> {
        AnyRandomAccessCollection(cachedSymbolsArray)
    }

    public var symbols64: Base.Symbols64? {
        storage.memoized(\.symbols64) { base.symbols64 }
    }

    public var symbols32: Base.Symbols? {
        storage.memoized(\.symbols32) { base.symbols32 }
    }

    public var indirectSymbols: Base.IndirectSymbols? {
        storage.memoized(\.indirectSymbols) { base.indirectSymbols }
    }

    public var symbolStrings: Base.Strings? {
        storage.memoized(\.symbolStrings) { base.symbolStrings }
    }

    public var cStrings: Base.Strings? {
        storage.memoized(\.cStrings) { base.cStrings }
    }

    public var allCStringTables: [Base.Strings] {
        storage.memoized(\.allCStringTables) { base.allCStringTables }
    }

    public var allCStrings: [String] {
        storage.memoized(\.allCStrings) { base.allCStrings }
    }

    public var uStrings: Base.UTF16Strings? {
        storage.memoized(\.uStrings) { base.uStrings }
    }

    /// Mirrors the `MachORepresentable.cfStrings` default implementation —
    /// keep in sync with it.
    public var cfStrings: [any CFStringProtocol]? {
        if is64Bit {
            cfStrings64?.map { $0 as (any CFStringProtocol) }
        } else {
            cfStrings32?.map { $0 as (any CFStringProtocol) }
        }
    }

    public var cfStrings64: Base.CFStrings64? {
        storage.memoized(\.cfStrings64) { base.cfStrings64 }
    }

    public var cfStrings32: Base.CFStrings32? {
        storage.memoized(\.cfStrings32) { base.cfStrings32 }
    }

    public var embeddedInfoPlist: [String: Any]? {
        storage.memoized(\.embeddedInfoPlist) { base.embeddedInfoPlist }
    }

    public var rebaseOperations: Base.RebaseOperations? {
        storage.memoized(\.rebaseOperations) { base.rebaseOperations }
    }

    public var bindOperations: Base.BindOperations? {
        storage.memoized(\.bindOperations) { base.bindOperations }
    }

    public var weakBindOperations: Base.BindOperations? {
        storage.memoized(\.weakBindOperations) { base.weakBindOperations }
    }

    public var lazyBindOperations: Base.BindOperations? {
        storage.memoized(\.lazyBindOperations) { base.lazyBindOperations }
    }

    public var exportTrie: Base.ExportTrie? {
        storage.memoized(\.exportTrie) { base.exportTrie }
    }

    public var exportedSymbols: [ExportedSymbol] {
        storage.memoized(\.exportedSymbols) { base.exportedSymbols }
    }

    public var bindingSymbols: [BindingSymbol] {
        storage.memoized(\.bindingSymbols) { base.bindingSymbols }
    }

    public var weakBindingSymbols: [BindingSymbol] {
        storage.memoized(\.weakBindingSymbols) { base.weakBindingSymbols }
    }

    public var lazyBindingSymbols: [BindingSymbol] {
        storage.memoized(\.lazyBindingSymbols) { base.lazyBindingSymbols }
    }

    public var rebases: [Rebase] {
        storage.memoized(\.rebases) { base.rebases }
    }

    public var functionStarts: Base.FunctionStarts? {
        storage.memoized(\.functionStarts) { base.functionStarts }
    }

    public var dataInCode: Base.DataInCode? {
        storage.memoized(\.dataInCode) { base.dataInCode }
    }

    public var dyldChainedFixups: Base.DyldChainedFixups? {
        storage.memoized(\.dyldChainedFixups) { base.dyldChainedFixups }
    }

    public var externalRelocations: Base.ExternalRelocations? {
        storage.memoized(\.externalRelocations) { base.externalRelocations }
    }

    public var classicBindingSymbols: [ClassicBindingSymbol]? {
        storage.memoized(\.classicBindingSymbols) { base.classicBindingSymbols }
    }

    public var classicLazyBindingSymbols: [ClassicBindingSymbol]? {
        storage.memoized(\.classicLazyBindingSymbols) { base.classicLazyBindingSymbols }
    }

    public var codeSign: Base.CodeSign? {
        storage.memoized(\.codeSign) { base.codeSign }
    }

    /// Mirrors the `MachORepresentable.expectedMachOFileSize` default
    /// implementation — keep in sync with it.
    public var expectedMachOFileSize: Int? {
        guard let segment = segments.max(
            by: { lhs, rhs in lhs.fileOffset < rhs.fileOffset }
        ) else { return nil }
        return segment.fileOffset + segment.fileSize
    }
}

// MARK: - Internal: materialized symbol array

extension MachOCached {
    /// Materialized symbol array — shared backing for the parameterized symbol
    /// lookups in MachOCached+SymbolLookup.swift. Building it once removes the
    /// repeated `Array(symbols)` cost those algorithms otherwise pay.
    var cachedSymbolsArray: [Base.Symbol] {
        storage.memoized(\.symbolsArray) { Array(base.symbols) }
    }
}
