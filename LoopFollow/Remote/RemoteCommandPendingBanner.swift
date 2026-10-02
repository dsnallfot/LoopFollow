import SwiftUI

struct RemoteCommandPendingBanner: View {
    @ObservedObject private var tracker: RemoteCommandReceiptTracker

    init(tracker: RemoteCommandReceiptTracker = .shared) {
        self.tracker = tracker
    }

    var body: some View {
        if !tracker.pending.isEmpty {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                VStack(alignment: .leading, spacing: 8) {
                    Label("Väntar på registrering i Nightscout", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                    Text("Ett remotekommando väntar på registrering i Nightscout. Skicka-knapparna är tillfälligt låsta. Efter 30 sekunder kan du avfärda varningen.")
                        .font(.subheadline)
                    ForEach(tracker.pending) { command in
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(command.title) · \(command.sentAt, style: .time)")
                                .font(.caption)
                            Spacer()
                            if context.date.timeIntervalSince(command.sentAt) >= RemoteCommandReceiptTracker.dismissalDelay {
                                Button("Avfärda") { tracker.dismiss(id: command.id) }
                                    .font(.subheadline.bold())
                                    .buttonStyle(.bordered)
                                    .tint(.white)
                                    .accessibilityLabel("Avfärda varning för \(command.title)")
                            }
                        }
                    }
                    if tracker.pending.contains(where: { context.date.timeIntervalSince($0.sentAt) >= RemoteCommandReceiptTracker.dismissalDelay }) {
                        Text("Ingen matchande registrering har hittats. Avfärda tar bara bort varningen och avbryter inte kommandot.")
                            .font(.caption)
                    }
                }
                .foregroundColor(.white)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 0.65, green: 0.05, blue: 0.08), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
        }
    }
}

#if DEBUG
struct RemoteCommandPendingBanner_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            RemoteCommandPendingBanner(tracker: example(age: 15))
                .previewDisplayName("Väntar på Nightscout")
            RemoteCommandPendingBanner(tracker: example(age: 31))
                .preferredColorScheme(.dark)
                .previewDisplayName("Kan avfärdas efter 30 sekunder")
        }
        .previewLayout(.sizeThatFits)
    }

    private static func example(age: TimeInterval) -> RemoteCommandReceiptTracker {
        let tracker = RemoteCommandReceiptTracker()
        let date = Date().addingTimeInterval(-age)
        let message = PushMessage(aps: .init(alert: ""), user: "Skolan", commandType: .combo,
                                  carbs: 3, sharedSecret: "", timestamp: date.timeIntervalSince1970,
                                  overrideName: "Låg")
        tracker.track(message, id: "preview", site: "preview", now: date)
        return tracker
    }
}
#endif
