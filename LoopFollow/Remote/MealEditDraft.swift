import Foundation

struct MealEditDraft {
    static let historyLimit: TimeInterval = (23 * 60 + 55) * 60
    var carbs: String
    var protein: String
    var fat: String
    var notes: String
    var date: Date

    init(raw: [String: Any], date: Date) {
        func text(_ key: String) -> String {
            if let number = raw[key] as? NSNumber { return number.stringValue }
            return raw[key] as? String ?? "0"
        }
        carbs = text("carbs")
        protein = text("protein")
        fat = text("fat")
        notes = raw["notes"] as? String ?? raw["foodType"] as? String ?? ""
        self.date = Date(timeIntervalSince1970: floor(date.timeIntervalSince1970))
    }

    static func canEdit(_ originalDate: Date, now: Date = Date()) -> Bool {
        let age = now.timeIntervalSince(originalDate)
        return age >= 0 && age < historyLimit
    }

    static func number(_ text: String) -> Double? {
        Double(text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: "."))
    }

    var nutrients: [Int]? {
        let values = [carbs, protein, fat].compactMap(Self.number)
        guard values.count == 3, values.allSatisfy({ $0.isFinite && $0 >= 0 && $0 <= 9999 && $0.rounded(.towardZero) == $0 }) else { return nil }
        return values.map(Int.init)
    }

    func differs(from original: MealEditDraft) -> Bool {
        [carbs, protein, fat].map(Self.number) != [original.carbs, original.protein, original.fat].map(Self.number) ||
            notes.trimmingCharacters(in: .whitespacesAndNewlines) != original.notes.trimmingCharacters(in: .whitespacesAndNewlines) ||
            floor(date.timeIntervalSince1970) != floor(original.date.timeIntervalSince1970)
    }

    func validationError(originalDate: Date, limits: [Double], now: Date = Date()) -> String? {
        guard Self.canEdit(originalDate, now: now) else { return "Måltiden är för gammal för att redigeras i Trio." }
        guard let nutrients else { return "Ange kolhydrater, protein och fett i hela gram mellan 0 och 9999." }
        guard limits.count == 3 else { return "Kunde inte läsa måltidsgränserna." }
        for (index, name) in ["kolhydrater", "protein", "fett"].enumerated() where Double(nutrients[index]) > limits[index] {
            return String(format: "Max %@ är %.0f g.", name, limits[index])
        }
        guard date.timeIntervalSince1970.isFinite, date <= now, now.timeIntervalSince(date) < Self.historyLimit else {
            return "Välj en måltidstid inom de senaste 23 timmarna och 55 minuterna."
        }
        return nil
    }
}
