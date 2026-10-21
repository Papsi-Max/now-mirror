import AppIntents
import AppKit
import SwiftUI
import WidgetKit

struct NowEntry: TimelineEntry {
    let date: Date
    let state: NowState?
    let artwork: NSImage?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> NowEntry {
        NowEntry(date: .now, state: NowState(title: "Title", artist: "Artist", album: "Album", playing: true, appName: "Musique"), artwork: nil)
    }
    func getSnapshot(in context: Context, completion: @escaping (NowEntry) -> Void) { completion(load()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<NowEntry>) -> Void) {
        // The relay reloads the timeline on every change; fallback: every 15 minutes.
        completion(Timeline(entries: [load()], policy: .after(.now.addingTimeInterval(900))))
    }
    private func load() -> NowEntry {
        let s = SharedPaths.load()
        // Read the bytes now: NSImage(contentsOf:) is lazy and the relay may delete the file later.
        let img = s?.artworkFile.flatMap { try? Data(contentsOf: SharedPaths.artwork($0)) }.flatMap { NSImage(data: $0) }
        return NowEntry(date: .now, state: s, artwork: img)
    }
}

/// In the tinted (monochrome) desktop style, images are flattened into a single-color block by default.
/// `.desaturated` keeps the artwork's luminance, so the cover stays readable while the widget stays dark.
/// (`.fullColor` was tried first: the cover was readable but the tinted widget came out light, with unreadable text.)
struct ArtworkImage: View {
    let image: NSImage
    var body: some View {
        if #available(macOS 15.0, *) {
            Image(nsImage: image).resizable().widgetAccentedRenderingMode(.desaturated).scaledToFill()
        } else {
            Image(nsImage: image).resizable().scaledToFill()
        }
    }
}

struct ArtView: View {
    let image: NSImage?
    var body: some View {
        Group {
            if let image { ArtworkImage(image: image) }
            else { ZStack { Color.gray.opacity(0.25); Image(systemName: "music.note").font(.largeTitle).foregroundStyle(.secondary) } }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct NowView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NowEntry

    var body: some View {
        if let s = entry.state, !s.isEmpty { content(s) }
        else {
            VStack(spacing: 6) {
                Image(systemName: entry.state?.error == nil ? "music.note" : "exclamationmark.triangle").font(.title)
                Text(entry.state?.error ?? "Nothing playing").font(.caption).multilineTextAlignment(.center)
            }.foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func texts(_ s: NowState) -> some View {
        let sub = [s.artist, s.album].compactMap { $0 }.filter { !$0.isEmpty }
        return VStack(alignment: .leading, spacing: 2) {
            Text(s.title ?? "").font(family == .systemSmall ? .subheadline.bold() : .headline).lineLimit(2)
            Text(sub.joined(separator: " – ")).font(.subheadline).foregroundStyle(.secondary).lineLimit(family == .systemSmall ? 1 : 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func controls(_ s: NowState) -> some View {
        HStack(spacing: family == .systemSmall ? 14 : 22) {
            Button(intent: PreviousTrackIntent()) { Image(systemName: "backward.fill") }
            Button(intent: TogglePlayPauseIntent()) { Image(systemName: s.playing ? "pause.fill" : "play.fill") }
            Button(intent: NextTrackIntent()) { Image(systemName: "forward.fill") }
        }
        .buttonStyle(.plain).font(family == .systemSmall ? .body : .title2)
    }

    @ViewBuilder private func content(_ s: NowState) -> some View {
        switch family {
        case .systemSmall:
            VStack(alignment: .leading, spacing: 6) {
                ArtView(image: entry.artwork).frame(height: 56)
                texts(s)
                Spacer(minLength: 0)
                controls(s)
            }
        case .systemLarge:
            VStack(alignment: .leading, spacing: 12) {
                ArtView(image: entry.artwork).frame(maxWidth: .infinity)
                texts(s)
                controls(s)
            }
        default:
            HStack(alignment: .top, spacing: 14) {
                ArtView(image: entry.artwork)
                VStack(alignment: .leading, spacing: 6) {
                    texts(s)
                    Spacer(minLength: 0)
                    controls(s)
                }
            }
        }
    }
}

struct NowMirrorWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NowMirror", provider: Provider()) { entry in
            NowView(entry: entry).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Now Playing")
        .description("Mirrors the system Now Playing: artwork, title, artist, with playback controls.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct NowMirrorBundle: WidgetBundle {
    var body: some Widget { NowMirrorWidget() }
}
