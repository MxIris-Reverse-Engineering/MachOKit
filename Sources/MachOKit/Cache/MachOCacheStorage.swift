//
//  MachOCacheStorage.swift
//  MachOKit
//
//  Created for the `.cached` view feature.
//

import Foundation

/// Concurrency-safe backing store for a ``MachOCached`` view.
///
/// Holds one ``CacheSlot`` per heavy `MachORepresentable` API. It does **not**
/// retain the `base` value: every cached getter passes its `base`-derived
/// `compute` closure in per call. Keeping `MachOFile` / `MachOImage` -> storage
/// a one-way reference is what lets the `struct` `MachOImage` own this `class`
/// without forming a reference cycle.
///
/// All access is guarded by a single `NSLock` (portable across Apple platforms
/// and Linux/OpenBSD). Heavy computation runs *outside* the lock — see
/// ``memoized(_:_:)``.
final class MachOCacheStorage<Base: MachORepresentable> {
    private let lock = NSLock()

    // MARK: - Heavy API slots

    var loadCommands: CacheSlot<Base.LoadCommands> = .notComputed
    var rpaths: CacheSlot<[String]> = .notComputed
    var dependencies: CacheSlot<[DependedDylib]> = .notComputed
    var segments: CacheSlot<[any SegmentCommandProtocol]> = .notComputed
    var sections: CacheSlot<[any SectionProtocol]> = .notComputed
    var sections64: CacheSlot<[Section64]> = .notComputed
    var sections32: CacheSlot<[Section]> = .notComputed
    var symbols64: CacheSlot<Base.Symbols64?> = .notComputed
    var symbols32: CacheSlot<Base.Symbols?> = .notComputed
    /// Materialized symbol array — backs the parameterized symbol lookups.
    var symbolsArray: CacheSlot<[Base.Symbol]> = .notComputed
    var indirectSymbols: CacheSlot<Base.IndirectSymbols?> = .notComputed
    var symbolStrings: CacheSlot<Base.Strings?> = .notComputed
    var cStrings: CacheSlot<Base.Strings?> = .notComputed
    var allCStringTables: CacheSlot<[Base.Strings]> = .notComputed
    var allCStrings: CacheSlot<[String]> = .notComputed
    var uStrings: CacheSlot<Base.UTF16Strings?> = .notComputed
    var cfStrings64: CacheSlot<Base.CFStrings64?> = .notComputed
    var cfStrings32: CacheSlot<Base.CFStrings32?> = .notComputed
    var embeddedInfoPlist: CacheSlot<[String: Any]?> = .notComputed
    var rebaseOperations: CacheSlot<Base.RebaseOperations?> = .notComputed
    var bindOperations: CacheSlot<Base.BindOperations?> = .notComputed
    var weakBindOperations: CacheSlot<Base.BindOperations?> = .notComputed
    var lazyBindOperations: CacheSlot<Base.BindOperations?> = .notComputed
    var exportTrie: CacheSlot<Base.ExportTrie?> = .notComputed
    var exportedSymbols: CacheSlot<[ExportedSymbol]> = .notComputed
    var bindingSymbols: CacheSlot<[BindingSymbol]> = .notComputed
    var weakBindingSymbols: CacheSlot<[BindingSymbol]> = .notComputed
    var lazyBindingSymbols: CacheSlot<[BindingSymbol]> = .notComputed
    var rebases: CacheSlot<[Rebase]> = .notComputed
    var functionStarts: CacheSlot<Base.FunctionStarts?> = .notComputed
    var dataInCode: CacheSlot<Base.DataInCode?> = .notComputed
    var dyldChainedFixups: CacheSlot<Base.DyldChainedFixups?> = .notComputed
    var externalRelocations: CacheSlot<Base.ExternalRelocations?> = .notComputed
    var classicBindingSymbols: CacheSlot<[ClassicBindingSymbol]?> = .notComputed
    var classicLazyBindingSymbols: CacheSlot<[ClassicBindingSymbol]?> = .notComputed
    var codeSign: CacheSlot<Base.CodeSign?> = .notComputed

    // MARK: - Chained-fixups slots

    // Populated only through the `where Base == MachOFile` APIs in
    // MachOCacheStorage+ChainedFixups.swift. They live here (not in an
    // extension) because Swift does not allow stored properties in extensions;
    // for a `MachOImage`-backed storage they simply stay unused.

    var chainedImports: CacheSlot<[DyldChainedImport]> = .notComputed
    /// `nil` means "not yet built"; an empty dictionary is a valid built result.
    var fixupPointersByOffset: [Int: DyldChainedFixupPointer]?

    // MARK: - Memoization

    /// Returns the cached value at `keyPath`, computing and storing it on first access.
    ///
    /// The `compute` closure runs **outside** the lock, so a slow parse of one
    /// property never blocks concurrent access to a different property. Under a
    /// race two callers may both compute the same slot; the first stored value
    /// wins and is returned to every caller — safe because each cached value is
    /// a pure function of immutable backing data.
    func memoized<Value>(
        _ keyPath: ReferenceWritableKeyPath<MachOCacheStorage, CacheSlot<Value>>,
        _ compute: () -> Value
    ) -> Value {
        lock.lock()
        if case .computed(let value) = self[keyPath: keyPath] {
            lock.unlock()
            return value
        }
        lock.unlock()

        let computed = compute()

        lock.lock()
        defer { lock.unlock() }
        if case .computed(let existing) = self[keyPath: keyPath] {
            return existing
        }
        self[keyPath: keyPath] = .computed(computed)
        return computed
    }

    /// Runs `body` while holding the storage lock.
    ///
    /// Used by the chained-fixups code that maintains `fixupPointersByOffset`,
    /// which is not a ``CacheSlot``. `body` must not call ``memoized(_:_:)`` or
    /// re-enter ``withLock(_:)`` — `NSLock` is not recursive.
    func withLock<Result>(_ body: () -> Result) -> Result {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    // MARK: - Invalidation

    /// Clears every cache slot. Call after the underlying data has changed.
    func invalidateAll() {
        lock.lock()
        defer { lock.unlock() }
        loadCommands = .notComputed
        rpaths = .notComputed
        dependencies = .notComputed
        segments = .notComputed
        sections = .notComputed
        sections64 = .notComputed
        sections32 = .notComputed
        symbols64 = .notComputed
        symbols32 = .notComputed
        symbolsArray = .notComputed
        indirectSymbols = .notComputed
        symbolStrings = .notComputed
        cStrings = .notComputed
        allCStringTables = .notComputed
        allCStrings = .notComputed
        uStrings = .notComputed
        cfStrings64 = .notComputed
        cfStrings32 = .notComputed
        embeddedInfoPlist = .notComputed
        rebaseOperations = .notComputed
        bindOperations = .notComputed
        weakBindOperations = .notComputed
        lazyBindOperations = .notComputed
        exportTrie = .notComputed
        exportedSymbols = .notComputed
        bindingSymbols = .notComputed
        weakBindingSymbols = .notComputed
        lazyBindingSymbols = .notComputed
        rebases = .notComputed
        functionStarts = .notComputed
        dataInCode = .notComputed
        externalRelocations = .notComputed
        classicBindingSymbols = .notComputed
        classicLazyBindingSymbols = .notComputed
        codeSign = .notComputed
        invalidateChainedFixupsLocked()
    }

    /// Clears only the chained-fixups caches.
    func invalidateChainedFixups() {
        lock.lock()
        defer { lock.unlock() }
        invalidateChainedFixupsLocked()
    }

    private func invalidateChainedFixupsLocked() {
        dyldChainedFixups = .notComputed
        chainedImports = .notComputed
        fixupPointersByOffset = nil
    }
}
