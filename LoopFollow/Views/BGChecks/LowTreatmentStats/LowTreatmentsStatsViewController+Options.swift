import UIKit
import Charts

extension LowTreatmentsStatsViewController {
    enum PeriodOption: CaseIterable {
        case d7, d14, d30, d90

        var days: Int {
            switch self {
            case .d7:  return 7
            case .d14: return 14
            case .d30: return 30
            case .d90: return 90
            }
        }

        var title: String {
            switch self {
            case .d7:  return "7 d"
            case .d14: return "14 d"
            case .d30: return "30 d"
            case .d90: return "90 d"
            }
        }
    }

    enum ModeOption: CaseIterable {
        case count
        case grams
        case lowAndBg
        case time

        var title: String {
            switch self {
            case .count: return "Behandling"
            case .grams: return "Mängd"
            case .lowAndBg: return "Dex & Stick"
            case .time: return "Tid"
            }
        }
    }

    enum TimeFilterOption: CaseIterable {
        case allTime
        case dayTime
        case nightTime

        var title: String {
            switch self {
            case .allTime:  return "Alla"
            case .dayTime:  return "Dag (06–22)"
            case .nightTime: return "Natt (22–06)"
            }
        }
    }
}
