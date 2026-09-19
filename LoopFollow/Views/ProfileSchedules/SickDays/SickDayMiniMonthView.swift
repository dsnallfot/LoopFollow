import SwiftUI
import UIKit


@available(iOS 16.0, *)
struct SickDayMiniMonthView: View {
    let year: Int
    let month: Int
    let calendar: Calendar
    let monthName: String
    let weekdayHeaders: [String]
    let sickDaySet: Set<Date>
    let sickDayEntriesByDay: [Date: SickDayHistoryEntry]
    let onTapSickDay: (SickDayHistoryEntry) -> Void

    private var monthDates: [Date?] {
        guard let firstDay = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: firstDay) else {
            return []
        }

        let weekday = calendar.component(.weekday, from: firstDay)
        let offset = (weekday - calendar.firstWeekday + 7) % 7

        var result: [Date?] = Array(repeating: nil, count: offset)
        for day in range {
            if let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) {
                result.append(date)
            }
        }
        return result
    }

    private func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    private func isSickDay(_ date: Date) -> Bool {
        sickDaySet.contains(calendar.startOfDay(for: date))
    }

    private func sickDayEntry(for date: Date) -> SickDayHistoryEntry? {
        sickDayEntriesByDay[calendar.startOfDay(for: date)]
    }

    private func textColor(for date: Date) -> Color {
        if isSickDay(date) {
            return .white
        }
        if isToday(date) {
            return .blue
        }
        return .primary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(monthName)
                .font(.title3.weight(.semibold))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 6) {
                ForEach(Array(weekdayHeaders.enumerated()), id: \.offset) { _, day in
                    Text(day)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(monthDates.enumerated()), id: \.offset) { _, date in
                    if let date {
                        let dayNumber = calendar.component(.day, from: date)

                        Text("\(dayNumber)")
                            .font(.system(size: 9, weight: isToday(date) || isSickDay(date) ? .semibold : .regular, design: .rounded))
                            .foregroundColor(textColor(for: date))
                            .frame(maxWidth: .infinity, minHeight: 15)
                            .background(
                                Group {
                                    if isSickDay(date) {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 15, height: 15)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white, lineWidth: isToday(date) ? 1 : 0)
                                            )
                                    } else if isToday(date) {
                                        Circle()
                                            .stroke(Color.white, lineWidth: 1)
                                            .frame(width: 15, height: 15)
                                    } else {
                                        Color.clear
                                    }
                                }
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if let entry = sickDayEntry(for: date) {
                                    onTapSickDay(entry)
                                }
                            }
                    } else {
                        Color.clear
                            .frame(maxWidth: .infinity, minHeight: 15)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

