//
//  DyldCache.swift
//
//
//  Created by p-x9 on 2024/01/13.
//
//

import Foundation
#if compiler(>=6.0) || (compiler(>=5.10) && hasFeature(AccessLevelOnImport))
internal import FileIO
internal import FileIOBinary
#else
@_implementationOnly import FileIO
@_implementationOnly import FileIOBinary
#endif

/// `DyldCache` represents a single dyld shared cache file.
///
/// It provides access to Mach-O binaries and metadata contained in a dyld shared cache,
/// enabling parsing of load commands, symbol tables, mappings, and other information.
///
/// This class is intended to work with a single cache file. For handling multiple subcaches
/// as one logical cache, see ``FullDyldCache``.
///
/// - Note: `DyldCache` automatically verifies the file's magic header and CPU type
///   when initialized.
///
/// - SeeAlso: ``DyldCacheRepresentable``, ``FullDyldCache``

public class DyldCache: DyldCacheRepresentable, _DyldCacheFileRepresentable {
    typealias File = MemoryMappedFile

    /// URL of loaded dyld cache file
    public let url: URL
    let fileHandle: File
    let _fileHandleIdentity: FileHandleIdentityBox

    // Retain the cache to which `self` belongs
    private let memoizedFullCache = MemoizedReference<FullDyldCache>()
    // Retain the main cache
    private let memoizedMainCache: MemoizedReference<DyldCache>
    // Retain the symbol cache
    private let memoizedSymbolCache = MemoizedReference<DyldCache>()

    // Read once, when the cache is opened: every read of an image in it maps
    // an address through them, from as many threads as read the image.
    private let _mappingInfos: [DyldCacheMappingInfo]?
    private let _mappingAndSlideInfos: [DyldCacheMappingAndSlideInfo]?

    // Retain the cache to which `self` belongs
    internal var _fullCache: FullDyldCache? {
        get { memoizedFullCache.value }
        set { memoizedFullCache.replace(with: newValue) }
    }

    // Retain the symbol cache
    internal var _symbolCache: DyldCache? {
        get { memoizedSymbolCache.value }
        set { memoizedSymbolCache.replace(with: newValue) }
    }

    public var headerSize: Int {
        header.actualSize
    }

    /// Header for dyld cache
    public let header: DyldCacheHeader

    /// Target CPU info.
    ///
    /// It is read from the header's architecture fields when present,
    /// otherwise it is recovered from the header magic.
    public let cpu: CPU

    private var _mainCacheHeader: DyldCacheHeader?

    /// Header for main dyld cache
    /// When this dyld cache is a subcache, represent the header of the main cache
    ///
    /// Some properties are only set for the main cache header
    /// https://github.com/apple-oss-distributions/dyld/blob/d552c40cd1de105f0ec95008e0e0c0972de43456/cache_builder/SubCache.cpp#L1353
    public var mainCacheHeader: DyldCacheHeader {
        _mainCacheHeader ?? header
    }

    /// Load dyld cache.
    /// - Parameter url: url for dyld cache
    /// - Important: Use ``init(subcacheUrl:mainCacheHeader:)`` to load sub cache
    public init(url: URL) throws {
        self.url = url
        let fileHandle = try File.open(
            url: url,
            isWritable: false
        )
        self.fileHandle = fileHandle
        self._fileHandleIdentity = FileHandleIdentityStore.identity(
            for: fileHandle
        )

        // read header
        self.header = try! fileHandle.read(
            offset: 0
        )

        // check magic of header
        guard header.magic.starts(with: "dyld_") else {
            throw MachOKitError.invalidMagic
        }

        guard let cpu = header._resolvedCPU else {
            throw MachOKitError.invalidCpuType
        }
        self.cpu = cpu
        self.memoizedMainCache = MemoizedReference()
        self._mappingInfos = DyldCache.readMappingInfos(in: fileHandle, header: header)
        self._mappingAndSlideInfos = DyldCache.readMappingAndSlideInfos(in: fileHandle, header: header)
    }

    /// Load sub dyld cache
    /// - Parameters:
    ///   - subcacheUrl: url for dyld cache
    ///   - mainCacheHeader: header of main dyld cache
    public convenience init(
        subcacheUrl: URL,
        mainCacheHeader: DyldCacheHeader
    ) throws {
        try self.init(url: subcacheUrl)
        self._mainCacheHeader = mainCacheHeader
    }

    /// Load sub dyld cache
    /// - Parameters:
    ///   - subcacheUrl: url for dyld cache
    ///   - mainCache: main dyld cache
    public convenience init(
        subcacheUrl: URL,
        mainCache: DyldCache
    ) throws {
        try self.init(url: subcacheUrl)
        self.memoizedMainCache.replace(with: mainCache)
        self._mainCacheHeader = mainCache.header
    }

    internal init(
        unsafeFileHandle fileHandle: File,
        url: URL,
        cpu: CPU,
        header: DyldCacheHeader? = nil,
        mainCache: DyldCache? = nil,
        mainCacheHeader: DyldCacheHeader? = nil
    ) {
        self.fileHandle = fileHandle
        self._fileHandleIdentity = FileHandleIdentityStore.identity(
            for: fileHandle
        )
        self.url = url
        let resolvedHeader: DyldCacheHeader = header ?? (
            try! fileHandle.read(
                offset: 0
            )
        )
        self.header = resolvedHeader
        self.cpu = cpu
        self.memoizedMainCache = MemoizedReference(mainCache)
        self._mainCacheHeader = mainCache?.header ?? mainCacheHeader
        self._mappingInfos = DyldCache.readMappingInfos(in: fileHandle, header: resolvedHeader)
        self._mappingAndSlideInfos = DyldCache.readMappingAndSlideInfos(in: fileHandle, header: resolvedHeader)
    }
}

extension DyldCache {
    /// The mapping infos `header` lists, read out of `fileHandle`.
    static func readMappingInfos(
        in fileHandle: File,
        header: DyldCacheHeader
    ) -> [DyldCacheMappingInfo]? {
        guard header.mappingCount > 0 else { return nil }
        let mappingInfos: DataSequence<DyldCacheMappingInfo> = fileHandle.readDataSequence(
            offset: numericCast(header.mappingOffset),
            numberOfElements: numericCast(header.mappingCount)
        )
        return Array(mappingInfos)
    }

    /// The mapping and slide infos `header` lists, read out of `fileHandle`.
    static func readMappingAndSlideInfos(
        in fileHandle: File,
        header: DyldCacheHeader
    ) -> [DyldCacheMappingAndSlideInfo]? {
        guard header.mappingWithSlideCount > 0,
              header.hasProperty(\.mappingWithSlideCount) else {
            return nil
        }
        let mappingAndSlideInfos: DataSequence<DyldCacheMappingAndSlideInfo> = fileHandle.readDataSequence(
            offset: numericCast(header.mappingWithSlideOffset),
            numberOfElements: numericCast(header.mappingWithSlideCount)
        )
        return Array(mappingAndSlideInfos)
    }
}

extension DyldCache {
    public var mainCache: DyldCache? {
        if let mainCache = memoizedMainCache.value { return mainCache }
        if let fullCache = _fullCache {
            if fullCache.url == url { return self }
            return memoizedMainCache.publish(fullCache.mainCache)
        }
        if url.lastPathComponent.contains(".") {
            let url = url
                .deletingPathExtension()
                .deletingPathExtension()
            guard let mainCache = try? DyldCache(url: url) else { return nil }
            mainCache._fullCache = _fullCache
            return memoizedMainCache.publish(mainCache)
        } else {
            return self
        }
    }

    public var fullCache: FullDyldCache? {
        if let fullCache = _fullCache { return fullCache }
        let url = url
            .deletingPathExtension()
            .deletingPathExtension()
        guard let fullCache = try? FullDyldCache(url: url) else { return nil }
        return memoizedFullCache.publish(fullCache)
    }
}

extension DyldCache {
    /// The cached `FullDyldCache`, if one is already associated with this cache.
    ///
    /// Unlike ``fullCache``, this property does not lazily create or load a full cache.
    @_spi(Support)
    public var _cachedFullCache: FullDyldCache? {
        _fullCache
    }
}

extension DyldCache {
    /// Sequence of mapping infos
    public var mappingInfos: [DyldCacheMappingInfo]? {
        _mappingInfos
    }

    /// Sequence of mapping and slide infos
    public var mappingAndSlideInfos: [DyldCacheMappingAndSlideInfo]? {
        _mappingAndSlideInfos
    }

    /// Sequence of image infos.
    public var imageInfos: DataSequence<DyldCacheImageInfo>? {
        guard header.imagesCount > 0 else { return nil }
        return fileHandle.readDataSequence(
            offset: numericCast(header.imagesOffset),
            numberOfElements: header.imagesCount
        )
    }

    /// Sequence of image text infos.
    public var imageTextInfos: DataSequence<DyldCacheImageTextInfo>? {
        guard header.imagesTextCount > 0,
              header.hasProperty(\.imagesTextCount) else {
            return nil
        }
        return fileHandle.readDataSequence(
            offset: numericCast(header.imagesTextOffset),
            numberOfElements: numericCast(header.imagesTextCount)
        )
    }

    /// Sub cache type
    ///
    /// Check if entry type is `dyld_subcache_entry_v1` or `dyld_subcache_entry`
    public var subCacheEntryType: DyldSubCacheEntryType? {
        guard header.subCacheArrayCount > 0 else {
            return nil
        }
        // https://github.com/apple-oss-distributions/dyld/blob/65bbeed63cec73f313b1d636e63f243964725a9d/common/DyldSharedCache.cpp#L1763
        let hasCacheSuffix = header.hasProperty(\.cacheSubType)
        return hasCacheSuffix ? .general : .v1
    }

    /// Sequence of sub caches
    public var subCaches: SubCaches? {
        guard let subCacheEntryType,
              header.hasProperty(\.subCacheArrayCount) else {
            return nil
        }
        let data = try! fileHandle.readData(
            offset: numericCast(header.subCacheArrayOffset),
            length: DyldSubCacheEntryGeneral.layoutSize * numericCast(header.subCacheArrayCount)
        )
        return .init(
            data: data,
            numberOfSubCaches: numericCast(header.subCacheArrayCount),
            subCacheEntryType: subCacheEntryType
        )
    }

    /// DyldCache containing unmapped local symbols
    public var symbolCache: DyldCache? {
        get throws {
            if let symbolCache = _symbolCache { return symbolCache }
            guard header.hasProperty(\.symbolFileUUID),
                  header.symbolFileUUID != .zero else {
                return nil
            }
            let suffix = ".symbols"
            let path = url.path + suffix
            let symbolCache: DyldCache = try .init(
                subcacheUrl: .init(fileURLWithPath: path, isDirectory: false),
                mainCacheHeader: mainCacheHeader
            )
            return memoizedSymbolCache.publish(symbolCache)
        }
    }

    /// Local symbol info
    public var localSymbolsInfo: DyldCacheLocalSymbolsInfo? {
        guard header.localSymbolsSize > 0,
              header.hasProperty(\.localSymbolsSize) else {
            return nil
        }
        let offset = header.localSymbolsOffset
        return .init(
            layout: fileHandle.read(
                offset: header.localSymbolsOffset
            ),
            offset: numericCast(offset)
        )
    }
}

extension DyldCache {
    /// Sequence of MachO information contained in this cache
    public func machOFiles() -> AnySequence<MachOFile> {
        _machOFiles(mainCache: mainCache)
    }

    /// Sequence of MachO information contained in this cache
    public func _machOFiles(
        mainCache: DyldCache? = nil
    ) -> AnySequence<MachOFile> {
        let effectiveDyldCache: DyldCache
        let imageInfos: DataSequence<DyldCacheImageInfo>

        if let mainCache, let mainCacheImageInfos = mainCache.imageInfos {
            effectiveDyldCache = mainCache
            imageInfos = mainCacheImageInfos
        } else if let currentCacheImageInfos = self.imageInfos {
            effectiveDyldCache = self
            imageInfos = currentCacheImageInfos
        } else {
            return AnySequence([])
        }

        let machOFiles = imageInfos
            .lazy
            .compactMap { info in
                guard let fileOffset = self.fileOffset(of: info.address),
                      let imagePath = info.path(in: effectiveDyldCache) else {
                    return nil
                }
                return (imagePath, fileOffset)
            }
            .compactMap { (imagePath: String, fileOffset: UInt64) -> MachOFile? in
                try? MachOFile(
                    url: self.url,
                    imagePath: imagePath,
                    headerStartOffsetInCache: numericCast(fileOffset),
                    cache: self
                )
            }

        return AnySequence(machOFiles)
    }

    public var dyld: MachOFile? {
        guard let offset = fileOffset(of: mainCacheHeader.dyldInCacheMH) else {
            return nil
        }
        return try? MachOFile(
            url: url,
            imagePath: "/usr/lib/dyld",
            headerStartOffsetInCache: numericCast(offset),
            cache: self
        )
    }
}

extension DyldCache {
    public var codeSign: MachOFile.CodeSign? {
        .init(
            fileSlice: try! fileHandle.fileSlice(
                offset: numericCast(header.codeSignatureOffset),
                length: numericCast(header.codeSignatureSize)
            )
        )
    }
}

extension DyldCache {
    /// Resolves the target of the metadata pointer at the specified file offset.
    /// This is the MachOKit equivalent of dyld's `MetadataVisitor::resolveRebase`.
    /// The top byte may or may not be kept depending on the slide info version:
    /// versions 2 and 3 keep it, while version 5 drops it.
    /// - Parameter offset: file offset of the pointer
    /// - Returns: unslid VM address of the pointer target
    ///
    /// [dyld Implementation](https://github.com/apple-oss-distributions/dyld/blob/66c652a1f1f6b7b5266b8bbfd51cb0965d67cc44/common/MetadataVisitor.cpp#L265)
    public func resolveRebase(at offset: UInt64) -> UInt64? {
        _resolveRebase(at: offset, skipsZeroValue: false)
    }

    /// Resolves the target of the optional metadata pointer at the specified file offset.
    /// This is the MachOKit equivalent of dyld's `MetadataVisitor::resolveOptionalRebase`.
    /// The top byte may or may not be kept depending on the slide info version:
    /// versions 2 and 3 keep it, while version 5 drops it.
    /// - Parameter offset: file offset of the pointer
    /// - Returns: unslid VM address of the pointer target
    ///
    /// [dyld implementation](https://github.com/apple-oss-distributions/dyld/blob/66c652a1f1f6b7b5266b8bbfd51cb0965d67cc44/common/MetadataVisitor.cpp#L435)
    /// `resolveOptionalRebase` differs from `resolveRebase` in that rebasing may or may not actually take place.
    public func resolveOptionalRebase(at offset: UInt64) -> UInt64? {
        _resolveRebase(at: offset, skipsZeroValue: true)
    }
}
