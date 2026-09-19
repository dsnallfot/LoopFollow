import Foundation

struct TrainingSessionEntry: Identifiable, Equatable {
    enum Category: String, Equatable {
        case metaQuest = "Meta Quest"
        case gympa = "Gympa"
        case highActivity = "Hög aktivitet"
        case training = "Övrig träning"

        var displayName: String { rawValue }
    }

    let id = UUID()
    let category: Category
    let startDate: Date
    let endDate: Date?

    var trainingType: String {
        category.displayName
    }

    var isOngoing: Bool {
        endDate == nil
    }

    var durationMinutes: Int? {
        guard let endDate else { return nil }
        let seconds = max(0, endDate.timeIntervalSince(startDate))
        return Int((seconds / 60.0).rounded())
    }
}
