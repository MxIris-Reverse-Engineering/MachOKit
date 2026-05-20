//
//  MachOCacheStorage+ChainedFixups.swift
//  MachOKit
//
//  Created for the `.cached` view feature.
//

// Chained-fixups deep caching is `MachOFile`-only: a `MachOImage` is a memory
// image whose fixup chains dyld has already applied and overwritten in place,
// so walking its chains yields nothing meaningful. `MachOImage` chained-fixups
// metadata (`dyldChainedFixups`, `imports`, …) is still cached through the
// generic slots.
extension MachOCacheStorage where Base == MachOFile {
    /// The cached `DyldChainedFixups` instance.
    func dyldChainedFixups(of machO: MachOFile) -> MachOFile.DyldChainedFixups? {
        memoized(\.dyldChainedFixups) { machO.dyldChainedFixups }
    }

    /// The cached chained imports table.
    func chainedImports(of machO: MachOFile) -> [DyldChainedImport] {
        memoized(\.chainedImports) { dyldChainedFixups(of: machO)?.imports ?? [] }
    }

    /// `offset -> DyldChainedFixupPointer` map for O(1) lookup.
    ///
    /// Built once by walking every chain of every segment. This is the step
    /// that makes per-offset chained-fixup resolution cheap.
    func fixupPointers(of machO: MachOFile) -> [Int: DyldChainedFixupPointer] {
        if let cached = withLock({ fixupPointersByOffset }) {
            return cached
        }

        // Walk the chains outside the lock — this is the expensive part.
        // `dyldChainedFixups(of:)` goes through `memoized`, which takes the
        // (non-recursive) lock itself, so it must be called outside `withLock`.
        var built: [Int: DyldChainedFixupPointer] = [:]
        if let fixups = dyldChainedFixups(of: machO),
           let startsInImage = fixups.startsInImage {
            for segment in fixups.startsInSegments(of: startsInImage) {
                for pointer in fixups.pointers(of: segment, in: machO) {
                    built[pointer.offset] = pointer
                }
            }
        }

        return withLock {
            if let existing = fixupPointersByOffset { return existing }
            fixupPointersByOffset = built
            return built
        }
    }

    /// Cached equivalent of `MachOFile.resolveRebase(at:)`.
    func resolveRebase(of machO: MachOFile, at offset: UInt64) -> UInt64? {
        if machO.isLoadedFromDyldCache, let cache = machO.cache {
            return cache.resolveRebase(at: offset)
        }
        guard let pointer = fixupPointers(of: machO)[Int(offset)] else {
            return nil
        }
        guard pointer.fixupInfo.rebase != nil,
              let rebaseOffset = pointer.rebaseTargetRuntimeOffset(for: machO) else {
            return nil
        }
        return rebaseOffset
    }

    /// Cached equivalent of `MachOFile.resolveOptionalRebase(at:)`.
    func resolveOptionalRebase(of machO: MachOFile, at offset: UInt64) -> UInt64? {
        if machO.isLoadedFromDyldCache, let cache = machO.cache {
            return cache.resolveOptionalRebase(at: offset)
        }
        guard let pointer = fixupPointers(of: machO)[Int(offset)] else {
            return nil
        }
        guard pointer.fixupInfo.rebase != nil,
              let rebaseOffset = pointer.rebaseTargetRuntimeOffset(for: machO) else {
            return nil
        }
        if machO.is64Bit {
            let value: UInt64 = try! machO.fileHandle.read(
                offset: numericCast(machO.headerStartOffset + pointer.offset)
            )
            if value == 0 { return nil }
        } else {
            let value: UInt32 = try! machO.fileHandle.read(
                offset: numericCast(machO.headerStartOffset + pointer.offset)
            )
            if value == 0 { return nil }
        }
        return rebaseOffset
    }

    /// Cached equivalent of `MachOFile.resolveBind(at:)`.
    func resolveBind(
        of machO: MachOFile,
        at offset: UInt64
    ) -> (DyldChainedImport, addend: UInt64)? {
        guard let pointer = fixupPointers(of: machO)[Int(offset)] else {
            return nil
        }
        guard pointer.fixupInfo.bind != nil,
              let (ordinal, addend) = pointer.bindOrdinalAndAddend(for: machO) else {
            return nil
        }
        let imports = chainedImports(of: machO)
        guard ordinal >= 0 && ordinal < imports.count else {
            return nil
        }
        return (imports[ordinal], addend)
    }
}
