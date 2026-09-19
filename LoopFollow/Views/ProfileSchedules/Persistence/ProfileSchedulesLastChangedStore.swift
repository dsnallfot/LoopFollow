import Foundation

final class ProfileSchedulesLastChangedStore {
    static let shared = ProfileSchedulesLastChangedStore()

    private let defaultsKey = "ProfileSchedulesLastChangedDates"
    private var cache: [String: Date] = [:]

    private init() {
        load()
    }

    private func load() {
        let defaults = UserDefaults.standard
        guard let dict = defaults.dictionary(forKey: defaultsKey) as? [String: TimeInterval] else {
            return
        }

        var result: [String: Date] = [:]
        for (key, ts) in dict {
            result[key] = Date(timeIntervalSince1970: ts)
        }
        cache = result
    }

    private func save() {
        var dict: [String: TimeInterval] = [:]
        for (key, date) in cache {
            dict[key] = date.timeIntervalSince1970
        }
        UserDefaults.standard.set(dict, forKey: defaultsKey)
    }

    func registerChange(forKey normalizedKey: String, at date: Date) {
        if let existing = cache[normalizedKey], existing >= date {
            return
        }
        cache[normalizedKey] = date
        save()
    }

    func mergedLatest(forKey normalizedKey: String, candidate: Date?) -> Date? {
        let persisted = cache[normalizedKey]

        switch (persisted, candidate) {
        case (nil, nil):
            return nil
        case (let p?, nil):
            return p
        case (nil, let c?):
            cache[normalizedKey] = c
            save()
            return c
        case (let p?, let c?):
            let latest = max(p, c)
            if latest != p {
                cache[normalizedKey] = latest
                save()
            }
            return latest
        }
    }
}
