import AppIntents
import Foundation

private func post(_ c: MirrorCommand) {
    DistributedNotificationCenter.default().postNotificationName(c.notificationName, object: nil, userInfo: nil, deliverImmediately: true)
}

struct PreviousTrackIntent: AppIntent {
    static var title: LocalizedStringResource = "Previous track"
    func perform() async throws -> some IntentResult { post(.previous); return .result() }
}
struct TogglePlayPauseIntent: AppIntent {
    static var title: LocalizedStringResource = "Play / pause"
    func perform() async throws -> some IntentResult { post(.togglePlayPause); return .result() }
}
struct NextTrackIntent: AppIntent {
    static var title: LocalizedStringResource = "Next track"
    func perform() async throws -> some IntentResult { post(.next); return .result() }
}
