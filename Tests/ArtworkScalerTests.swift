import AppKit
import XCTest

final class ArtworkScalerTests: XCTestCase {
    private func png(width: Int, height: Int) -> Data {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        return rep.representation(using: .png, properties: [:])!
    }

    func testLargeImageIsScaledDownToRequestedSide() throws {
        let jpg = try XCTUnwrap(ArtworkScaler.jpeg(from: png(width: 1200, height: 1200)))
        let rep = try XCTUnwrap(NSBitmapImageRep(data: jpg))
        XCTAssertEqual(rep.pixelsWide, 400)
        XCTAssertEqual(rep.pixelsHigh, 400)
    }

    func testOutputIsJPEG() throws {
        let jpg = try XCTUnwrap(ArtworkScaler.jpeg(from: png(width: 64, height: 64), side: 100))
        XCTAssertEqual(Array(jpg.prefix(2)), [0xFF, 0xD8])
        XCTAssertEqual(try XCTUnwrap(NSBitmapImageRep(data: jpg)).pixelsWide, 100)
    }

    func testGarbageDataReturnsNil() {
        XCTAssertNil(ArtworkScaler.jpeg(from: Data("not an image".utf8)))
    }
}
