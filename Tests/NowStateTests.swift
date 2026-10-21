import XCTest

final class NowStateTests: XCTestCase {
    func testIsEmpty() {
        XCTAssertTrue(NowState().isEmpty)
        XCTAssertTrue(NowState(title: "", artist: "").isEmpty)
        XCTAssertFalse(NowState(title: "A").isEmpty)
        XCTAssertFalse(NowState(artist: "B").isEmpty)
    }

    func testCodableRoundTrip() throws {
        var s = NowState(title: "Titre é", artist: "Artist", album: "Album", playing: true)
        s.artworkFile = "artwork-1.jpg"
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601
        let back = try d.decode(NowState.self, from: e.encode(s))
        XCTAssertEqual(back.title, s.title)
        XCTAssertEqual(back.artworkFile, "artwork-1.jpg")
        XCTAssertTrue(back.playing)
    }

    func testCommandCodesMatchAdapter() {
        XCTAssertEqual(MirrorCommand.togglePlayPause.adapterCode, "2")
        XCTAssertEqual(MirrorCommand.next.adapterCode, "4")
        XCTAssertEqual(MirrorCommand.previous.adapterCode, "5")
    }

    func testCommandNotificationNamesAreDistinct() {
        let names = Set(MirrorCommand.allCases.map { $0.notificationName.rawValue })
        XCTAssertEqual(names.count, MirrorCommand.allCases.count)
        XCTAssertTrue(names.allSatisfy { $0.hasPrefix("dev.nowmirror.command.") })
    }

    func testSharedDirectoryIsInRealHome() {
        XCTAssertTrue(SharedPaths.directory.path.hasSuffix("Library/Application Support/NowMirror"))
        XCTAssertFalse(SharedPaths.directory.path.contains("/Containers/"))
    }
}
