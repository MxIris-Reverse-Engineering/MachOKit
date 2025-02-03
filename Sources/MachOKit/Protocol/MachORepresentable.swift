//
//  MachORepresentable.swift
//
//
//  Created by p-x9 on 2023/12/13.
//  
//

import Foundation

public protocol MachORepresentable {
    associatedtype LoadCommands: LoadCommandsProtocol
    associatedtype Symbol: SymbolProtocol
    associatedtype Symbols64: RandomAccessCollection<Symbol>
    associatedtype Symbols: RandomAccessCollection<Symbol>
    associatedtype IndirectSymbols: RandomAccessCollection<IndirectSymbol>
    associatedtype RebaseOperations: Sequence<RebaseOperation>
    associatedtype BindOperations: Sequence<BindOperation>
    associatedtype ExportTrie: Sequence<ExportTrieEntry>
    associatedtype Strings: StringTable<UTF8>
    associatedtype UTF16Strings: StringTable<UTF16>
    associatedtype FunctionStarts: Sequence<FunctionStart>
    associatedtype DataInCode: RandomAccessCollection<DataInCodeEntry>
    associatedtype DyldChainedFixups: DyldChainedFixupsProtocol
    associatedtype ExternalRelocations: RandomAccessCollection<Relocation>
    associatedtype CodeSign: CodeSignProtocol

    /// A boolean value that indicates whether MachO is a 64-bit architecture.
    var is64Bit: Bool { get }

    /// Size of MachO header. [byte]
    var headerSize: Int { get }

    /// MachO header
    var header: MachHeader { get }

    /// Sequence of load commands
    var loadCommands: LoadCommands { get }

    /// List of runpaths
    var rpaths: [String] { get }
    /// List of depended dynamic libraries
    var dependencies: [DependedDylib] { get }

    /// List of segments
    var segments: [any SegmentCommandProtocol] { get }
    /// Sequence of 64-bit architecture segments
    var segments64: AnySequence<SegmentCommand64> { get }
    /// Sequence of 32-bit architecture segments
    var segments32: AnySequence<SegmentCommand> { get }

    /// List of sections in all segments
    var sections: [any SectionProtocol] { get }
    /// List of sections in 64-bit architecture segments
    var sections64: [Section64] { get }
    /// List of sections in 32-bit architecture segments
    var sections32: [Section] { get }

    /// Sequence of symbols
    var symbols: AnyRandomAccessCollection<Symbol> { get }
    /// Sequence of 64-bit architecture symbols
    var symbols64: Symbols64? { get }
    /// Sequence of 32-bit architecture symbols
    var symbols32: Symbols? { get }

    /// Sequence of Indirect symbols
    var indirectSymbols: IndirectSymbols? { get }

    /// Sequence of symbol strings.
    /// (symbol string table)
    var symbolStrings: Strings? { get }

    /// Sequence of strings in `__TEXT, __cstring` section
    var cStrings: Strings? { get }

    /// Sequence of all string tables in this MachO
    ///
    /// Symbol string table is not included.
    var allCStringTables: [Strings] { get }

    /// Sequence of all strings in this MachO
    ///
    /// Symbol strings is not included.
    var allCStrings: [String] { get }

    /// Sequence of rebase operations
    var rebaseOperations: RebaseOperations? { get }

    /// Sequence of bind operations
    var bindOperations: BindOperations? { get }

    /// Sequence of weak bind operations
    var weakBindOperations: BindOperations? { get }

    /// Sequence of lazy bind operations
    var lazyBindOperations: BindOperations? { get }

    /// Sequence of export tries
    ///
    /// If LC_DYLD_INFO(LC_DYLD_INFO_ONLY) does not exist, look for LC_DYLD_EXPORTS_TRIE
    var exportTrie: ExportTrie? { get }

    /// List of export symbols
    ///
    /// It is obtained by parsing  ``exportTrie``
    var exportedSymbols: [ExportedSymbol] { get }

    /// List of binding symbols
    ///
    /// It is obtained by parsing  ``bindOperations``
    /// When this sequence is empty, it may be retrieved from ``dyldChainedFixups``
    var bindingSymbols: [BindingSymbol] { get }

    /// List of weak binding symbols
    ///
    /// It is obtained by parsing  ``weakBindOperations``
    var weakBindingSymbols: [BindingSymbol] { get }

    /// List of lazy binding symbols
    ///
    /// It is obtained by parsing  ``lazyBindOperations``
    var lazyBindingSymbols: [BindingSymbol] { get }

    /// List of rebases
    ///
    /// It is obtained by parsing  ``rebaseOperations``
    /// When this sequence is empty, it may be retrieved from ``dyldChainedFixups``
    var rebases: [Rebase] { get }

    /// Sequence of function starts
    var functionStarts: FunctionStarts? { get }

    /// Sequence of data in codes
    var dataInCode: DataInCode? { get }

    /// Chained fixup infos
    var dyldChainedFixups: DyldChainedFixups? { get }

    /// Sequence of external relocation infos
    var externalRelocations: ExternalRelocations? { get }

    /// Code sign infos
    var codeSign: CodeSign? { get }

    /// Expected file size of this mach-o
    ///
    /// segments information is used in the calculation.
    /// If this mach-o is read from a fat file or dyld cache, it will differ from the actual file size.
    var expectedMachOFileSize: Int? { get }

    /// Find the symbol closest to the address at the specified offset.
    ///
    /// Behaves almost identically to the `dladdr` function
    ///
    /// If sectionNumber is 0, search in all sections
    ///
    /// - Parameters:
    ///   - offset: Offset from start of mach header. (``SymbolProtocol.offset``)
    ///   - sectionNumber: Section number to be searched.
    ///   - isGlobalOnly: If true, search only global symbols.
    /// - Returns: Closest symbol.
    func closestSymbol(
        at offset: Int,
        inSection sectionNumber: Int,
        isGlobalOnly: Bool
    ) -> Symbol?

    /// Find the symbols closest to the address at the specified offset.
    ///
    /// Different from ``closestSymbol(at:inSection:isGlobalOnly:)`` multiple symbols with the same offset may be found.
    ///
    /// If sectionNumber is 0, search in all sections
    ///
    /// - Parameters:
    ///   - offset: Offset from start of mach header. (``SymbolProtocol.offset``)
    ///   - sectionNumber: Section number to be searched.
    ///   - isGlobalOnly: If true, search only global symbols.
    /// - Returns: Closest symbols.
    func closestSymbols(
        at offset: Int,
        inSection sectionNumber: Int,
        isGlobalOnly: Bool
    ) -> [Symbol]

    /// Find the symbol matching the specified offset.
    ///
    /// If sectionNumber is 0, search in all sections
    ///
    /// - Parameters:
    ///   - offset: Offset from start of mach header. (``SymbolProtocol.offset``)
    ///   - sectionNumber: Section number to be searched.
    ///   - isGlobalOnly: If true, search only global symbols.
    /// - Returns: Matched symbol
    func symbol(
        for offset: Int,
        inSection sectionNumber: Int,
        isGlobalOnly: Bool
    ) -> Symbol?

    /// Find the symbols matching the specified offset.
    ///
    /// Different from ``symbol(for:isGlobalOnly:)`` multiple symbols with the same offset may be found.
    ///
    /// If sectionNumber is 0, search in all sections
    ///
    /// - Parameters:
    ///   - offset: Offset from start of mach header. (``SymbolProtocol.offset``)
    ///   - sectionNumber: Section number to be searched.
    ///   - isGlobalOnly: If true, search only global symbols.
    /// - Returns: Matched symbols
    func symbols(
        for offset: Int,
        inSection sectionNumber: Int,
        isGlobalOnly: Bool
    ) -> [Symbol]

    /// Find the symbol matching the given name.
    /// - Parameters:
    ///   - name: Symbol name to find
    ///   - mangled: A boolean value that indicates whether the specified name is mangled with Swift
    /// - Returns: Matched symbols
    func symbols(named name: String, mangled: Bool) -> [Symbol]

    /// Find the symbol matching the given name
    /// Search only for symbols defined within this mach-o
    ///
    /// If sectionNumber is 0, search in all sections
    ///
    /// - Parameters:
    ///   - name: Symbol name to find
    ///   - mangled: A boolean value that indicates whether the specified name is mangled with Swift
    ///   - sectionNumber: Section number to be searched.
    ///   - isGlobalOnly: If true, search only global symbols.
    /// - Returns: Matched symbol
    func symbol(
        named name: String,
        mangled: Bool,
        inSection sectionNumber: Int,
        isGlobalOnly: Bool
    ) -> Symbol?
}

extension MachORepresentable {
    public var segments: [any SegmentCommandProtocol] {
        if is64Bit {
            Array(segments64)
        } else {
            Array(segments32)
        }
    }

    public var segments64: AnySequence<SegmentCommand64> {
        loadCommands.infos(of: LoadCommand.segment64)
    }

    public var segments32: AnySequence<SegmentCommand> {
        loadCommands.infos(of: LoadCommand.segment)
    }
}

extension MachORepresentable {
    public var sections: [any SectionProtocol] {
        if is64Bit {
            sections64
        } else {
            sections32
        }
    }
}

extension MachORepresentable {
    public var symbols: AnyRandomAccessCollection<Symbol> {
        if is64Bit, let symbols64 {
            AnyRandomAccessCollection(symbols64)
        } else if let symbols32 {
            AnyRandomAccessCollection(symbols32)
        } else {
            AnyRandomAccessCollection([])
        }
    }
}

extension MachORepresentable {
    public var bindingSymbols: [BindingSymbol] {
        guard let bindOperations else {
            return []
        }
        return bindOperations.bindings(is64Bit: is64Bit)
    }

    public var weakBindingSymbols: [BindingSymbol] {
        guard let weakBindOperations else {
            return []
        }
        return weakBindOperations.bindings(is64Bit: is64Bit)
    }

    public var lazyBindingSymbols: [BindingSymbol] {
        guard let lazyBindOperations else {
            return []
        }
        return lazyBindOperations.bindings(is64Bit: is64Bit)
    }

    public var rebases: [Rebase] {
        guard let rebaseOperations else {
            return []
        }
        return rebaseOperations.rebases(is64Bit: is64Bit)
    }
}

extension MachORepresentable {
    public var expectedMachOFileSize: Int? {
        guard let segment = segments.max(
            by: { lhs, rhs in lhs.fileOffset < rhs.fileOffset }
        ) else { return nil }
        return segment.fileOffset + segment.fileSize
    }
}

extension MachORepresentable {
    public func closestSymbol( // swiftlint:disable:this cyclomatic_complexity
        at offset: Int,
        inSection sectionNumber: Int = 0,
        isGlobalOnly: Bool = false
    ) -> Symbol? {
        let symbols = Array(self.symbols)
        var bestSymbol: Symbol?

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

    public func closestSymbols( // swiftlint:disable:this cyclomatic_complexity
        at offset: Int,
        inSection sectionNumber: Int = 0,
        isGlobalOnly: Bool = false
    ) -> [Symbol] {
        let symbols = self.symbols
        var bestOffset: Int?
        var bestSymbols: [Symbol] = []

        func updateBestSymbols(_ symbol: Symbol) {
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
                let symbol = symbols[AnyIndex(i)]
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
                let symbol = symbols[AnyIndex(i)]
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
}

extension MachORepresentable {
    public func symbol(
        for offset: Int,
        inSection sectionNumber: Int = 0,
        isGlobalOnly: Bool = false
    ) -> Symbol? {
        let best = closestSymbol(
            at: offset,
            inSection: sectionNumber,
            isGlobalOnly: isGlobalOnly
        )
        return best?.offset == offset ? best : nil
    }

    public func symbols(
        for offset: Int,
        inSection sectionNumber: Int = 0,
        isGlobalOnly: Bool = false
    ) -> [Symbol] {
        let best = closestSymbols(
            at: offset,
            inSection: sectionNumber,
            isGlobalOnly: isGlobalOnly
        )
        return best.first?.offset == offset ? best : []
    }
}

extension MachORepresentable where Symbol == MachOFile.Symbol {
    public func symbols(
        named name: String,
        mangled: Bool = true
    ) -> [Symbol] {
        if is64Bit, let symbols64 {
            return symbols64.named(name, mangled: mangled)
        } else if let symbols32 {
            return symbols32.named(name, mangled: mangled)
        }
        return []
    }

    public func symbol(
        named name: String,
        mangled: Bool = true,
        inSection sectionNumber: Int = 0,
        isGlobalOnly: Bool = false
    ) -> Symbol? {
        _symbol(
            named: name,
            inSection: sectionNumber,
            isGlobalOnly: isGlobalOnly,
            matchesName: { nameC, symbol in
                if strcmp(nameC, symbol.name) == 0 || strcmp(nameC, "_" + symbol.name) == 0 {
                    return true
                } else if !mangled {
                    let demangled = stdlib_demangleName(symbol.name)
                    return strcmp(nameC, demangled) == 0
                }
                return false
            }
        )
    }
}

extension MachORepresentable where Symbol == MachOImage.Symbol {
    public func symbols(
        named name: String,
        mangled: Bool = true
    ) -> [Symbol] {
        if is64Bit, let symbols64 {
            return symbols64.named(name, mangled: mangled)
        } else if let symbols32 {
            return symbols32.named(name, mangled: mangled)
        }
        return []
    }

    public func symbol(
        named name: String,
        mangled: Bool = true,
        inSection sectionNumber: Int = 0,
        isGlobalOnly: Bool = false
    ) -> Symbol? {
        _symbol(
            named: name,
            inSection: sectionNumber,
            isGlobalOnly: isGlobalOnly,
            matchesName: { nameC, symbol in
                if strcmp(nameC, symbol.nameC) == 0 || strcmp(nameC, symbol.nameC + 1) == 0 {
                    return true
                } else if !mangled {
                    let demangled = stdlib_demangleName(symbol.nameC)
                    return strcmp(nameC, demangled) == 0
                }
                return false
            }
        )
    }
}

extension MachORepresentable {
    private func _symbol(
        named name: String,
        inSection sectionNumber: Int = 0,
        isGlobalOnly: Bool = false,
        matchesName: ([CChar], Symbol) -> Bool
    ) -> Symbol? { // swiftlint:disable:this cyclomatic_complexity
        guard let nameC = name.cString(using: .utf8) else {
            return nil
        }

        let symbols = self.symbols
        var bestSymbol: Symbol?

        if let dysym = loadCommands.dysymtab {
            // find closest match in globals
            let globalStart: Int = numericCast(dysym.iextdefsym)
            let globalCount: Int = numericCast(dysym.nextdefsym)
            for i in globalStart ..< globalStart + globalCount {
                let symbol = symbols[AnyIndex(i)]
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
                let symbol = symbols[AnyIndex(i)]
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
