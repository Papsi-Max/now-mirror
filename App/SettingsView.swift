import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var tab = Tab.general

    enum Tab: String, CaseIterable, Identifiable {
        case general = "General", about = "About"
        var id: Self { self }
        var icon: String { self == .general ? "gearshape" : "info.circle" }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                ForEach(Tab.allCases) { t in
                    Button { tab = t } label: {
                        VStack(spacing: 3) {
                            Image(systemName: t.icon).font(.system(size: 18))
                            Text(t.rawValue).font(.system(size: 11))
                        }
                        .frame(width: 76, height: 48)
                        .background(tab == t ? Color.accentColor.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(tab == t ? Color.accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 10)

            switch tab {
            case .general: GeneralTab(model: model)
            case .about: AboutTab(model: model)
            }
        }
        .frame(width: 480, height: 560)
    }
}

struct GeneralTab: View {
    @ObservedObject var model: AppModel
    @AppStorage("showIcon") private var showIcon = true
    @State private var openAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Section {
                Toggle("Open at login", isOn: Binding(get: { openAtLogin }, set: setLogin))
                Toggle("Show icon in menu bar", isOn: $showIcon)
            } footer: {
                Text(loginError ?? "Hide the icon and Now Mirror keeps running in the background. Open Now Mirror again at any time to show these settings.")
            }
            Section {
                LabeledContent("Status") {
                    HStack(spacing: 6) {
                        Circle().fill(model.error == nil ? Color.green : Color.orange).frame(width: 8, height: 8)
                        Text(model.error ?? "Now Playing is readable").multilineTextAlignment(.trailing)
                    }
                }
                LabeledContent("Currently") {
                    Text(model.nowPlaying ?? "Nothing playing").foregroundStyle(.secondary).lineLimit(1)
                }
            } header: {
                Text("Now Playing")
            }
            Section {
                Text("Right-click the desktop (or open Notification Center) › Edit Widgets › search for “Now Mirror”, then pick a size. Keep the app running so the widget stays up to date.")
                    .font(.callout).foregroundStyle(.secondary)
            } header: {
                Text("Add the widget")
            }
        }
        .formStyle(.grouped)
    }

    private func setLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = "Could not change the login item: \(error.localizedDescription). You can add Now Mirror in System Settings → General → Login Items instead."
        }
        openAtLogin = SMAppService.mainApp.status == .enabled
    }
}

struct AboutTab: View {
    @ObservedObject var model: AppModel
    @State private var copied = false

    private var version: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?" }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 84, height: 84)
                    Text("Now Mirror").font(.title2.bold())
                    Text("Version \(version)").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 8)
            }
            Section {
                LabeledContent("Status") {
                    Text("👑 Free").foregroundStyle(.purple)
                }
            }
            Section {
                LabeledContent("Developed by") {
                    Link("Maxime Boulogne ↗", destination: URL(string: "https://maximeboulogne.com")!)
                }
                LabeledContent("Source code") {
                    Link("papsi-max/now-mirror ↗", destination: URL(string: "https://github.com/Papsi-Max/now-mirror")!)
                }
            }
            Section {
                Button(copied ? "Copied" : "Copy diagnostics") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(model.diagnostics(), forType: .string)
                    copied = true
                }
            } footer: {
                Text("Useful when reporting a problem.")
            }
            Section {
                Text("Now Mirror mirrors macOS Now Playing in a widget. It relies on MediaRemote, a private Apple API, and may stop working after a macOS update. It is an independent project and is not affiliated with Qobuz, Spotify or Apple.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
