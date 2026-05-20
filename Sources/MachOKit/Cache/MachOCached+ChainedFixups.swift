//
//  MachOCached+ChainedFixups.swift
//  MachOKit
//
//  Created for the `.cached` view feature.
//

// Chained-fixups deep caching — `MachOFile`-only.
//
// A `MachOImage` is an in-memory image whose fixup chains dyld has already
// applied and overwritten in place, so walking its chains yields nothing
// meaningful (this is also why `MachOImage.DyldChainedFixups` itself offers
// no `pointers`). `MachOImage` chained-fixups *metadata* is still cached
// through the generic `dyldChainedFixups` member.
extension MachOCached where Base == MachOFile {
    /// Cached `offset -> DyldChainedFixupPointer` map.
    ///
    /// Built once by walking every chain of every segment; afterwards each
    /// lookup is O(1).
    public var fixupPointers: [Int: DyldChainedFixupPointer] {
        storage.fixupPointers(of: base)
    }

    /// The cached `DyldChainedFixupPointer` at the given file offset, if any.
    public func fixupPointer(at offset: Int) -> DyldChainedFixupPointer? {
        storage.fixupPointers(of: base)[offset]
    }

    /// Cached equivalent of `MachOFile.resolveRebase(at:)`.
    public func resolveRebase(at offset: UInt64) -> UInt64? {
        storage.resolveRebase(of: base, at: offset)
    }

    /// Cached equivalent of `MachOFile.resolveOptionalRebase(at:)`.
    public func resolveOptionalRebase(at offset: UInt64) -> UInt64? {
        storage.resolveOptionalRebase(of: base, at: offset)
    }

    /// Cached equivalent of `MachOFile.resolveBind(at:)`.
    public func resolveBind(at offset: UInt64) -> (DyldChainedImport, addend: UInt64)? {
        storage.resolveBind(of: base, at: offset)
    }
}
