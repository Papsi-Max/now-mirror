import Foundation

/// Relay state exposed to the UI (settings, menu).
@MainActor
final class AppModel: ObservableObject {
    @Published var error: String?
    @Published var nowPlaying: String?
    @Published var adapterTest = "Running…"

    var isHealthy: Bool? { error == nil ? true : false }

    func update(_ s: NowState) {
        error = s.error
        nowPlaying = s.isEmpty ? nil : [s.title, s.artist].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " – ")
    }

    func diagnostics() -> String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        return """
        Now Mirror \(v)
        macOS \(ProcessInfo.processInfo.operatingSystemVersionString)
        Adapter self-test: \(adapterTest)
        Error: \(error ?? "none")
        Now Playing: \(nowPlaying ?? "nothing")
        """
    }
}
