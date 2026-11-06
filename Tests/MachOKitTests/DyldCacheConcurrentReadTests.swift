import XCTest
@testable import MachOKit

/// What a dyld cache remembers about itself — its mapping tables, its main
/// cache — is read by every thread reading an image of it, and the first
/// readers ask at the same time.
///
/// Remembered in plain stored properties, two first readers both stored a
/// value and the second store released the first while the other thread
/// was still retaining it. A reader above MachOKit that built two indexes of
/// one image at once crashed in `mappingInfo(for:)` that way, in roughly
/// every other run of its test suite. A plain run of these tests rarely
/// lines the threads up; under the thread sanitizer every unsynchronized
/// first read is reported.
final class DyldCacheConcurrentReadTests: XCTestCase {
    private let roundCount = 20
    private let threadCount = 16

    /// Fresh caches each round, so every round's first reads race. The
    /// address comes from another instance: asking the raced one first would
    /// fill in what the threads are to race on.
    func testAddressLookupsFromManyThreadsAtOnce() throws {
        let hostCache = try XCTUnwrap(FullDyldCache.host)
        let firstMapping = try XCTUnwrap(DyldCache(url: hostCache.url).mappingInfos?.first)
        let expectedFileOffset = firstMapping.fileOffset
        for _ in 0 ..< roundCount {
            let cache = try DyldCache(url: hostCache.url)
            let fileOffsets = ConcurrentResults<UInt64?>(count: threadCount)
            DispatchQueue.concurrentPerform(iterations: threadCount) { threadIndex in
                fileOffsets[threadIndex] = cache.fileOffset(of: firstMapping.address)
            }
            XCTAssertEqual(Set(fileOffsets.values), [expectedFileOffset])
        }
    }

    /// A subcache opened on its own finds its main cache when first asked;
    /// every thread asking at once gets the same one.
    func testMainCacheOfASubcacheFromManyThreadsAtOnce() throws {
        let hostCache = try XCTUnwrap(FullDyldCache.host)
        let subcacheURL = try XCTUnwrap(hostCache.urls.dropFirst().first)
        for _ in 0 ..< roundCount {
            let subcache = try DyldCache(subcacheUrl: subcacheURL, mainCacheHeader: hostCache.header)
            let mainCaches = ConcurrentResults<ObjectIdentifier?>(count: threadCount)
            DispatchQueue.concurrentPerform(iterations: threadCount) { threadIndex in
                mainCaches[threadIndex] = subcache.mainCache.map { ObjectIdentifier($0) }
            }
            let distinctMainCaches = Set(mainCaches.values)
            XCTAssertEqual(distinctMainCaches.count, 1)
            XCTAssertFalse(distinctMainCaches.contains(nil))
            XCTAssertEqual(subcache.mainCache?.url, hostCache.url)
        }
    }
}

/// One slot per thread, each written by its own thread only.
private final class ConcurrentResults<Value>: @unchecked Sendable {
    private var storage: [Value?]
    private let lock = NSLock()

    init(count: Int) {
        storage = Array(repeating: nil, count: count)
    }

    subscript(index: Int) -> Value? {
        get { lock.lock(); defer { lock.unlock() }; return storage[index] }
        set { lock.lock(); defer { lock.unlock() }; storage[index] = newValue }
    }

    var values: [Value] {
        lock.lock()
        defer { lock.unlock() }
        return storage.compactMap { $0 }
    }
}
