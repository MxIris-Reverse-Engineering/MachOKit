import XCTest

/// `MachOKitC`'s umbrella header has to include every header of the module.
/// One it leaves out stays out of the module, and no build says so: Xcode
/// reuses the module it built before the header existed, without the warning
/// a fresh build of the module would give.
final class MachOKitCUmbrellaHeaderTests: XCTestCase {
    func testUmbrellaHeaderIncludesEveryHeader() throws {
        let includeDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/MachOKitC/include")
        let umbrellaHeaderName = "MachOKitC.h"
        let umbrellaHeader = try String(
            contentsOf: includeDirectory.appendingPathComponent(umbrellaHeaderName),
            encoding: .utf8
        )
        let headerNames = try FileManager.default.contentsOfDirectory(atPath: includeDirectory.path)
            .filter { $0.hasSuffix(".h") && $0 != umbrellaHeaderName }
            .sorted()
        XCTAssertFalse(headerNames.isEmpty)
        for headerName in headerNames {
            XCTAssertTrue(
                umbrellaHeader.contains("\n#include \"\(headerName)\"\n"),
                "\(umbrellaHeaderName) does not include \(headerName)"
            )
        }
    }
}
