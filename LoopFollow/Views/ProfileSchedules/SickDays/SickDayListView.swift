import SwiftUI
import UIKit

@available(iOS 26.0, *)
struct SickDayListView: View {
    let entries: [SickDayHistoryEntry]
    let dateFormatter: DateFormatter
    let onSelect: (SickDayHistoryEntry) -> Void
    let onDelete: (SickDayHistoryEntry) -> Void

    private static let sickDayMonthSectionFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "sv_SE")
        df.dateFormat = "MMMM yyyy"
        return df
    }()

    private var groupedSickDayEntries: [(title: String, countText: String, entries: [SickDayHistoryEntry])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: entries) { entry in
            let date = Date(timeIntervalSince1970: entry.date)
            let components = calendar.dateComponents([.year, .month], from: date)
            return calendar.date(from: components) ?? calendar.startOfDay(for: date)
        }

        return grouped
            .sorted { $0.key > $1.key }
            .map { monthDate, entries in
                let title = Self.sickDayMonthSectionFormatter.string(from: monthDate).capitalized
                let sortedEntries = entries.sorted { $0.date > $1.date }
                let count = sortedEntries.count
                let countText = count == 1 ? "1 dag" : "\(count) dagar"
                return (title: title, countText: countText, entries: sortedEntries)
            }
    }

    private var hasSickDayEntries: Bool {
        !entries.isEmpty
    }

    @ViewBuilder
    var body: some View {
        if hasSickDayEntries {
            List {
                ForEach(groupedSickDayEntries, id: \.title) { section in
                    Section(
                        header:
                            HStack {
                                Text(section.title)
                                Spacer()
                                Text(section.countText)
                                    .foregroundColor(.secondary)
                            }
                    ) {
                        ForEach(section.entries, id: \.date) { entry in
                            HStack {
                                Text(entry.notes)
                                    .font(.subheadline.monospacedDigit())
                                Spacer()
                                Text(dateFormatter.string(from: Date(timeIntervalSince1970: entry.date)))
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundColor(.secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onSelect(entry)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    onDelete(entry)
                                } label: {
                                    Label("Radera", systemImage: "trash")
                                }
                            }
                            .listRowBackground(Color(UIColor.systemGray).opacity(0.15))
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        } else {
            ContentUnavailableView(
                "Inga sjukdagar registrerade",
                systemImage: "medical.thermometer",
                description: Text("Automatiskt fångade eller manuellt tillagda sjukdagar kommer att visas här.")
            )
        }
    }
}
