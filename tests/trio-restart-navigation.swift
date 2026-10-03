import Foundation

// Run with RestartEntry.swift using swiftc; no simulator or Nightscout required.
@main
struct RestartNavigationTests {
    static func main() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        func date(_ day: Int, month: Int = 3, hour: Int = 12) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
        }
        func entry(_ day: Int, month: Int = 3, hour: Int = 12) -> RestartEntry {
            RestartEntry(date: date(day, month: month, hour: hour), note: "Trio startades om")
        }
        func nearest(_ day: Date, _ entries: [RestartEntry]) -> Int? {
            RestartEntry.nearestIndex(to: day, in: entries, calendar: calendar)
        }
        let entries = [entry(31), entry(29, hour: 21), entry(29, hour: 8), entry(27)]
        precondition(nearest(date(29, hour: 0), entries) == 1, "Latest restart on selected day")
        precondition(nearest(date(30), entries) == 0, "Newer day wins an equal-distance tie")
        precondition(nearest(date(28), entries) == 1, "Calendar days across spring DST")
        precondition(nearest(date(1), entries) == 3, "Before oldest restart")
        precondition(nearest(date(5, month: 4), entries) == 0, "After newest restart")
        precondition(nearest(date(29), []) == nil, "Empty history")
        precondition(nearest(date(1), [entry(31)]) == 0, "Single restart")
        precondition(nearest(date(25, month: 10), [entry(26, month: 10), entry(24, month: 10)]) == 0,
                     "Calendar days across autumn DST")
        print("Restart date navigation: 8 checks passed")
    }
}
