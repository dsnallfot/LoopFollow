import SwiftUI
import UIKit

@available(iOS 16.0, *)
struct UserProfileFieldsView: View {
    @Binding var name: String
    @Binding var heightText: String
    @Binding var weightText: String
    @Binding var tddText: String
    @Binding var actualMorningCRText: String
    @Binding var actualDayCRText: String
    @Binding var actualBasalText: String
    @Binding var actualAverageISFText: String
    @Binding var hbA1cText: String
    @Binding var birthDate: Date
    @Binding var t1dSinceDate: Date
    @Binding var updatedDate: Date
    let insulinPerKg: Double?

    var body: some View {
        // Inmatningsfält
        Group {
            HStack {
                Text("Namn:")
                Spacer()
                TextField("Förnamn Efternamn", text: $name)
                    .multilineTextAlignment(.trailing)
                if name == "" {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundColor(.red)
                }
            }

            HStack {
                Text("Längd:")
                Spacer()
                TextField("Ange längd", text: $heightText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                Text("cm")
                if heightText == "" {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundColor(.red)
                }
            }

            HStack {
                Text("Vikt:")
                Spacer()
                TextField("Ange vikt", text: $weightText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                Text("kg")
                if weightText == "" {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundColor(.red)
                }
            }

            HStack {
                Text("Total daglig dos (14d):")
                Spacer()
                TextField("Ange TDD", text: $tddText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                Text("E")
                if tddText == "" {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundColor(.red)
                }
            }

            HStack {
                Text("Aktuell CR (morgon):")
                Spacer()
                TextField("Ange CR (morgon)", text: $actualMorningCRText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                Text("g/E")
                if actualMorningCRText == "" {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundColor(.red)
                }
            }

            HStack {
                Text("Aktuell CR (dag):")
                Spacer()
                TextField("Ange CR (dag)", text: $actualDayCRText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                Text("g/E")
                if actualDayCRText == "" {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundColor(.red)
                }
            }

            HStack {
                Text("Aktuell Basal (24h):")
                Spacer()
                TextField("Ange Basal", text: $actualBasalText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                Text("E/d")
                if actualBasalText == "" {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundColor(.red)
                }
            }

            HStack {
                Text("Aktuell ISF (medel):")
                Spacer()
                TextField("Ange ISF", text: $actualAverageISFText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                Text("mmol/L/E")
                if actualAverageISFText == "" {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundColor(.red)
                }
            }

            HStack {
                Text("Insulinbehov/kg:")
                Spacer()
                Text(insulinPerKg.map { String(format: "%.2f", $0) } ?? "--")
                Text("E/kg/d")
            }

            HStack {
                Text("HbA1C (Blodprov):")
                Spacer()
                TextField("Ange HbA1C", text: $hbA1cText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                Text("mmol/mol")
                if hbA1cText == "" {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundColor(.red)
                }
            }

            Divider()
                .padding(.top, 4)

            HStack {
                Text("Födelsedatum:")
                Spacer()
                DatePicker(
                    "",
                    selection: $birthDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .environment(\.locale, Locale(identifier: "sv_SE"))
                .labelsHidden()
            }

            HStack {
                Text("T1D debutdatum:")
                Spacer()
                DatePicker(
                    "",
                    selection: $t1dSinceDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .environment(\.locale, Locale(identifier: "sv_SE"))
                .labelsHidden()
            }

            HStack {
                Text("Data uppdaterad:")
                Spacer()
                DatePicker(
                    "",
                    selection: $updatedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .environment(\.locale, Locale(identifier: "sv_SE"))
                .labelsHidden()
            }
        }

    }
}
