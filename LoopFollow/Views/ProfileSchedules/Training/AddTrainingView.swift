import SwiftUI
import UIKit


@available(iOS 16.0, *)
struct AddTrainingView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedStartTime: Date = Date()
    @State private var selectedEndTime: Date = Date()
    @State private var selectedType: TrainingType = .metaquest
    @State private var isSaving: Bool = false

    enum TrainingType: String, CaseIterable, Identifiable {
        case metaquest = "Meta Quest"
        case othertraining = "Övrig träning"

        var id: String { rawValue }

        var startNote: String {
            switch self {
            case .metaquest:
                return "Meta Quest spel startades"
            case .othertraining:
                return "Träning startades"
            }
        }

        var endNote: String {
            switch self {
            case .metaquest:
                return "Meta Quest spel avslutades"
            case .othertraining:
                return "Träning avslutades"
            }
        }
    }

    var body: some View {
        ZStack {
            ThemeBackground()
                .ignoresSafeArea()

            VStack(alignment: .leading) {
                HStack {
                    Text("Starttid:")
                        .font(.body)
                        .fontWeight(.regular)
                        .foregroundColor(Color.secondary)
                    Spacer()
                    
                    DatePicker(
                        "Starttid",
                        selection: $selectedStartTime,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                    .environment(\.locale, Locale(identifier: "sv_SE"))
                    .labelsHidden()
                }
                HStack {
                    Text("Sluttid:")
                        .font(.body)
                        .fontWeight(.regular)
                        .foregroundColor(Color.secondary)
                    Spacer()
                    
                    DatePicker(
                        "Sluttid",
                        selection: $selectedEndTime,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                    .environment(\.locale, Locale(identifier: "sv_SE"))
                    .labelsHidden()
                }
                
                .padding(.bottom, 20)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(TrainingType.allCases) { type in
                        Button {
                            selectedType = type
                        } label: {
                            HStack {
                                Text(type.rawValue)
                                    .font(.body.monospacedDigit())
                                Spacer()
                                if selectedType == type {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(UIColor.systemGray).opacity(0.15))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Lägg till Träningspass")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Avbryt") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Spara") {
                    saveTrainingNotes()
                }
                .disabled(isSaving)
            }
        }
    }
    
    private func saveTrainingNotes() {
        guard selectedEndTime >= selectedStartTime else { return }

        isSaving = true

        Task {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            isoFormatter.timeZone = TimeZone(secondsFromGMT: 0)

            let utcOffsetMinutes = TimeZone.current.secondsFromGMT(for: selectedStartTime) / 60
            
            // enteredBy: use caregiverName if available, else fall back
            let caregiver = UserDefaultsRepository.caregiverName.value.trimmingCharacters(in: .whitespacesAndNewlines)
            let enteredBy = caregiver.isEmpty ? "LoopFollow" : "\(caregiver)"

            let startBody: [String: Any] = [
                "notes": selectedType.startNote,
                "eventType": "Note",
                "enteredBy": enteredBy,
                "created_at": isoFormatter.string(from: selectedStartTime),
                "utcOffset": utcOffsetMinutes
            ]

            let endBody: [String: Any] = [
                "notes": selectedType.endNote,
                "eventType": "Note",
                "enteredBy": enteredBy,
                "created_at": isoFormatter.string(from: selectedEndTime),
                "utcOffset": utcOffsetMinutes
            ]

            do {
                _ = try await NightscoutUtils.executePostRequestRaw(eventType: .treatments, body: startBody)
                _ = try await NightscoutUtils.executePostRequestRaw(eventType: .treatments, body: endBody)

                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                LogManager.shared.log(
                    category: .nightscout,
                    message: "⚠️ Failed to save manual training notes: \(error.localizedDescription)",
                    isDebug: true
                )

                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
}

