import Foundation

// Read-only inputs for the daily statistics subviews. Calculations remain in the view model.
struct DailyStatsDisplayThresholds {
    let lowGlucoseOKThreshold: Double
    let lowGlucoseGreatThreshold: Double
    let titrTargetThreshold: Double
    let tirTargetThreshold: Double
    let stdDevOkThreshold: Double
    let stdDevGreatThreshold: Double
    let bgAverageOKThreshold: Double
    let bgAverageGreatThreshold: Double

    init(viewModel: DailyStatsViewModel) {
        lowGlucoseOKThreshold = viewModel.lowGlucoseOKThreshold
        lowGlucoseGreatThreshold = viewModel.lowGlucoseGreatThreshold
        titrTargetThreshold = viewModel.titrTargetThreshold
        tirTargetThreshold = viewModel.tirTargetThreshold
        stdDevOkThreshold = viewModel.stdDevOkThreshold
        stdDevGreatThreshold = viewModel.stdDevGreatThreshold
        bgAverageOKThreshold = viewModel.bgAverageOKThreshold
        bgAverageGreatThreshold = viewModel.bgAverageGreatThreshold
    }
}

struct DailyStatsAverages {
    let averageCarbs: Double?
    let averageTDD: Double?
    let averageMeanGlucose: Double?
    let averageLowPercent: Double?
    let averageTitr: Double?
    let averageTir: Double?
    let averageStdDev: Double?

    init(viewModel: DailyStatsViewModel) {
        averageCarbs = viewModel.averageCarbs
        averageTDD = viewModel.averageTDD
        averageMeanGlucose = viewModel.averageMeanGlucose
        averageLowPercent = viewModel.averageLowPercent
        averageTitr = viewModel.averageTitr
        averageTir = viewModel.averageTir
        averageStdDev = viewModel.averageStdDev
    }
}
