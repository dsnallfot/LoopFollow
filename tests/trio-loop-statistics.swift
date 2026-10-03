import Foundation

// swiftc LoopFollow/Views/TrioPerformance/Models/LoopEntry.swift tests/trio-loop-statistics.swift -o /tmp/trio-loop-statistics
@main
struct TrioLoopStatisticsTests {
    static func main() {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = Date(timeIntervalSince1970: 0)
        func hour(_ h: Double) -> Date { start.addingTimeInterval(h * 3600) }
        func stats(_ dates: [Date], counts: [Int] = [0, 2, 1], end: Double = 60) -> LoopStatistics {
            LoopStatistics(counts: counts, dates: dates, start: start, end: hour(end), calendar: utcCalendar)
        }
        let mixed = stats([hour(50), hour(30), hour(25)])
        assert(mixed.total == 3)
        assert(mixed.daysWithErrors == 2)
        assert(mixed.averagePerDay == 1)
        assert(mixed.averagePerErrorDay == 1.5)
        assert(abs(mixed.percentageOfDaysWithErrors - 200.0 / 3) < 0.001)
        assert(mixed.maximumPerDay == 2)
        assert(mixed.longestErrorFreeHours == 25, "Include the initial gap")
        assert(stats([hour(1), hour(40)]).longestErrorFreeHours == 39, "Include gaps between errors")
        assert(stats([hour(1), hour(2)]).longestErrorFreeHours == 58, "Include ongoing streak")
        let empty = stats([], counts: [0, 0, 0])
        assert(empty.longestErrorFreeHours == 60)
        assert(empty.averagePerDay == 0 && empty.averagePerErrorDay == nil)
        assert(empty.percentageOfDaysWithErrors == 0)
        assert(stats([hour(-10), hour(100)]).longestErrorFreeHours == 60, "Clip to selected period")
        assert(stats([hour(0), hour(60)]).longestErrorFreeHours == 60)
        assert(stats([hour(10), hour(10)], end: 10.5).longestErrorFreeHours == 10)
        for days in [7, 14, 30, 90] {
            let period = stats([], counts: Array(repeating: 0, count: days), end: Double(days * 24 - 12))
            assert(period.longestErrorFreeHours == days * 24 - 12)
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        let dstStart = calendar.date(from: DateComponents(year: 2026, month: 3, day: 29))!
        let dstEnd = calendar.date(byAdding: .day, value: 1, to: dstStart)!
        let dst = LoopStatistics(counts: [0], dates: [], start: dstStart, end: dstEnd)
        assert(dst.longestErrorFreeHours == 23, "Use elapsed hours across daylight saving")
        let halfDay = stats([hour(1)], counts: [1], end: 12)
        assert(halfDay.expectedLoops == 144)
        assert(abs(halfDay.successfulLoopPercentage! - 14300.0 / 144) < 0.001)
        assert(mixed.expectedLoops == 288 * 2 + 144)
        assert(abs(mixed.successfulLoopPercentage! - 99.5833333333) < 0.001)
        assert(stats([], counts: [0], end: 0).successfulLoopPercentage == nil)
        assert(stats([], counts: [0], end: 4.0 / 60).expectedLoops == 0)
        assert(stats([], counts: [0], end: 5.0 / 60).expectedLoops == 1)
        assert(stats([], counts: [0], end: 12).successfulLoopPercentage == 100)
        assert(stats([hour(0)], counts: [2], end: 5.0 / 60).successfulLoopPercentage == 0)
        let completedDST = LoopStatistics(counts: [0], dates: [], start: dstStart, end: dstEnd, calendar: calendar)
        assert(completedDST.expectedLoops == 288, "Completed days always contribute 288")
        for days in [7, 14, 30, 90] {
            assert(stats([], counts: Array(repeating: 0, count: days), end: Double(days * 24 - 12)).expectedLoops == (days - 1) * 288 + 144)
        }
        print("Loop statistics tests passed")
    }
}
