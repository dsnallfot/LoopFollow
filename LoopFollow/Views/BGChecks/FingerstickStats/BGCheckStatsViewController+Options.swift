import UIKit
import Charts

extension BGCheckStatsViewController {
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

    enum ChartMode: CaseIterable {
        case count, time

        var title: String {
            switch self {
            case .count: return "Antal"
            case .time:  return "Tid"
            }
        }
    }
}
