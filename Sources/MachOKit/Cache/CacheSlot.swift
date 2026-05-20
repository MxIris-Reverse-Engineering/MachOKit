//
//  CacheSlot.swift
//  MachOKit
//
//  Created for the `.cached` view feature.
//

/// A storage slot for a lazily computed, memoized value.
///
/// Distinguishes "never computed" from "computed". The latter may itself hold
/// an optional whose value is `nil`, so an API returning `nil` is cached as
/// `.computed(nil)` and not recomputed on every access.
enum CacheSlot<Value> {
    case notComputed
    case computed(Value)
}
