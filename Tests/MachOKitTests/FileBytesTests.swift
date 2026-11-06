import XCTest
@_spi(Support) @testable import MachOKit

/// The bytes MachOKit mapped a file into, handed to the layers above it so
/// they read through MachOKit's mapping instead of a second mapping of their
/// own or a `Data` per read.
final class FileBytesTests: XCTestCase {
    /// A standalone file's bytes are the whole file, its header at the
    /// file's header offset.
    func testStandaloneFileBytesAreTheWholeFile() throws {
        let url = URL(fileURLWithPath: "/usr/lib/dyld")
        let machOFile: MachOFile = switch try MachOKit.loadFromFile(url: url) {
        case .machO(let machOFile):
            machOFile
        case .fat(let fatFile):
            try XCTUnwrap(try fatFile.machOFiles().first)
        }
        let contents = try Data(contentsOf: url)

        let fileBytes = machOFile.fileBytes
        XCTAssertEqual(fileBytes.count, contents.count)
        XCTAssertEqual(Data(fileBytes), contents)

        let magic = fileBytes.loadUnaligned(fromByteOffset: machOFile.headerStartOffset, as: UInt32.self)
        XCTAssertEqual(magic, machOFile.header.magic?.rawValue)
    }

    /// The images of one dyld cache file read through one mapping, the
    /// cache's own, each header at the image's offset in it.
    func testImagesOfOneCacheFileShareItsBytes() throws {
        let cache = try XCTUnwrap(FullDyldCache.host)
        let images = Array(cache.machOFiles())
        let imagesOfOneFile = try XCTUnwrap(
            Dictionary(grouping: images, by: \.url.path).values.first { $0.count >= 2 }
        )
        let firstImage = imagesOfOneFile[0]
        let secondImage = imagesOfOneFile[1]
        let firstImageCache = try XCTUnwrap(firstImage.cache)

        XCTAssertEqual(firstImage.fileBytes.baseAddress, secondImage.fileBytes.baseAddress)
        XCTAssertEqual(firstImage.fileBytes.baseAddress, firstImageCache.fileBytes.baseAddress)

        for image in [firstImage, secondImage] {
            let magic = image.fileBytes.loadUnaligned(fromByteOffset: image.headerStartOffsetInCache, as: UInt32.self)
            XCTAssertEqual(magic, image.header.magic?.rawValue)
        }
    }
}
