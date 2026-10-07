import Foundation

/// The same classification supplies the row title and the searchable Swedish names.
enum TreatmentCategory: Hashable {
    case meal, dextro, fatProtein, sensor, pump, insulin
    case other(String)

    init(eventType: String, foodType: String?, notes: String?) {
        switch eventType {
        case "Carb Correction":
            guard let foodType, !foodType.isEmpty else { self = .fatProtein; return }
            let note = notes?.hasPrefix("✎ ") == true ? String(notes!.dropFirst(2)) : (notes ?? "")
            self = !note.isEmpty && note.allSatisfy { $0 == "🍬" } ? .dextro : .meal
        case "Måltid": self = .meal
        case "Dextro": self = .dextro
        case "Site Change": self = .pump
        case "Insulin Change": self = .insulin
        case "Sensor Start", "Sensor Change", "Sensorbyte", "Sensorstart": self = .sensor
        default: self = .other(eventType)
        }
    }

    var title: String {
        switch self {
        case .meal: return "Måltid"
        case .dextro: return "Dextro"
        case .fatProtein: return "Fett & Protein"
        case .sensor: return "Sensorbyte"
        case .pump: return "Pumpbyte"
        case .insulin: return "Nytt insulin"
        case .other(let name): return name
        }
    }

    var searchText: String {
        let aliases: String
        switch self {
        case .meal: aliases = "mat måltider kolhydrater carb correction"
        case .dextro: aliases = "druvsocker kolhydrater carb correction"
        case .fatProtein: aliases = "fett/protein fpu carb correction"
        case .sensor: aliases = "sensorstart sensor start sensor change"
        case .pump: aliases = "pumbyte pump site change infusionsset kanyl"
        case .insulin: aliases = "insulinbyte insulin change"
        case .other("BG Check"): aliases = "fingerstick blodsockerkontroll blodsocker"
        case .other("Temp Basal"): aliases = "temporär basal basaldos"
        case .other("SMB"): aliases = "mikrobolus insulin"
        case .other("Bolus"), .other("Correction Bolus"), .other("Meal Bolus"):
            aliases = "bolus insulin"
        case .other("Exercise"), .other("Override"), .other("Temporary Override"):
            aliases = "override tillfällig profil träning"
        case .other("Note"): aliases = "notering anteckning"
        case .other("Announcement"): aliases = "meddelande notering"
        default: aliases = ""
        }
        return Self.normalize(title + " " + aliases)
    }

    static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "sv_SE"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }.joined(separator: " ")
    }
}

struct TreatmentSearchIndex {
    private struct Group {
        let text: String
        var records: [TreatmentJSON]
    }
    private var groups: [TreatmentCategory: Group] = [:]

    init(records: [TreatmentJSON]) {
        // A midnight entry can occur in adjacent legacy day files. Prefer one document.
        var seen = Set<String>()
        for record in records where seen.insert(record._id).inserted {
            let category = TreatmentCategory(eventType: record.eventType, foodType: record.foodType, notes: record.notes)
            if groups[category] == nil {
                groups[category] = Group(text: category.searchText, records: [])
            }
            groups[category]!.records.append(record)
        }
    }

    func matches(query: String, segment: Int, autoTypes: [String], manualTypes: [String]) -> [TreatmentJSON] {
        let words = TreatmentCategory.normalize(query).split(separator: " ")
        guard !words.isEmpty else { return [] }
        return groups.values.filter { group in words.allSatisfy { group.text.contains($0) } }
            .flatMap { $0.records }.filter { record in
                switch segment {
                case 1: return autoTypes.contains(record.eventType)
                case 2:
                    if record.eventType == "Carb Correction" { return !(record.foodType ?? "").isEmpty }
                    return manualTypes.contains(record.eventType)
                case 3: return !autoTypes.contains(record.eventType) && !manualTypes.contains(record.eventType)
                default: return true
                }
            }.sorted { $0.created_at == $1.created_at ? $0._id < $1._id : $0.created_at > $1.created_at }
    }
}

/// Owned by one treatment screen. All index state is confined to this serial queue.
final class TreatmentSearchStore {
    struct Result {
        let records: [TreatmentJSON]
        let unavailableDays: Int
        let dayCount: Int
    }
    struct Page {
        let treatments: [Treatment]
        let glucose: [Date: [SGVJSON]]
    }
    private let queue = DispatchQueue(label: "TreatmentCategorySearch", qos: .userInitiated)
    private var index: TreatmentSearchIndex?
    private var revision: UInt64?
    private var windowKey = ""
    private var unavailableDays = 0

    @discardableResult
    func search(query: String, segment: Int, autoTypes: [String], manualTypes: [String],
                scope: String, completion: @escaping (Result) -> Void) -> DispatchWorkItem {
        let work = DispatchWorkItem { [self] in
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let days = NightscoutCache.retentionDays
            let key = "\(scope)|\(today.timeIntervalSince1970)|\(calendar.timeZone.identifier)|\(days)"
            let currentRevision = NightscoutCache.treatmentSearchRevision
            if index == nil || revision != currentRevision || windowKey != key {
                let start = calendar.date(byAdding: .day, value: -days + 1, to: today)!
                let end = calendar.date(byAdding: .day, value: 1, to: today)!
                var records: [TreatmentJSON] = []
                unavailableDays = 0
                for offset in 0..<days {
                    let day = calendar.date(byAdding: .day, value: -offset, to: today)!
                    do { records += try NightscoutCache.readTreatmentsForSearch(day) }
                    catch { unavailableDays += 1 }
                }
                index = TreatmentSearchIndex(records: records.filter { $0.created_at >= start && $0.created_at < end })
                revision = currentRevision
                windowKey = key
            }
            let result = Result(records: index!.matches(query: query, segment: segment,
                autoTypes: autoTypes, manualTypes: manualTypes), unavailableDays: unavailableDays, dayCount: days)
            DispatchQueue.main.async { completion(result) }
        }
        queue.async(execute: work)
        return work
    }

    @discardableResult
    func preparePage(_ records: [TreatmentJSON], completion: @escaping (Page) -> Void) -> DispatchWorkItem {
        let work = DispatchWorkItem {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let treatments = records.map { Treatment(cached: $0, dateFormatter: formatter) }
            // Only meals need glucose, and only the displayed page needs row models.
            let calendar = Calendar.current
            var days = Set<Date>()
            for treatment in treatments where treatment.category == .meal {
                let day = calendar.startOfDay(for: treatment.timestamp)
                days.insert(day)
                if let next = calendar.date(byAdding: .day, value: 1, to: day) { days.insert(next) }
            }
            var glucose: [Date: [SGVJSON]] = [:]
            for day in days {
                if let payload = try? NightscoutCache.readDay(day) {
                    glucose[day] = NightscoutCache.normalizeAndDedupeSGV(payload.sgv)
                }
            }
            let page = Page(treatments: treatments, glucose: glucose)
            DispatchQueue.main.async { completion(page) }
        }
        queue.async(execute: work)
        return work
    }
}
