//
//  MachOCached+SymbolLookup.swift
//  MachOKit
//
//  Created for the `.cached` view feature.
//

import Foundation

// Parameterized symbol lookups, mirrored from the `MachORepresentable`
// protocol extensions but driven off the cached, materialized symbol array
// (`cachedSymbolsArray`). Building that array once removes the repeated
// `Array(symbols)` cost the original algorithms pay on every call.

extension MachOCached {
    /// Cached equivalent of `MachORepresentable.closestSymbol(at:inSection:isGlobalOnly:)`.
    public func closestSymbol( // swiftlint:disable:this cyclomatic_complexity
        at offset: Int,
        inSection sectionNumber: Int = 0,
        isGlobalOnly: Bool = false
    ) -> Base.Symbol? {
        let symbols = cachedSymbolsArray
        var bestSymbol: Base.Symbol?

        if let dysym = loadCommands.dysymtab {
            // find closest match in globals
            let globalStart: Int = numericCast(dysym.iextdefsym)
            let globalCount: Int = numericCast(dysym.nextdefsym)
            for i in globalStart ..< globalStart + globalCount {
                let symbol = symbols[i]
                let nlist = symbol.nlist
                let symbolSectionNumber = symbol.nlist.sectionNumber

                guard nlist.flags?.type == .sect,
                      symbol.offset <= offset,
                      sectionNumber == 0 || symbolSectionNumber == sectionNumber else {
                    continue
                }
                if let bestSymbol,
                   bestSymbol.offset >= symbol.offset {
                    continue
                }
                bestSymbol = symbol
            }
            if isGlobalOnly { return bestSymbol }

            // find closest match in locals
            let localStart: Int = numericCast(dysym.ilocalsym)
            let localCount: Int = numericCast(dysym.nlocalsym)
            for i in localStart ..< localStart + localCount {
                let symbol = symbols[i]
                let nlist = symbol.nlist
                let symbolSectionNumber = symbol.nlist.sectionNumber

                guard nlist.flags?.type == .sect,
                      nlist.flags?.stab == nil,
                      symbol.offset <= offset,
                      sectionNumber == 0 || symbolSectionNumber == sectionNumber else {
                    continue
                }
                if let bestSymbol,
                   bestSymbol.offset >= symbol.offset {
                    continue
                }
                bestSymbol = symbol
            }
        } else {
            // find closest match in locals
            for symbol in symbols {
                let nlist = symbol.nlist
                let symbolSectionNumber = symbol.nlist.sectionNumber
                guard nlist.flags?.type == .sect,
                      nlist.flags?.stab == nil,
                      symbol.offset <= offset,
                      !isGlobalOnly || nlist.flags?.contains(.ext) ?? false,
                      sectionNumber == 0 || symbolSectionNumber == sectionNumber else {
                    continue
                }
                if let bestSymbol,
                   bestSymbol.offset >= symbol.offset {
                    continue
                }
                bestSymbol = symbol
            }
        }

        return bestSymbol
    }

    /// Cached equivalent of `MachORepresentable.closestSymbols(at:inSection:isGlobalOnly:)`.
    public func closestSymbols( // swiftlint:disable:this cyclomatic_complexity
        at offset: Int,
        inSection sectionNumber: Int = 0,
        isGlobalOnly: Bool = false
    ) -> [Base.Symbol] {
        let symbols = cachedSymbolsArray
        var bestOffset: Int?
        var bestSymbols: [Base.Symbol] = []

        func updateBestSymbols(_ symbol: Base.Symbol) {
            if let _bestOffset = bestOffset {
                if _bestOffset > symbol.offset {
                    return
                } else if _bestOffset == symbol.offset {
                    bestSymbols.append(symbol)
                } else {
                    bestOffset = symbol.offset
                    bestSymbols = [symbol]
                }
            } else {
                bestOffset = symbol.offset
                bestSymbols = [symbol]
            }
        }

        if let dysym = loadCommands.dysymtab {
            // find closest match in globals
            let globalStart: Int = numericCast(dysym.iextdefsym)
            let globalCount: Int = numericCast(dysym.nextdefsym)
            for i in globalStart ..< globalStart + globalCount {
                let symbol = symbols[i]
                let nlist = symbol.nlist
                let symbolSectionNumber = symbol.nlist.sectionNumber

                guard nlist.flags?.type == .sect,
                      symbol.offset <= offset,
                      sectionNumber == 0 || symbolSectionNumber == sectionNumber else {
                    continue
                }
                updateBestSymbols(symbol)
            }
            if isGlobalOnly { return bestSymbols }

            // find closest match in locals
            let localStart: Int = numericCast(dysym.ilocalsym)
            let localCount: Int = numericCast(dysym.nlocalsym)
            for i in localStart ..< localStart + localCount {
                let symbol = symbols[i]
                let nlist = symbol.nlist
                let symbolSectionNumber = symbol.nlist.sectionNumber

                guard nlist.flags?.type == .sect,
                      nlist.flags?.stab == nil,
                      symbol.offset <= offset,
                      sectionNumber == 0 || symbolSectionNumber == sectionNumber else {
                    continue
                }
                updateBestSymbols(symbol)
            }
        } else {
            // find closest match in locals
            for symbol in symbols {
                let nlist = symbol.nlist
                let symbolSectionNumber = symbol.nlist.sectionNumber
                guard nlist.flags?.type == .sect,
                      nlist.flags?.stab == nil,
                      symbol.offset <= offset,
                      !isGlobalOnly || nlist.flags?.contains(.ext) ?? false,
                      sectionNumber == 0 || symbolSectionNumber == sectionNumber else {
                    continue
                }
                updateBestSymbols(symbol)
            }
        }

        return bestSymbols
    }

    /// Cached equivalent of `MachORepresentable.symbol(for:inSection:isGlobalOnly:)`.
    public func symbol(
        for offset: Int,
        inSection sectionNumber: Int = 0,
        isGlobalOnly: Bool = false
    ) -> Base.Symbol? {
        let best = closestSymbol(
            at: offset,
            inSection: sectionNumber,
            isGlobalOnly: isGlobalOnly
        )
        return best?.offset == offset ? best : nil
    }

    /// Cached equivalent of `MachORepresentable.symbols(for:inSection:isGlobalOnly:)`.
    public func symbols(
        for offset: Int,
        inSection sectionNumber: Int = 0,
        isGlobalOnly: Bool = false
    ) -> [Base.Symbol] {
        let best = closestSymbols(
            at: offset,
            inSection: sectionNumber,
            isGlobalOnly: isGlobalOnly
        )
        return best.first?.offset == offset ? best : []
    }
}

extension MachOCached where Base.Symbol == MachOFile.Symbol {
    /// Cached equivalent of `MachORepresentable.symbols(named:mangled:)`.
    public func symbols(named name: String, mangled: Bool = true) -> [Base.Symbol] {
        cachedSymbolsArray.named(name, mangled: mangled)
    }

    /// Cached equivalent of `MachORepresentable.symbol(named:mangled:inSection:isGlobalOnly:)`.
    public func symbol(
        named name: String,
        mangled: Bool = true,
        inSection sectionNumber: Int = 0,
        isGlobalOnly: Bool = false
    ) -> Base.Symbol? {
        _symbol(
            named: name,
            inSection: sectionNumber,
            isGlobalOnly: isGlobalOnly,
            matchesName: { nameC, symbol in
                if strcmp(nameC, symbol.name) == 0 || strcmp(nameC, "_" + symbol.name) == 0 {
                    return true
                } else if !mangled, let demangled = stdlib_demangleName(symbol.name) {
                    return strcmp(nameC, demangled) == 0
                }
                return false
            }
        )
    }
}

extension MachOCached where Base.Symbol == MachOImage.Symbol {
    /// Cached equivalent of `MachORepresentable.symbols(named:mangled:)`.
    public func symbols(named name: String, mangled: Bool = true) -> [Base.Symbol] {
        cachedSymbolsArray.named(name, mangled: mangled)
    }

    /// Cached equivalent of `MachORepresentable.symbol(named:mangled:inSection:isGlobalOnly:)`.
    public func symbol(
        named name: String,
        mangled: Bool = true,
        inSection sectionNumber: Int = 0,
        isGlobalOnly: Bool = false
    ) -> Base.Symbol? {
        _symbol(
            named: name,
            inSection: sectionNumber,
            isGlobalOnly: isGlobalOnly,
            matchesName: { nameC, symbol in
                if strcmp(nameC, symbol.nameC) == 0 || strcmp(nameC, symbol.nameC + 1) == 0 {
                    return true
                } else if !mangled, let demangled = stdlib_demangleName(symbol.nameC) {
                    return strcmp(nameC, demangled) == 0
                }
                return false
            }
        )
    }
}

extension MachOCached {
    private func _symbol( // swiftlint:disable:this cyclomatic_complexity
        named name: String,
        inSection sectionNumber: Int = 0,
        isGlobalOnly: Bool = false,
        matchesName: ([CChar], Base.Symbol) -> Bool
    ) -> Base.Symbol? {
        guard let nameC = name.cString(using: .utf8) else {
            return nil
        }

        let symbols = cachedSymbolsArray
        var bestSymbol: Base.Symbol?

        if let dysym = loadCommands.dysymtab {
            // find closest match in globals
            let globalStart: Int = numericCast(dysym.iextdefsym)
            let globalCount: Int = numericCast(dysym.nextdefsym)
            for i in globalStart ..< globalStart + globalCount {
                let symbol = symbols[i]
                let nlist = symbol.nlist
                let symbolSectionNumber = symbol.nlist.sectionNumber

                guard nlist.flags?.type == .sect,
                      sectionNumber == 0 || symbolSectionNumber == sectionNumber,
                      matchesName(nameC, symbol) else {
                    continue
                }
                bestSymbol = symbol
            }
            if isGlobalOnly { return bestSymbol }

            // find closest match in locals
            let localStart: Int = numericCast(dysym.ilocalsym)
            let localCount: Int = numericCast(dysym.nlocalsym)
            for i in localStart ..< localStart + localCount {
                let symbol = symbols[i]
                let nlist = symbol.nlist
                let symbolSectionNumber = symbol.nlist.sectionNumber

                guard nlist.flags?.type == .sect,
                      nlist.flags?.stab == nil,
                      sectionNumber == 0 || symbolSectionNumber == sectionNumber,
                      matchesName(nameC, symbol) else {
                    continue
                }
                bestSymbol = symbol
            }
        } else {
            // find closest match in locals
            for symbol in symbols {
                let nlist = symbol.nlist
                let symbolSectionNumber = symbol.nlist.sectionNumber
                guard nlist.flags?.type == .sect,
                      nlist.flags?.stab == nil,
                      sectionNumber == 0 || symbolSectionNumber == sectionNumber,
                      !isGlobalOnly || nlist.flags?.contains(.ext) ?? false,
                      matchesName(nameC, symbol) else {
                    continue
                }
                bestSymbol = symbol
            }
        }

        return bestSymbol
    }
}
