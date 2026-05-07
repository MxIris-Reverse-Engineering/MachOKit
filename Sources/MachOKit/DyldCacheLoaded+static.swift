//
//  DyldCacheLoaded+static.swift
//  MachOKit
//
//  Created by p-x9 on 2025/01/09
//  
//

#if canImport(Darwin)
extension DyldCacheLoaded {
    /// Process-wide cache for ``current``. dyld's shared cache range is
    /// established at launch and never mutated for the lifetime of the
    /// process, so reconstructing a fresh `DyldCacheLoaded` on every access
    /// only burns CPU on header parsing — the original implementation
    /// showed up at the top of profiling sessions because every access
    /// re-evaluates `DyldCacheHeader.magic` / `_cpuType` / `_cpuSubType`,
    /// all of which run through the slow `String.init(tuple:)` byte-by-byte
    /// path.
    ///
    /// `static let` is initialized once on first read via the Swift
    /// runtime's lazy-init thunk (dispatch_once-equivalent), so concurrent
    /// callers race only on the constant-address read of `_cachedCurrent`,
    /// not on the construction.
    private static let _cachedCurrent: DyldCacheLoaded? = {
        guard let range = _DyldSharedCacheRuntime.sharedCacheRange(),
              range.size > 0,
              let cache = try? DyldCacheLoaded(ptr: range.ptr) else {
            return nil
        }
        return cache
    }()

    public static var current: DyldCacheLoaded? {
        _cachedCurrent
    }
}
#endif
