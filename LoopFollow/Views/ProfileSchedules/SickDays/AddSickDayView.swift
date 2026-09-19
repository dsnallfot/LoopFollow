import SwiftUI
import UIKit


@available(iOS 16.0, *)
struct AddSickDayView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDate: Date = Date()
    @State private var selectedType: SickDayType = .forkyld

    enum SickDayType: String, CaseIterable, Identifiable {
        case forkyld = "🤧 Förkyld"
        case magsjuka = "🤢 Magsjuka"
        case sjuk = "🤒 Sjuk"

        var id: String { rawValue }
    }

    var body: some View {
        ZStack {
            ThemeBackground()
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                DatePicker(
                    "Datum",
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.compact)
                .environment(\.locale, Locale(identifier: "sv_SE"))
                .labelsHidden()

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(SickDayType.allCases) { type in
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
        .navigationTitle("Lägg till sjukdag")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Avbryt") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Spara") {
                    Storage.shared.addManualSickDay(for: selectedDate, notes: selectedType.rawValue)
                    dismiss()
                }
            }
        }
    }
}
