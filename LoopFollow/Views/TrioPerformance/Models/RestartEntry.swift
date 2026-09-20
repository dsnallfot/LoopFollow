import Foundation

struct RestartEntry {
    let date: Date
    let note: String
}


extension RestartEntry {
    /// Entries are newest first. Prefer the latest restart on the chosen day;
    /// otherwise use the closest calendar day, preferring the newer one on a tie.
    static func nearestIndex(to date: Date, in entries: [RestartEntry], calendar: Calendar = .current) -> Int? {
        let selectedDay = calendar.startOfDay(for: date)
        return entries.indices.min { lhs, rhs in
            func distance(_ index: Int) -> Int {
                let day = calendar.startOfDay(for: entries[index].date)
                return abs(calendar.dateComponents([.day], from: selectedDay, to: day).day ?? 0)
            }
            return distance(lhs) < distance(rhs)
        }
    }
}
