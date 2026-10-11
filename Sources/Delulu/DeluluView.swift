import AppKit
import DeluluCore
import SwiftUI

private enum Palette {
    static let surface = Color(red: 0.141, green: 0.149, blue: 0.153)
    static let inset = Color(red: 0.105, green: 0.113, blue: 0.117)
    static let border = Color(red: 0.205, green: 0.215, blue: 0.220)
    static let text = Color(red: 0.93, green: 0.93, blue: 0.91)
    static let muted = Color(red: 0.60, green: 0.62, blue: 0.63)
    static let focus = Color(red: 0.68, green: 0.77, blue: 0.80)
}

struct DeluluView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var navigation: Navigation

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Text("delulu").font(.system(size: 18, weight: .semibold)).tracking(-0.5)
                Spacer()
                Button {
                    navigation.page = navigation.page == .profile ? .compose : .profile
                } label: {
                    Image(systemName: navigation.page == .profile ? "xmark" : "slider.horizontal.3")
                        .frame(width: 28, height: 28).contentShape(Circle())
                }
                .buttonStyle(QuietButtonStyle())
                .help(navigation.page == .profile ? "Close settings" : "Settings")
                .accessibilityLabel(navigation.page == .profile ? "Close settings" : "Settings")
                .disabled(model.isSending)
            }
            if navigation.page == .profile {
                ProfileView(model: model) { navigation.page = .compose }
            } else {
                ScheduleView(model: model, dismiss: navigation.dismiss)
            }
            if let error = model.error {
                Text(error).font(.caption).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                if model.state.schedule != nil {
                    Circle().fill(model.permission == .allowed ? Color.green : Color.orange).frame(width: 5, height: 5)
                    Text(model.permission == .allowed ? "Active" : "Notifications disabled")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Stop") { model.stop() }.buttonStyle(.plain).font(.caption).disabled(model.isSending)
                }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }.buttonStyle(.plain)
                    .font(.caption).foregroundStyle(.secondary).disabled(model.isSending)
            }
        }
        .padding(20)
        .frame(width: 344)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.clear)
        .foregroundStyle(Palette.text)
        .tint(Palette.focus)
        .preferredColorScheme(.dark)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { navigation.resize($0) }
    }
}

private struct ScheduleView: View {
    @ObservedObject var model: AppModel
    var dismiss: () -> Void
    @State private var mode: MessageMode = .outreach
    @State private var cadence: DeliveryCadence = .fifteenMinutes
    @State private var sound = true
    @State private var sendingNow = false
    @State private var applying = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 5) {
                ForEach(MessageMode.allCases) { option in
                    Button { mode = option } label: {
                        Label(option.title, systemImage: option.symbol)
                            .font(.system(size: 12, weight: .medium))
                            .frame(maxWidth: .infinity).frame(height: 38)
                            .contentShape(RoundedRectangle(cornerRadius: 11))
                    }
                    .buttonStyle(SelectionStyle(selected: mode == option))
                    .accessibilityAddTraits(mode == option ? .isSelected : [])
                }
            }
            .padding(4)
            .background(Palette.inset, in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(Palette.border))

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Repeat").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                    Spacer()
                    Button { sound.toggle() } label: {
                        Image(systemName: sound ? "speaker.wave.2" : "speaker.slash")
                            .font(.system(size: 12)).frame(width: 24, height: 20)
                    }.buttonStyle(.plain).help(sound ? "Mute notifications" : "Enable sound")
                        .accessibilityLabel(sound ? "Mute notifications" : "Enable sound")
                }
                HStack(spacing: 6) {
                    ForEach(DeliveryCadence.allCases) { option in
                        Button { cadence = option } label: {
                            Text(shortTitle(option)).font(.system(size: 11, weight: .medium))
                                .frame(maxWidth: .infinity).frame(height: 32)
                                .contentShape(RoundedRectangle(cornerRadius: 9))
                        }
                        .buttonStyle(SelectionStyle(selected: cadence == option, cornerRadius: 9))
                        .accessibilityLabel(option.title)
                        .accessibilityAddTraits(cadence == option ? .isSelected : [])
                    }
                }
            }
            HStack(spacing: 8) {
                PanelAction(title: "Send now", busy: sendingNow) {
                    Task {
                        sendingNow = true
                        defer { sendingNow = false }
                        await model.sendNow(mode: mode, sound: sound)
                    }
                }
                PanelAction(title: "Okay", busy: applying) {
                    Task {
                        applying = true
                        defer { applying = false }
                        if await model.apply(mode: mode, cadence: cadence, sound: sound) { dismiss() }
                    }
                }.keyboardShortcut(.defaultAction)
            }.disabled(model.isSending || model.storageBlocked)
            if model.permission == .denied {
                Button("Notification settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                }.buttonStyle(.plain).font(.caption)
            }
        }
        .disabled(model.isSending)
        .onAppear {
            mode = model.state.mode
            cadence = model.state.cadence
            sound = model.state.soundEnabled
        }
    }
    private func shortTitle(_ cadence: DeliveryCadence) -> String {
        switch cadence {
        case .minute: "1 min"
        case .fiveMinutes: "5 min"
        case .fifteenMinutes: "15 min"
        case .hour: "1 hour"
        case .threeHours: "3 hours"
        }
    }

}

private struct ProfileView: View {
    @ObservedObject var model: AppModel
    var done: () -> Void
    @State private var draft = DreamProfile()

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            field("Your first name", placeholder: "Alex", text: $draft.name)
            field("Dream role", placeholder: "Product Designer", text: $draft.role)
            field("Your standout skill · optional", placeholder: "Making complex things feel simple", text: $draft.strength)
            field("Compensation · optional", placeholder: "$180,000 / year", text: $draft.compensation)
            field("Work setup · optional", placeholder: "Remote", text: $draft.location)
            Text("Compensation and work setup appear in offer messages.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if let validation = draft.validationError {
                Text(validation).font(.caption).foregroundStyle(.red)
            }
            PanelAction(title: "Save my dream job", busy: model.isSending) {
                Task { if await model.saveProfile(draft) { done() } }
            }.keyboardShortcut(.defaultAction)
                .disabled(draft.validationError != nil || model.storageBlocked || model.isSending)
        }.disabled(model.isSending).onAppear { draft = model.state.profile }
    }

    private func field(_ title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField(placeholder, text: text).textFieldStyle(.plain)
                .padding(.horizontal, 10).padding(.vertical, 9)
                .background(Palette.inset, in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Palette.border))
                .accessibilityLabel(title)
        }
    }
}

private struct PanelAction: View {
    var title: String
    var busy: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if busy { ProgressView().controlSize(.small) }
                Text(title).font(.system(size: 12, weight: .semibold))
            }.frame(maxWidth: .infinity).frame(height: 40)
                .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(SelectionStyle(selected: false, cornerRadius: 12, prominent: true))
    }
}

private struct SelectionStyle: ButtonStyle {
    var selected: Bool
    var cornerRadius: CGFloat = 11
    var prominent = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        configuration.label
            .foregroundStyle(selected || prominent ? Palette.text : Palette.muted)
            .background(shape.fill(Palette.inset))
            .overlay {
                shape.strokeBorder(selected ? Palette.focus : Palette.border, lineWidth: selected ? 2 : 1)
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.65 : 1) : 0.4)
    }
}

private struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Palette.muted)
            .background(Palette.inset, in: Circle())
            .overlay(Circle().strokeBorder(Palette.border))
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
