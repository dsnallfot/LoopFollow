import UIKit
import Charts

extension GlucoseView {
    func nearestBG(before date: Date, in bgTimes: [Date]) -> Date? {
        guard !bgTimes.isEmpty else { return nil }
        // bgTimes is sorted asc
        var lo = 0
        var hi = bgTimes.count - 1
        var result: Date?
        while lo <= hi {
            let mid = (lo + hi) / 2
            let d = bgTimes[mid]
            if d < date {
                result = d
                lo = mid + 1
            } else {
                hi = mid - 1
            }
        }
        return result
    }

    func nearestBG(after date: Date, in bgTimes: [Date]) -> Date? {
        guard !bgTimes.isEmpty else { return nil }
        // bgTimes is sorted asc
        var lo = 0
        var hi = bgTimes.count - 1
        var result: Date?
        while lo <= hi {
            let mid = (lo + hi) / 2
            let d = bgTimes[mid]
            if d > date {
                result = d
                hi = mid - 1
            } else {
                lo = mid + 1
            }
        }
        return result
    }
}
