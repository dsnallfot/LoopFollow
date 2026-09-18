import UIKit

extension TreatmentsTableView {
    // MARK: - BG helpers for meal status

    /// Hittar BG-punkten som ligger närmast i tid till target, givet att bgPoints är sorterade på date.
    /// Om maxDelta anges, returnerar nil om närmaste punkt ligger längre bort än maxDelta.
    private func nearestBGPoint(around target: Date,
                                in points: [BGPoint],
                                maxDelta: TimeInterval? = nil) -> BGPoint? {
        guard !points.isEmpty else { return nil }
        var lo = 0
        var hi = points.count - 1
        var bestIndex = 0
        var bestDiff = abs(points[0].date.timeIntervalSince(target))

        while lo <= hi {
            let mid = (lo + hi) / 2
            let d = points[mid].date
            let diff = abs(d.timeIntervalSince(target))
            if diff < bestDiff {
                bestDiff = diff
                bestIndex = mid
            }
            if d < target {
                lo = mid + 1
            } else if d > target {
                hi = mid - 1
            } else {
                break
            }
        }
        
        if let maxDelta = maxDelta, bestDiff > maxDelta {
            return nil
        }
        return points[bestIndex]
    }

    /// Låg / ok / hög-symbol för en Kh-måltid, baserat på BG ~3h efter.
    /// Om ingen BG finns inom ±30 min runt +3h visas "⏳".
    func statusSymbolForCarbMeal(at mealDate: Date) -> String {
        let relevantBGPoints = bgPointsForMealStatus(at: mealDate)
        guard !relevantBGPoints.isEmpty else { return "⏳" }

        // Target time = 3h efter måltid
        let target = mealDate.addingTimeInterval(3 * 60 * 60)

        // Tillåt max ±30 minuter från target
        let maxDelta: TimeInterval = 30 * 60

        guard let point = nearestBGPoint(around: target, in: relevantBGPoints, maxDelta: maxDelta) else {
            return "⏳"
        }

        let endBG = point.mmol
        let endMgdl = endBG * 18.0182
        let lowMgdl = Double(UserDefaultsRepository.lowLine.value)
        let highMgdl = Double(UserDefaultsRepository.highLine.value)

        if endMgdl > highMgdl {
            return "🟣"
        } else if endMgdl < lowMgdl {
            return "🔴"
        } else {
            return "🟢"
        }
    }
    
    func storeBGPoints(_ points: [BGPoint], for day: Date) {
        let dayStart = Calendar.current.startOfDay(for: day)
        bgPointsByDay[dayStart] = points.sorted { $0.date < $1.date }
    }

    private func bgPointsForMealStatus(at mealDate: Date) -> [BGPoint] {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: mealDate)
        let nextDayStart = cal.date(byAdding: .day, value: 1, to: dayStart)

        var combined = bgPointsByDay[dayStart] ?? []
        if let nextDayStart {
            combined += bgPointsByDay[nextDayStart] ?? []
        }

        return combined.sorted { $0.date < $1.date }
    }
}
