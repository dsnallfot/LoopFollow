import UIKit
import Charts

extension BGCheckView {
    @objc func showBGCheckStats() {
        switch mode {
        case .fingerstick:
            let calendar = Calendar.current
            let now = Date()
            let daysBack = min(NightscoutCache.retentionDays, 91)

            // Startdatum = början av dagen (daysBack-1) dagar bakåt
            guard let startDay = calendar.date(byAdding: .day, value: -(daysBack - 1), to: calendar.startOfDay(for: now)) else {
                return
            }

            // Bygg en array av alla dagar i intervallet, med default 0 stick per dag
            var days: [Date] = []
            var counts: [Int] = []
            var dextroCounts: [Int] = []
            days.reserveCapacity(daysBack)
            counts.reserveCapacity(daysBack)
            dextroCounts.reserveCapacity(daysBack)

            for offset in 0..<daysBack {
                if let day = calendar.date(byAdding: .day, value: offset, to: startDay) {
                    days.append(day)
                    counts.append(0)
                    dextroCounts.append(0)
                }
            }

            // Snabb lookup för dag -> index i counts
            var indexByDay: [Date: Int] = [:]
            for (idx, day) in days.enumerated() {
                indexByDay[calendar.startOfDay(for: day)] = idx
            }

            // Räkna fingerstick per dag inom perioden och dextro per dag
            for entry in fingerstickEntries {
                if entry.date < startDay || entry.date > now { continue }
                let dayStart = calendar.startOfDay(for: entry.date)
                if let idx = indexByDay[dayStart] {
                    counts[idx] += 1
                    if entry.hasDextroNearby {
                        dextroCounts[idx] += 1
                    }
                }
            }

            let bgCheckDates = fingerstickEntries.map { $0.date }
            let bgCheckDextroDates = fingerstickEntries.filter { $0.hasDextroNearby }.map { $0.date }

            let statsVC = BGCheckStatsViewController(
                days: days,
                counts: counts,
                dextroCounts: dextroCounts,
                bgCheckEntries: fingerstickEntries,
                bgCheckDates: bgCheckDates,
                bgCheckDextroDates: bgCheckDextroDates
            )
            let nav = UINavigationController(rootViewController: statsVC)

            nav.modalPresentationStyle = .formSheet
            nav.view.backgroundColor = .clear
            nav.view.isOpaque = false
            nav.view.layer.backgroundColor = UIColor.clear.cgColor

            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            nav.navigationBar.standardAppearance = appearance
            nav.navigationBar.scrollEdgeAppearance = appearance
            nav.navigationBar.compactAppearance = appearance

            nav.overrideUserInterfaceStyle = self.traitCollection.userInterfaceStyle
            present(nav, animated: true)

        case .dextro:
            let calendar = Calendar.current
            let now = Date()
            let daysBack = min(NightscoutCache.retentionDays, 91)

            // Startdatum = början av dagen (daysBack-1) dagar bakåt
            guard let startDay = calendar.date(
                byAdding: .day,
                value: -(daysBack - 1),
                to: calendar.startOfDay(for: now)
            ) else {
                return
            }

            // Begränsa till perioden vi ska visa i statistiken
            let filteredEntries = dextroEntries.filter { $0.date >= startDay && $0.date <= now }

            // Bygg en array av alla dagar i intervallet, med default 0 lågbehandlingar per dag
            var days: [Date] = []
            var counts: [Int] = []
            var gramsPerDay: [Double] = []
            days.reserveCapacity(daysBack)
            counts.reserveCapacity(daysBack)
            gramsPerDay.reserveCapacity(daysBack)

            for offset in 0..<daysBack {
                if let day = calendar.date(byAdding: .day, value: offset, to: startDay) {
                    days.append(day)
                    counts.append(0)
                    gramsPerDay.append(0)
                }
            }

            // Snabb lookup för dag -> index i arrays
            var indexByDay: [Date: Int] = [:]
            for (idx, day) in days.enumerated() {
                indexByDay[calendar.startOfDay(for: day)] = idx
            }

            // Räkna lågbehandlingar och gram per dag
            for entry in filteredEntries {
                let dayStart = calendar.startOfDay(for: entry.date)
                if let idx = indexByDay[dayStart] {
                    counts[idx] += 1
                    gramsPerDay[idx] += entry.grams
                }
            }

            // Underliggande lista med enskilda behandlingar (för medel/max/streak-beräkningar)
            let treatmentDates = filteredEntries.map { $0.date }
            let treatmentGrams = filteredEntries.map { $0.grams }
            let treatmentHasBGCheck = filteredEntries.map { $0.hasBGCheckNearby }

            let statsVC = LowTreatmentsStatsViewController(
                days: days,
                counts: counts,
                gramsPerDay: gramsPerDay,
                treatmentDates: treatmentDates,
                treatmentGrams: treatmentGrams,
                treatmentHasBGCheck: treatmentHasBGCheck,
                bgCheckDates: dextroBGCheckDates,
                bgCheckMmol: dextroBGCheckMmol
            )
            let nav = UINavigationController(rootViewController: statsVC)

            nav.modalPresentationStyle = .formSheet
            nav.view.backgroundColor = .clear
            nav.view.isOpaque = false
            nav.view.layer.backgroundColor = UIColor.clear.cgColor

            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            nav.navigationBar.standardAppearance = appearance
            nav.navigationBar.scrollEdgeAppearance = appearance
            nav.navigationBar.compactAppearance = appearance

            nav.overrideUserInterfaceStyle = self.traitCollection.userInterfaceStyle
            present(nav, animated: true)
        }
    }
}
