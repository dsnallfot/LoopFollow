import SwiftUI
import UIKit

@available(iOS 26.0, *)
struct WeekdayFilterView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedWeekdays: Set<Int>
    @Binding var usePumpChangeDays: Bool
    @Binding var useNonPumpChangeDays: Bool
    @Binding var useSensorChangeDays: Bool
    @Binding var useNonSensorChangeDays: Bool
    @Binding var useSickDays: Bool
    @Binding var useNonSickDays: Bool

    /// Mappar Calendar.weekday (1–7) till svenska kortnamn.
    private let weekdayOrder: [Int] = [2, 3, 4, 5, 6, 7, 1] // Mån–Sön i visningsordning
    private let weekdayLabels: [Int: String] = [
        1: "Sön",
        2: "Mån",
        3: "Tis",
        4: "Ons",
        5: "Tor",
        6: "Fre",
        7: "Lör"
    ]

    private var allWeekdaysSet: Set<Int> { Set(1...7) }

    private var anySpecialFilterActive: Bool {
        usePumpChangeDays || useNonPumpChangeDays || useSensorChangeDays || useNonSensorChangeDays || useSickDays || useNonSickDays
    }

    var body: some View {
        ZStack {
            ThemeBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Rad 1: veckodagar + "Alla"
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Veckodagar")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        HStack(spacing: 12) {
                            let allSelected = (selectedWeekdays == allWeekdaysSet) && !anySpecialFilterActive

                            // Alla-knapp
                            Button {
                                if allSelected {
                                    // Avmarkera alla dagar
                                    selectedWeekdays = []
                                } else {
                                    // Markera alla dagar och slå av specialfilter
                                    selectedWeekdays = allWeekdaysSet
                                }
                                resetSpecialFilters()
                            } label: {
                                Text("Alla")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .frame(width: 44, height: 32)
                                    .background(
                                        Capsule()
                                            .fill(allSelected ? Color.accentColor : Color.gray.opacity(0.4))
                                    )
                                    .foregroundColor(.white)
                            }
                            .buttonStyle(.plain)

                            // Mån–Sön
                            ForEach(weekdayOrder, id: \.self) { weekday in
                                let isSelected = selectedWeekdays.contains(weekday) && !anySpecialFilterActive
                                Button {
                                    if isSelected {
                                        // Tillåt att alla kan avmarkeras om man vill se en tom lista.
                                        selectedWeekdays.remove(weekday)
                                    } else {
                                        selectedWeekdays.insert(weekday)
                                    }
                                    // Att manuellt pilla på veckodagar stänger av specialfilter
                                    resetSpecialFilters()
                                } label: {
                                    Text(weekdayLabels[weekday] ?? "?")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .frame(width: 32, height: 32)
                                        .background(
                                            Circle()
                                                .fill(isSelected ? Color.accentColor : Color.gray.opacity(0.4))
                                        )
                                        .foregroundColor(.white)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Rad 2: Andra filter
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Andra filter")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        HStack(spacing: 8) {
                            specialFilterButton("Pumpbytesdagar", isOn: $usePumpChangeDays)
                            specialFilterButton("Sensorbytesdagar", isOn: $useSensorChangeDays)
                        }

                        HStack(spacing: 8) {
                            specialFilterButton("Ej pumpbytesdagar", isOn: $useNonPumpChangeDays)
                            specialFilterButton("Ej sensorbytesdagar", isOn: $useNonSensorChangeDays)
                        }

                        HStack(spacing: 8) {
                            specialFilterButton("Sjukdagar", isOn: $useSickDays)
                            specialFilterButton("Ej sjukdagar", isOn: $useNonSickDays)
                        }
                    }
                }
                .padding()
            }
        }
    }

    private func resetSpecialFilters() {
        usePumpChangeDays = false
        useNonPumpChangeDays = false
        useSensorChangeDays = false
        useNonSensorChangeDays = false
        useSickDays = false
        useNonSickDays = false
    }

    private func specialFilterButton(_ title: String, isOn: Binding<Bool>) -> some View {
        Button {
            let newValue = !isOn.wrappedValue
            resetSpecialFilters()
            isOn.wrappedValue = newValue
            selectedWeekdays = newValue ? [] : allWeekdaysSet
        } label: {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(
                    Capsule()
                        .fill(isOn.wrappedValue ? Color.accentColor : Color.gray.opacity(0.4))
                )
                .foregroundColor(.white)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn.wrappedValue ? .isSelected : [])
    }

}

