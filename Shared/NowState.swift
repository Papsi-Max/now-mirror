import Foundation

/// "Now Playing" state shared between the relay (writes) and the widget (reads).
struct NowState: Codable, Equatable {
    var title: String?
    var artist: String?
    var album: String?
    var playing: Bool = false
    var appName: String?
    var bundleIdentifier: String?
    /// Artwork file name in the shared folder (changes with every artwork).
    var artworkFile: String?
    /// Relay error message (adapter blocked, etc.).
    var error: String?
    var updatedAt: Date = Date()

    var isEmpty: Bool { (title ?? "").isEmpty && (artist ?? "").isEmpty }
}

enum SharedPaths {
    /// The real home folder (inside the sandbox, NSHomeDirectory() points to the container).
    static var realHome: String {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir { return String(cString: dir) }
        return NSHomeDirectory()
    }
    static var directory: URL {
        URL(fileURLWithPath: realHome).appendingPathComponent("Library/Application Support/NowMirror", isDirectory: true)
    }
    static var stateFile: URL { directory.appendingPathComponent("state.json") }
    static func artwork(_ name: String) -> URL { directory.appendingPathComponent(name) }

    static func load() -> NowState? {
        guard let data = try? Data(contentsOf: stateFile) else { return nil }
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601
        return try? d.decode(NowState.self, from: data)
    }
}

/// Commands sent from the (sandboxed) widget to the relay through a distributed notification.
/// The notification name carries the command, so no payload is needed.
enum MirrorCommand: String, CaseIterable {
    case previous, togglePlayPause, next

    var notificationName: Notification.Name { .init("dev.nowmirror.command.\(rawValue)") }
    /// MediaRemote command number for `mediaremote-adapter send`.
    var adapterCode: String {
        switch self { case .togglePlayPause: "2"; case .next: "4"; case .previous: "5" }
    }
}
