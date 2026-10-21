import AppKit
import WidgetKit

/// Runs `mediaremote-adapter stream`, merges the updates and writes the shared state.
final class Relay {
    private let model: AppModel
    init(model: AppModel) { self.model = model }
    private var process: Process?
    private var buffer = Data()
    private var merger = StateMerger()
    private var lastArtworkBase64: String?
    private var state = NowState()
    private var stopped = false
    private var failures = 0
    private let queue = DispatchQueue(label: "relay")

    private var adapterDir: URL { Bundle.main.resourceURL!.appendingPathComponent("adapter") }

    func start() {
        try? FileManager.default.createDirectory(at: SharedPaths.directory, withIntermediateDirectories: true)
        cleanArtwork(keeping: nil)
        queue.async { self.selfTest(); self.launch() }
        for c in MirrorCommand.allCases {
            DistributedNotificationCenter.default().addObserver(forName: c.notificationName, object: nil, queue: nil) { [weak self] _ in
                self?.queue.async { self?.send(c) }
            }
        }
    }

    /// Sends the command to the app currently shown in Now Playing.
    private func send(_ c: MirrorCommand) {
        let (code, out) = run(["send", c.adapterCode])
        if code != 0 { NSLog("NowMirror: send %@ failed (%d): %@", c.rawValue, code, out) }
    }

    func stop() { stopped = true; process?.terminate() }

    // MARK: test + stream

    private func run(_ extra: [String]) -> (Int32, String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        p.arguments = [adapterDir.appendingPathComponent("mediaremote-adapter.pl").path,
                       adapterDir.appendingPathComponent("MediaRemoteAdapter.framework").path] + extra
        let out = Pipe(); p.standardOutput = out; p.standardError = out
        do { try p.run() } catch { return (-1, "\(error)") }
        p.waitUntilExit()
        return (p.terminationStatus, String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "")
    }

    private func selfTest() {
        let (code, out) = run([adapterDir.appendingPathComponent("MediaRemoteAdapterTestClient").path, "test"])
        DispatchQueue.main.async { self.model.adapterTest = code == 0 ? "passed" : "failed (code \(code))" }
        if code != 0 {
            NSLog("NowMirror: test de l'adaptateur failed (%d): %@", code, out)
            state.error = "The MediaRemote adapter is blocked (self-test failed)."
            publish()
        }
    }

    private func launch() {
        guard !stopped else { return }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        p.arguments = [adapterDir.appendingPathComponent("mediaremote-adapter.pl").path,
                       adapterDir.appendingPathComponent("MediaRemoteAdapter.framework").path, "stream"]
        let out = Pipe(); p.standardOutput = out
        out.fileHandleForReading.readabilityHandler = { [weak self] h in
            let d = h.availableData
            guard !d.isEmpty else { h.readabilityHandler = nil; return }
            self?.queue.async { self?.consume(d) }
        }
        p.terminationHandler = { [weak self] _ in
            self?.queue.async {
                guard let self, !self.stopped else { return }
                self.failures += 1
                let delay = min(30.0, Double(self.failures) * 2)
                self.queue.asyncAfter(deadline: .now() + delay) { self.launch() }
            }
        }
        do { try p.run(); process = p; failures = 0 } catch {
            state.error = "Impossible de lancer /usr/bin/perl : \(error.localizedDescription)"; publish()
        }
    }

    private func consume(_ data: Data) {
        buffer.append(data)
        while let nl = buffer.firstIndex(of: 0x0A) {
            let line = buffer.subdata(in: buffer.startIndex..<nl)
            buffer.removeSubrange(buffer.startIndex...nl)
            handle(line)
        }
    }

    private func handle(_ line: Data) {
        if merger.ingest(line: line) { apply() }
    }

    // MARK: state

    private func apply() {
        var s = merger.makeState()
        s.appName = s.bundleIdentifier.flatMap(Self.appName)
        s.artworkFile = state.artworkFile
        if let b64 = merger.artworkBase64 {
            // Only rewrite the file when the artwork really changed: a new file name on every update
            // would make the widget chase files that were just deleted.
            if b64 != lastArtworkBase64, let raw = Data(base64Encoded: b64), let name = writeArtwork(raw) {
                s.artworkFile = name
                lastArtworkBase64 = b64
            }
        } else {
            // Artwork sometimes arrives after the title: don't keep the previous track's artwork.
            if s.title == nil || state.title != s.title || state.artist != s.artist {
                s.artworkFile = nil
                lastArtworkBase64 = nil
            }
        }
        s.error = state.error
        guard s.title != state.title || s.artist != state.artist || s.album != state.album
                || s.playing != state.playing || s.artworkFile != state.artworkFile
                || s.bundleIdentifier != state.bundleIdentifier else { return }
        state = s
        publish()
    }

    private static func appName(_ bundleID: String) -> String? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    /// Scales the artwork (see `ArtworkScaler`) and writes it under a unique name.
    private func writeArtwork(_ raw: Data) -> String? {
        guard let jpg = ArtworkScaler.jpeg(from: raw) else { return nil }
        let name = "artwork-\(UUID().uuidString.prefix(8)).jpg"
        do { try jpg.write(to: SharedPaths.artwork(name), options: .atomic) } catch { return nil }
        cleanArtwork(keeping: name)
        return name
    }

    private func cleanArtwork(keeping name: String?) {
        let fm = FileManager.default
        for f in (try? fm.contentsOfDirectory(atPath: SharedPaths.directory.path)) ?? []
        where f.hasPrefix("artwork-") && f != name { try? fm.removeItem(at: SharedPaths.artwork(f)) }
    }

    private func publish() {
        state.updatedAt = Date()
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601
        if let data = try? e.encode(state) { try? data.write(to: SharedPaths.stateFile, options: .atomic) }
        let snapshot = state
        DispatchQueue.main.async { self.model.update(snapshot); WidgetCenter.shared.reloadAllTimelines() }
    }
}
