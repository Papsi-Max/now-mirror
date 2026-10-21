import Foundation

/// Merges the JSON lines printed by `mediaremote-adapter stream` into the current Now Playing state.
///
/// A line is `{"type":"data","diff":<bool>,"payload":{...}}`. A full payload (`diff: false`) replaces the
/// state; a diff payload updates only the keys it contains, and a `null` value removes a key.
struct StateMerger {
    private(set) var merged: [String: Any] = [:]

    /// Returns true when the line was a valid data message (and the state was updated).
    @discardableResult
    mutating func ingest(line: Data) -> Bool {
        guard let obj = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              obj["type"] as? String == "data",
              let payload = obj["payload"] as? [String: Any] else { return false }
        if obj["diff"] as? Bool == true {
            for (k, v) in payload {
                if v is NSNull { merged.removeValue(forKey: k) } else { merged[k] = v }
            }
        } else {
            merged = payload
        }
        return true
    }

    /// Base64 artwork of the current track, if the adapter sent any.
    var artworkBase64: String? { merged["artworkData"] as? String }

    /// The text fields and playback state; artwork and app name are filled in by the caller.
    func makeState() -> NowState {
        var s = NowState()
        s.title = merged["title"] as? String
        s.artist = merged["artist"] as? String
        s.album = merged["album"] as? String
        s.playing = merged["playing"] as? Bool ?? false
        s.bundleIdentifier = merged["bundleIdentifier"] as? String
        return s
    }
}
