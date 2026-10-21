import XCTest

final class StateMergerTests: XCTestCase {
    private func line(_ json: String) -> Data { Data(json.utf8) }

    func testFullPayloadSetsState() {
        var m = StateMerger()
        XCTAssertTrue(m.ingest(line: line(#"{"type":"data","diff":false,"payload":{"title":"A","artist":"B","album":"C","playing":true,"bundleIdentifier":"com.apple.Music"}}"#)))
        let s = m.makeState()
        XCTAssertEqual(s.title, "A")
        XCTAssertEqual(s.artist, "B")
        XCTAssertEqual(s.album, "C")
        XCTAssertTrue(s.playing)
        XCTAssertEqual(s.bundleIdentifier, "com.apple.Music")
    }

    func testDiffUpdatesOnlyGivenKeys() {
        var m = StateMerger()
        m.ingest(line: line(#"{"type":"data","diff":false,"payload":{"title":"A","artist":"B","playing":true}}"#))
        m.ingest(line: line(#"{"type":"data","diff":true,"payload":{"playing":false}}"#))
        let s = m.makeState()
        XCTAssertEqual(s.title, "A")
        XCTAssertEqual(s.artist, "B")
        XCTAssertFalse(s.playing)
    }

    func testDiffWithNullRemovesKey() {
        var m = StateMerger()
        m.ingest(line: line(#"{"type":"data","diff":false,"payload":{"title":"A","album":"C"}}"#))
        m.ingest(line: line(#"{"type":"data","diff":true,"payload":{"album":null}}"#))
        XCTAssertNil(m.makeState().album)
        XCTAssertEqual(m.makeState().title, "A")
    }

    func testFullPayloadReplacesPreviousState() {
        var m = StateMerger()
        m.ingest(line: line(#"{"type":"data","diff":false,"payload":{"title":"A","artist":"B"}}"#))
        m.ingest(line: line(#"{"type":"data","diff":false,"payload":{}}"#))
        XCTAssertTrue(m.makeState().isEmpty)
    }

    func testInvalidLinesAreIgnored() {
        var m = StateMerger()
        m.ingest(line: line(#"{"type":"data","diff":false,"payload":{"title":"A"}}"#))
        XCTAssertFalse(m.ingest(line: line("not json")))
        XCTAssertFalse(m.ingest(line: line(#"{"type":"error","message":"x"}"#)))
        XCTAssertFalse(m.ingest(line: line(#"{"type":"data","diff":true}"#)))
        XCTAssertEqual(m.makeState().title, "A")
    }

    func testMissingPlayingDefaultsToFalse() {
        var m = StateMerger()
        m.ingest(line: line(#"{"type":"data","diff":false,"payload":{"title":"A"}}"#))
        XCTAssertFalse(m.makeState().playing)
    }

    func testArtworkBase64() {
        var m = StateMerger()
        XCTAssertNil(m.artworkBase64)
        m.ingest(line: line(#"{"type":"data","diff":false,"payload":{"title":"A","artworkData":"AAAA"}}"#))
        XCTAssertEqual(m.artworkBase64, "AAAA")
        m.ingest(line: line(#"{"type":"data","diff":true,"payload":{"playing":true}}"#))
        XCTAssertEqual(m.artworkBase64, "AAAA", "a diff without artwork keeps the current one")
    }
}
