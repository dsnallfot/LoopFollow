// LoopFollow
// DailyStatsViewModel.swift

import Foundation
import Combine

final class DailyStatsViewModel: ObservableObject {
    let dataService: StatsDataService
    let todayTDDOverride: Double?

    /// Vilka veckodagar som är valda i filtret (1 = sön, 2 = mån, ... 7 = lör enligt Calendar)
    @Published var selectedWeekdays: Set<Int>
    
    let allWeekdaysSet: Set<Int> = Set(1...7)
    
    /// True när vi filtrerar på pumpbytesdagar i stället för veckodagar.
    @Published var usePumpChangeDays: Bool = false
    
    /// True när vi filtrerar på sensorbytesdagar i stället för veckodagar.
    @Published var useSensorChangeDays: Bool = false
    
    /// True när vi endast vill visa sjukdagar.
    @Published var useSickDays: Bool = false

    /// True när vi endast vill visa dagar som inte är sjukdagar.
    @Published var useNonSickDays: Bool = false

        var mainViewController: MainViewController? {
            dataService.mainViewController
        }
    
    @Published var rows: [DailyStatRow] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    let lowGlucoseOKThreshold: Double = 0.05
    let lowGlucoseGreatThreshold: Double = 0.03
    let titrTargetThreshold: Double = 0.5
    let tirTargetThreshold: Double = 0.7
    let stdDevOkThreshold: Double = 3.0
    let stdDevGreatThreshold: Double = 2.5
    let bgAverageOKThreshold: Double = 8.0
    let bgAverageGreatThreshold: Double = 7.5
    let minGlucoseReadingsPerDay: Int = 150

    private let daysBack: Int

    init(dataService: StatsDataService, daysBack: Int = 91, todayTDDOverride: Double? = nil) {
        self.dataService = dataService
        self.todayTDDOverride = todayTDDOverride
        self.daysBack = daysBack
        self.selectedWeekdays = allWeekdaysSet
    }

}
