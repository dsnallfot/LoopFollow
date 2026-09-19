import SwiftUI
import UIKit


private struct TrainingSessionRow: View {
    let session: TrainingSessionEntry

    private static let startFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "sv_SE")
        df.dateFormat = "yyyy-MM-dd, HH:mm"
        return df
    }()

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(leftText)
                .font(.subheadline.monospacedDigit())
                .foregroundColor(.primary)

            Spacer(minLength: 8)

            Text(Self.startFormatter.string(from: session.startDate))
                .font(.subheadline.monospacedDigit())
                .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
    }

    private var leftText: String {
        let durationText: String
        if session.isOngoing {
            durationText = "Pågår"
        } else if let minutes = session.durationMinutes {
            durationText = "\(minutes) min"
        } else {
            durationText = "Pågår"
        }

        return "\(session.trainingType) (\(durationText))"
    }
}

@available(iOS 17.0, *)
struct TrainingSessionsView: View {
    let sessions: [TrainingSessionEntry]
    let onTapSession: (TrainingSessionEntry) -> Void

    var body: some View {
        Group {
            if sessions.isEmpty {
                ContentUnavailableView(
                    "Inga träningssessioner registrerade",
                    systemImage: "figure.run",
                    description: Text("Registrerade träningssessioner från Nightscout-noteringar kommer att visas här.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clear)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                            TrainingSessionRow(session: session)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 16)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onTapSession(session)
                                }

                            if index < sessions.count - 1 {
                                Divider()
                                    .padding(.leading, 18)
                                    .padding(.trailing, 18)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(Color(UIColor.systemGray).opacity(0.15))
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
                .background(Color.clear)
            }
        }
        .navigationTitle("Träningssessioner")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.clear)
    }
}

