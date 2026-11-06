//
//  MachOKit+MemoizedReference.swift
//  MachOKit
//

import Foundation
#if canImport(os)
import os
#endif

/// A value a `DyldCache`, `FullDyldCache` or `MachOFile` remembers once it
/// has worked it out — the main cache, the full cache, the symbol cache —
/// safe to read and fill from several threads at once.
///
/// The three classes are shared: every image of one cache file reads through
/// the same instances, and readers above MachOKit read one image from several
/// threads. Remembered in a plain stored property, two threads asking at the
/// same time both stored a value, and the second store released the first
/// while the other thread was still retaining it; the retain then landed on
/// freed memory. A reader building two indexes of one image at once crashed
/// in `mappingInfo(for:)` that way.
///
/// A value is computed outside the lock and published only if none is there
/// yet, so the computation may itself ask other instances for their values,
/// and a published value is never replaced while a reader may hold it.
final class MemoizedReference<Value>: @unchecked Sendable {
    private let lock = MemoizationLock()
    private var storedValue: Value?

    init(_ value: Value? = nil) {
        self.storedValue = value
    }

    /// The value, if one has been published.
    var value: Value? {
        lock.withLock { storedValue }
    }

    /// Publishes `candidate` unless a value is already there, and answers
    /// whichever value stays.
    @discardableResult
    func publish(_ candidate: Value) -> Value {
        lock.withLock {
            if let storedValue { return storedValue }
            storedValue = candidate
            return candidate
        }
    }

    /// Replaces the value. For the setters that hand an instance its
    /// relatives right after assembling it, before any other thread sees it.
    func replace(with newValue: Value?) {
        lock.withLock { storedValue = newValue }
    }
}

/// An `os_unfair_lock` where the platform has one, an `NSLock` elsewhere.
final class MemoizationLock: @unchecked Sendable {
    #if canImport(os)
    private let unfairLock: UnsafeMutablePointer<os_unfair_lock>

    init() {
        unfairLock = .allocate(capacity: 1)
        unfairLock.initialize(to: os_unfair_lock())
    }

    deinit {
        unfairLock.deinitialize(count: 1)
        unfairLock.deallocate()
    }

    @inline(__always)
    func withLock<Result>(_ body: () throws -> Result) rethrows -> Result {
        os_unfair_lock_lock(unfairLock)
        defer { os_unfair_lock_unlock(unfairLock) }
        return try body()
    }
    #else
    private let lock = NSLock()

    @inline(__always)
    func withLock<Result>(_ body: () throws -> Result) rethrows -> Result {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }
    #endif
}
