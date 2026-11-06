//
//  MachOKit+FileBytes.swift
//  MachOKit
//

import Foundation

// MARK: - file bytes

extension MachOFile {
    /// The bytes of the file this Mach-O file is read from, as MachOKit
    /// mapped it when the file was opened: the whole file, a fat file's
    /// every slice and a dyld cache file's every image included.
    ///
    /// Offsets count from the start of the file, so a slice of a fat file
    /// starts at ``headerStartOffset`` and an image of a dyld cache at
    /// ``headerStartOffsetInCache``. The bytes stay valid while this file or
    /// another value sharing its file handle is alive.
    ///
    /// A layer above MachOKit that reads many small values reads them here
    /// rather than through a mapping of its own, which would hold a second
    /// descriptor per file, or through `Data`, which allocates per read.
    @_spi(Support)
    public var fileBytes: UnsafeRawBufferPointer {
        UnsafeRawBufferPointer(start: fileHandle.ptr, count: fileHandle.size)
    }
}

extension DyldCache {
    /// The bytes of this dyld cache file as MachOKit mapped it when the file
    /// was opened. Offsets count from the start of the file; the bytes stay
    /// valid while this cache or another value sharing its file handle is
    /// alive.
    @_spi(Support)
    public var fileBytes: UnsafeRawBufferPointer {
        UnsafeRawBufferPointer(start: fileHandle.ptr, count: fileHandle.size)
    }
}
