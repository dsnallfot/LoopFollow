import SwiftUI
import UIKit

// MARK: - AddUserDataView placeholder

@available(iOS 16.0, *)
struct AddUserDataView: View {
    @Environment(\.dismiss) var dismiss
    var existingEntry: UserProfileEntry? = nil
    var isReadOnly: Bool = false

    @State var name: String = ""
    @State var birthDate: Date = Date()
    @State var t1dSinceDate: Date = Date()
    @State var updatedDate: Date = Date()
    @State var heightText: String = ""
    @State var weightText: String = ""
    @State var tddText: String = ""
    @State var actualMorningCRText: String = ""
    @State var actualDayCRText: String = ""
    @State var actualBasalText: String = ""
    @State var actualAverageISFText: String = ""
    @State var hbA1cText: String = ""

    var body: some View {
        ZStack {
            ThemeBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    UserProfileFieldsView(
                        name: $name,
                        heightText: $heightText,
                        weightText: $weightText,
                        tddText: $tddText,
                        actualMorningCRText: $actualMorningCRText,
                        actualDayCRText: $actualDayCRText,
                        actualBasalText: $actualBasalText,
                        actualAverageISFText: $actualAverageISFText,
                        hbA1cText: $hbA1cText,
                        birthDate: $birthDate,
                        t1dSinceDate: $t1dSinceDate,
                        updatedDate: $updatedDate,
                        insulinPerKg: insulinPerKg
                    )
                    UserProfileWalshView(
                        walsh500CR: .init(value: walsh500CR, percentage: walshPercentageOfActual500CR),
                        walsh300CR: .init(value: walsh300CR, percentage: walshPercentageOfActual300CR),
                        walshWeightCR: .init(value: walshWeightCR, percentage: walshPercentageOfActualWeightCR),
                        walsh100ISF: .init(value: walsh100ISF, percentage: walshPercentageOfActualISF),
                        walshTDD: .init(value: walshTDD, percentage: walshPercentageOfActualTDD),
                        walshBasal: .init(value: walshBasal, percentage: walshPercentageOfActualBasal),
                        walshBasalPerHour: .init(value: walshBasalPerHour, percentage: walshPercentageOfActualBasalPerHour)
                    )
                }
                .font(.subheadline)
                .padding()
            }
        }
        .navigationTitle(
            isReadOnly
            ? "Registrerad data"
            : (existingEntry == nil ? "Registrera ny data" : "Ändra registrering")
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Avbryt") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                if isReadOnly {
                    Button("Klar") {
                        dismiss()
                    }
                } else {
                    Button("Spara") {
                        saveProfile()
                    }
                }
            }
        }
        .onAppear(perform: loadExistingProfile)
        .onChange(of: updatedDate) { newDate in
            // Auto-populera bara för NYA registreringar (existingEntry == nil) och ej i read-only-läge
            guard existingEntry == nil, !isReadOnly else { return }
            let calendar = Calendar.current
            clearActualFields()

            if calendar.isDateInToday(newDate) {
                populateActualFieldsFromCurrentProfile()
            }
        }
    }

}
