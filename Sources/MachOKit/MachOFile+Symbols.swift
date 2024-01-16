//
//  MachOFile+Symbols.swift
//
//
//  Created by p-x9 on 2023/12/08.
//  
//

import Foundation

extension MachOFile {
    public struct Symbol: SymbolProtocol {
        public let name: String

        /// Offset from start of mach header (`MachO`)
        /// File offset from mach header (`MachOFile`)
        public let offset: Int

        /// Nlist or Nlist64
        public let nlist: any NlistProtocol
    }
}

extension MachOFile {
    public struct Symbols64: Sequence {
        public let stringData: Data
        public let symbolsData: Data

        public let numberOfSymbols: Int

        public func makeIterator() -> Iterator {
            .init(
                stringData: stringData,
                symbolsData: symbolsData,
                numberOfSymbols: numberOfSymbols
            )
        }
    }
}

extension MachOFile.Symbols64 {
    init(
        machO: MachOFile,
        symtab: LoadCommandInfo<symtab_command>
    ) {
        machO.fileHandle.seek(
            toFileOffset: UInt64(machO.headerStartOffset) + UInt64(symtab.stroff)
        )
        let stringData = machO.fileHandle.readData(
            ofLength: Int(symtab.strsize)
        )

        machO.fileHandle.seek(
            toFileOffset: UInt64(machO.headerStartOffset) + UInt64(symtab.symoff)
        )
        let symbolsData = machO.fileHandle.readData(
            ofLength: Int(symtab.nsyms) * MemoryLayout<nlist_64>.size
        )

        if machO.isSwapped {
            symbolsData.withUnsafeBytes {
                guard let baseAddress = $0.baseAddress else { return }
                let ptr = UnsafeMutableRawPointer(mutating: baseAddress)
                    .assumingMemoryBound(to: nlist_64.self)
                swap_nlist_64(
                    ptr,
                    symtab.nsyms,
                    NXHostByteOrder()
                )
            }
        }
        self.init(
            stringData: stringData,
            symbolsData: symbolsData,
            numberOfSymbols: numericCast(symtab.nsyms)
        )
    }
}

extension MachOFile.Symbols64 {
    public struct Iterator: IteratorProtocol {
        public typealias Element = MachOFile.Symbol

        let stringData: Data
        let symbolsData: Data

        public let numberOfSymbols: Int

        private var nextIndex: Int = 0

        init(
            stringData: Data,
            symbolsData: Data,
            numberOfSymbols: Int
        ) {
            self.stringData = stringData
            self.symbolsData = symbolsData
            self.numberOfSymbols = numberOfSymbols
        }

        public mutating func next() -> Element? {
            guard nextIndex < numberOfSymbols,
                  !symbolsData.isEmpty,
                  !stringData.isEmpty else {
                return nil
            }

            let symbol: nlist_64 = symbolsData.withUnsafeBytes {
                guard let baseAddress = $0.baseAddress else {
                    fatalError()
                }
                let ptr = baseAddress
                    .assumingMemoryBound(to: nlist_64.self)

                let symbol = ptr.advanced(by: nextIndex).pointee

                nextIndex += 1

                return symbol
            }

            let string: String = stringData.withUnsafeBytes {
                guard let baseAddress = $0.baseAddress else {
                    fatalError()
                }
                let ptr = baseAddress
                    .assumingMemoryBound(to: CChar.self)
                    .advanced(by: Int(symbol.n_un.n_strx))
                return String(
                    cString: ptr
                )
            }

            return .init(
                name: string,
                offset: Int(symbol.n_value),
                nlist: Nlist64(layout: symbol)
            )
        }
    }
}

extension MachOFile {
    public struct Symbols: Sequence {
        public let stringData: Data
        public let symbolsData: Data

        public let numberOfSymbols: Int

        public func makeIterator() -> Iterator {
            .init(
                stringData: stringData,
                symbolsData: symbolsData,
                numberOfSymbols: numberOfSymbols
            )
        }
    }
}

extension MachOFile.Symbols {
    init(
        machO: MachOFile,
        symtab: LoadCommandInfo<symtab_command>
    ) {
        machO.fileHandle.seek(
            toFileOffset: UInt64(machO.headerStartOffset) + UInt64(symtab.stroff)
        )
        let stringData = machO.fileHandle.readData(
            ofLength: Int(symtab.strsize)
        )

        machO.fileHandle.seek(
            toFileOffset: UInt64(machO.headerStartOffset) + UInt64(symtab.symoff)
        )
        let symbolsData = machO.fileHandle.readData(
            ofLength: Int(symtab.nsyms) * MemoryLayout<nlist_64>.size
        )

        if machO.isSwapped {
            symbolsData.withUnsafeBytes {
                guard let baseAddress = $0.baseAddress else { return }
                let ptr = UnsafeMutableRawPointer(mutating: baseAddress)
                    .assumingMemoryBound(to: nlist.self)
                swap_nlist(
                    ptr,
                    symtab.nsyms,
                    NXHostByteOrder()
                )
            }
        }

        self.init(
            stringData: stringData,
            symbolsData: symbolsData,
            numberOfSymbols: numericCast(symtab.nsyms)
        )
    }
}

extension MachOFile.Symbols {
    public struct Iterator: IteratorProtocol {
        public typealias Element = MachOFile.Symbol

        let stringData: Data
        let symbolsData: Data

        public let numberOfSymbols: Int

        private var nextIndex: Int = 0

        init(
            stringData: Data,
            symbolsData: Data,
            numberOfSymbols: Int
        ) {
            self.stringData = stringData
            self.symbolsData = symbolsData
            self.numberOfSymbols = numberOfSymbols
        }

        public mutating func next() -> Element? {
            guard nextIndex < numberOfSymbols,
                  !symbolsData.isEmpty,
                  !stringData.isEmpty else {
                return nil
            }

            let symbol: nlist = symbolsData.withUnsafeBytes {
                guard let baseAddress = $0.baseAddress else {
                    fatalError()
                }
                let ptr = baseAddress
                    .assumingMemoryBound(to: nlist.self)

                let symbol = ptr.advanced(by: nextIndex).pointee

                nextIndex += 1

                return symbol
            }

            let string: String = stringData.withUnsafeBytes {
                guard let baseAddress = $0.baseAddress else {
                    fatalError()
                }
                let ptr = baseAddress
                    .assumingMemoryBound(to: CChar.self)
                    .advanced(by: Int(symbol.n_un.n_strx))
                return String(
                    cString: ptr
                )
            }

            return .init(
                name: string,
                offset: Int(symbol.n_value),
                nlist: Nlist(layout: symbol)
            )
        }
    }
}
